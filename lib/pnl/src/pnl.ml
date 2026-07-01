open! Core
open Jsip_types

(* One participant's running position in one symbol. [cost_basis_cents] is
   the exact total cost of the currently-open [inventory] shares, carrying
   the same sign as [inventory] (positive when long, negative when short);
   the average entry price is [cost_basis_cents / inventory]. Keeping the
   total rather than the average keeps every fill exact — averaging into an
   int on each fill would accumulate sub-cent rounding error. *)
module Position = struct
  type t =
    { inventory : int
    ; cost_basis_cents : int
    ; realized_cents : int
    }

  let zero = { inventory = 0; cost_basis_cents = 0; realized_cents = 0 }

  let average_entry_price t =
    if t.inventory = 0
    then None
    else Some (Price.of_int_cents (t.cost_basis_cents / t.inventory))
  ;;
end

type t =
  { positions : Position.t Map.M(Symbol).t Map.M(Participant).t
  ; reference_prices : Price.t Map.M(Symbol).t
  }

let empty =
  { positions = Map.empty (module Participant)
  ; reference_prices = Map.empty (module Symbol)
  }
;;

let find_position t ~participant ~symbol =
  match Map.find t.positions participant with
  | None -> Position.zero
  | Some by_symbol ->
    Option.value (Map.find by_symbol symbol) ~default:Position.zero
;;

let set_position t ~participant ~symbol position =
  let by_symbol =
    Option.value
      (Map.find t.positions participant)
      ~default:(Map.empty (module Symbol))
  in
  let by_symbol = Map.set by_symbol ~key:symbol ~data:position in
  { t with positions = Map.set t.positions ~key:participant ~data:by_symbol }
;;

(* [-1], [0], or [+1] as an int (unlike [Int.sign], which returns a [Sign.t]
   we cannot do arithmetic with). *)
let sign_int n = Sign.to_int (Int.sign n)

(* Update a single participant's position with a [size]-share execution at
   [price] on [side]. This is the heart of the module: it decides whether the
   fill grows, shrinks, or flips the position, and how much P&L that
   realizes. *)
let apply_one t ~participant ~symbol ~(side : Side.t) ~size ~price =
  let delta = Side.sign side * Size.to_int size in
  let price_cents = Price.to_int_cents price in
  let (position : Position.t) = find_position t ~participant ~symbol in
  let inventory = position.inventory in
  let cost_basis = position.cost_basis_cents in
  let (position : Position.t) =
    if inventory = 0 || sign_int delta = sign_int inventory
    then
      (* Opening or adding in the same direction: fold the shares into the
         cost basis. Nothing is realized. *)
      { position with
        inventory = inventory + delta
      ; cost_basis_cents = cost_basis + (delta * price_cents)
      }
    else (
      (* [delta] opposes the position, so it closes shares. *)
      let closing = Int.min (Int.abs delta) (Int.abs inventory) in
      let flips = Int.abs delta > Int.abs inventory in
      let cost_removed =
        if closing = Int.abs inventory
        then
          cost_basis
          (* full close: retire all basis exactly, no residual *)
        else cost_basis * closing / Int.abs inventory
      in
      (* The closing trade brings in [+price] per share when we were long and
         costs [price] per share when we were short, i.e.
         [sign inventory * closing * price]. Realized P&L is that cash minus
         the basis it retired. *)
      let realized_delta =
        (sign_int inventory * closing * price_cents) - cost_removed
      in
      let new_inventory = inventory + delta in
      let cost_basis_cents =
        if flips
        then
          new_inventory * price_cents (* leftover opens fresh at [price] *)
        else cost_basis - cost_removed
      in
      { inventory = new_inventory
      ; cost_basis_cents
      ; realized_cents = position.realized_cents + realized_delta
      })
  in
  set_position t ~participant ~symbol position
;;

let apply_fill t (fill : Fill.t) =
  let t =
    apply_one
      t
      ~participant:fill.aggressor_participant
      ~symbol:fill.symbol
      ~side:fill.aggressor_side
      ~size:fill.size
      ~price:fill.price
  in
  apply_one
    t
    ~participant:fill.resting_participant
    ~symbol:fill.symbol
    ~side:(Side.flip fill.aggressor_side)
    ~size:fill.size
    ~price:fill.price
;;

let apply_trade_report t (event : Exchange_event.t) =
  match event with
  | Trade_report { symbol; price; size = _ } ->
    { t with
      reference_prices = Map.set t.reference_prices ~key:symbol ~data:price
    }
  | Order_accept _ | Fill _ | Order_cancel _ | Order_reject _
  | Best_bid_offer_update _ | Cancel_reject _ ->
    t
;;

(* [unrealized_cents ~inventory ~average_entry_price ~reference_price] values
   an OPEN position at the current mark. Per the P&L convention:

   {[
     unrealized = inventory * (reference_price - average_entry_price)
   ]}

   [inventory] is signed (negative = short). [average_entry_price] is [None]
   when the position is flat; [reference_price] is [None] until the first
   trade print for the symbol arrives. Decide what "unrealized" should be
   when a price is missing, and return the value in integer cents. *)
let unrealized_cents ~inventory ~average_entry_price ~reference_price =
  match average_entry_price, reference_price with
  | Some average_entry_price, Some reference_price ->
    inventory
    * (Price.to_int_cents reference_price
       - Price.to_int_cents average_entry_price)
  | None, None | Some _, None | None, Some _ -> 0
;;

module Summary = struct
  module Per_symbol = struct
    type t =
      { symbol : Symbol.t
      ; inventory : int
      ; average_entry_price : Price.t option
      ; reference_price : Price.t option
      ; realized_cents : int
      ; unrealized_cents : int
      }
    [@@deriving sexp_of]
  end

  type t =
    { per_symbol : Per_symbol.t list
    ; realized_cents : int
    ; unrealized_cents : int
    ; total_cents : int
    }
  [@@deriving sexp_of]

  (* Format a cash amount in cents as dollars, reusing {!Price}'s renderer
     (which already handles negatives). *)
  let dollars cents = Price.to_string_dollar (Price.of_int_cents cents)

  let price_opt = function
    | None -> "n/a"
    | Some price -> Price.to_string_dollar price
  ;;

  let row (r : Per_symbol.t) =
    let symbol = Symbol.to_string r.symbol in
    let inventory = Int.to_string r.inventory in
    let avg = price_opt r.average_entry_price in
    let ref_ = price_opt r.reference_price in
    let realized = dollars r.realized_cents in
    let unrealized = dollars r.unrealized_cents in
    [%string
      "%{symbol}: inv=%{inventory} avg=%{avg} ref=%{ref_} \
       realized=%{realized} unrealized=%{unrealized}"]
  ;;

  let to_string_hum
    { per_symbol; realized_cents; unrealized_cents; total_cents }
    =
    let realized = dollars realized_cents in
    let unrealized = dollars unrealized_cents in
    let pnl = dollars total_cents in
    let total =
      [%string
        "TOTAL: realized=%{realized} unrealized=%{unrealized} pnl=%{pnl}"]
    in
    String.concat ~sep:"\n" (List.map per_symbol ~f:row @ [ total ])
  ;;
end

let summary t participant =
  let by_symbol =
    Option.value
      (Map.find t.positions participant)
      ~default:(Map.empty (module Symbol))
  in
  let per_symbol =
    Map.to_alist by_symbol
    |> List.map ~f:(fun (symbol, (position : Position.t)) ->
      let reference_price = Map.find t.reference_prices symbol in
      let average_entry_price = Position.average_entry_price position in
      let unrealized_cents =
        unrealized_cents
          ~inventory:position.inventory
          ~average_entry_price
          ~reference_price
      in
      { Summary.Per_symbol.symbol
      ; inventory = position.inventory
      ; average_entry_price
      ; reference_price
      ; realized_cents = position.realized_cents
      ; unrealized_cents
      })
  in
  let realized_cents =
    List.sum (module Int) per_symbol ~f:(fun (r : Summary.Per_symbol.t) ->
      r.realized_cents)
  in
  let unrealized_cents =
    List.sum (module Int) per_symbol ~f:(fun (r : Summary.Per_symbol.t) ->
      r.unrealized_cents)
  in
  { Summary.per_symbol
  ; realized_cents
  ; unrealized_cents
  ; total_cents = realized_cents + unrealized_cents
  }
;;
