(* : consider implementing a hash queue or other data structure with O(1)
   remove *)

open! Core
open Jsip_types
open! Async_log_kernel.Ppx_log_syntax

(* 1. could use two modules. one for Buy and one for sell (most clear)
   2. could also make the key Price.t Order_id.t Side.t *)

(* This will be from the perspective of the Buyer so the prices will be
   sorted in ascending order. *)

module Order_Key = struct
  module T = struct
    type t = int * Order_id.t [@@deriving sexp, compare]
  end

  include T
  include Comparable.Make (T)
end

type order_book_map = Order.t Map.M(Order_Key).t [@@deriving sexp]

type t =
  { symbol : Symbol.t
  ; mutable bids : order_book_map
  ; mutable asks : order_book_map
  ; mutable id_hash : (Order_id.t, Order.t) Hashtbl.t
  }
[@@deriving sexp_of]

let create symbol =
  { symbol
  ; bids = Map.empty (module Order_Key)
  ; asks = Map.empty (module Order_Key)
  ; id_hash = Hashtbl.create (module Order_id)
  }
;;

(* This function converts a Price.t into an int for the bids and asks map. We
   negate if the side is Buy because higher bids are more competitive, and we
   are using min_elt. *)
let rank (price : Price.t) side =
  let int_price = Price.to_int_cents price in
  match (side : Side.t) with Sell -> int_price | Buy -> -int_price
;;

let map_key_of order : Order_Key.t =
  rank (Order.price order) (Order.side order), Order.order_id order
;;

let hash_key_of order = Order.order_id order
let symbol t = t.symbol

(* grabs the list of orders associated with side *)
let side_map t side =
  match (side : Side.t) with Buy -> t.bids | Sell -> t.asks
;;

let add t order =
  if not (Symbol.equal (Order.symbol order) t.symbol)
  then
    raise_s
      [%message
        "Order_book.add: order symbol does not match this book"
          ~book_symbol:(t.symbol : Symbol.t)
          (order : Order.t)]
  else if Size.( <= ) (Order.remaining_size order) Size.zero
  then
    raise_s
      [%message
        "Order_book.add: order must have positive remaining size"
          (order : Order.t)]
  else (
    let side = Order.side order in
    let () =
      Hashtbl.add_exn t.id_hash ~key:(hash_key_of order) ~data:order
    in
    match side with
    | Buy -> t.bids <- Map.set t.bids ~key:(map_key_of order) ~data:order
    | Sell -> t.asks <- Map.set t.asks ~key:(map_key_of order) ~data:order)
;;

(* factored out as ' and returns option for testing purposes *)
let remove' t order_id =
  let find_hash = Hashtbl.find_and_remove t.id_hash order_id in
  match find_hash with
  | None -> None
  | Some order ->
    let side = Order.side order in
    let () =
      match side with
      | Buy -> t.bids <- Map.remove t.bids (map_key_of order)
      | Sell -> t.asks <- Map.remove t.asks (map_key_of order)
    in
    Some order
;;

let remove t order_id = ignore (remove' t order_id)
let find t order_id = Hashtbl.find t.id_hash order_id

(* match o1_more_than_o2, o2_more_than_o1, o1_earlier_than_o2 with | true, _,
   _ -> 1 | _, true, _ -> -1 | _, _, x -> x *)

(* This returns the most aggressively priced marketable order on the opposite
   side using List.reduce *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let opposite_side = Side.flip incoming_side in
  let most_aggressive = Map.min_elt (side_map t opposite_side) in
  match most_aggressive with
  | None -> None
  | Some (_, order) ->
    if Price.is_marketable
         incoming_side
         ~price:(Order.price incoming)
         ~resting_price:(Order.price order)
    then Some order
    else None
;;

let orders_on_side t side =
  List.map (Map.to_alist (side_map t side)) ~f:(fun (_, y) -> y)
;;

let is_empty t = Map.is_empty t.bids && Map.is_empty t.asks
let count t side = Map.length (side_map t side)

(* gets the best price on the side *)
let best_price t side =
  let find_min = Map.min_elt (side_map t side) in
  match find_min with
  | None -> None
  | Some (_, order) -> Some (Order.price order)
;;

let best_level t side : Level.t option =
  match best_price t side with
  | None -> None
  | Some price ->
    let side_list =
      (* Map.data exists!! *)
      List.map (Map.to_alist (side_map t side)) ~f:(fun (_, order) -> order)
    in
    let total_size =
      (* filter and then list.sum. *)
      List.fold side_list ~init:Size.zero ~f:(fun acc order ->
        if Price.equal (Order.price order) price
        then Size.( + ) acc (Order.remaining_size order)
        else acc)
    in
    Some { price; size = total_size }
;;

let best_bid_offer t : Bbo.t =
  { bid = best_level t Buy; ask = best_level t Sell }
;;

(* before *)
(* let snapshot_side t (side : Side.t) = List.map (Map.to_alist
   ~key_order:`Increasing (side_map t side)) ~f:(fun (_, order) ->
   Level.of_order order) ;; *)

let snapshot_side t (side : Side.t) =
  let fold_fun (accum : Level.t List.t) (level : Level.t) =
    match accum with
    | x :: _ ->
      if Price.equal x.price level.price then accum else level :: accum
    | [] -> [ level ]
  in
  List.fold
    ~init:[]
    (List.map
       (Map.to_alist ~key_order:`Increasing (side_map t side))
       ~f:(fun (_, order) -> Level.of_order order))
    ~f:fold_fun
;;

(* default *)
(* let snapshot_side t (side : Side.t) = let compare = match side with | Buy
   -> Comparable.reverse Level.compare | Sell -> Level.compare in
   orders_on_side t side |> List.map ~f:Level.of_order |> List.sort ~compare
   ;; *)

let snapshot t =
  { Book.symbol = symbol t
  ; bids = snapshot_side t Buy
  ; asks = snapshot_side t Sell
  ; bbo = best_bid_offer t
  }
;;

module For_testing = struct
  let remove = remove'
end
