open! Core
open Jsip_types

(* Representation: each price level is a FIFO hash queue of orders keyed by
   [Order_id]. A [Hash_queue] gives O(1) enqueue / peek-oldest / cancel, and
   its front-to-back order is arrival order — exactly price-time priority
   within a level. Each side is a [Core.Map] from price to that queue, so the
   best level is [Map.max_elt] (bids) or [Map.min_elt] (asks). A separate
   [id_hash] maps every resting order id to its order so [find] and [remove]
   stay O(1) without needing the price. Empty levels are dropped from the map
   so [is_empty] and the best-level lookups never see a zero-size price. *)

module Order_queue = Hash_queue.Make (Order_id)

type side_book = Order.t Order_queue.t Map.M(Price).t

(* [Hash_queue] is not sexpable, so flatten each level to its ordered order
   list — this also reads better than a raw queue dump. *)
let sexp_of_side_book (m : side_book) : Sexp.t =
  Map.to_alist m
  |> List.map ~f:(fun (price, q) -> price, Order_queue.to_list q)
  |> [%sexp_of: (Price.t * Order.t list) list]
;;

type t =
  { symbol : Symbol.t
  ; mutable bids : side_book
  ; mutable asks : side_book
  ; id_hash : (Order_id.t, Order.t) Hashtbl.t
  }
[@@deriving sexp_of]

let create symbol =
  { symbol
  ; bids = Map.empty (module Price)
  ; asks = Map.empty (module Price)
  ; id_hash = Hashtbl.create (module Order_id)
  }
;;

let symbol t = t.symbol

(* the price -> queue map for one side *)
let side_map t side : side_book =
  match (side : Side.t) with Buy -> t.bids | Sell -> t.asks
;;

let set_side t side m =
  match (side : Side.t) with Buy -> t.bids <- m | Sell -> t.asks <- m
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
    let price = Order.price order in
    let id = Order.order_id order in
    let side = Order.side order in
    Hashtbl.add_exn t.id_hash ~key:id ~data:order;
    let m = side_map t side in
    (* If the level exists we enqueue in place (no structural write); only a
       brand-new price grows the map. *)
    match Map.find m price with
    | Some q -> Order_queue.enqueue_back_exn q id order
    | None ->
      let q = Order_queue.create () in
      Order_queue.enqueue_back_exn q id order;
      set_side t side (Map.set m ~key:price ~data:q))
;;

(* factored out as ' and returns option for testing purposes *)
let remove' t order_id =
  match Hashtbl.find_and_remove t.id_hash order_id with
  | None -> None
  | Some order ->
    let price = Order.price order in
    let side = Order.side order in
    let m = side_map t side in
    (match Map.find m price with
     | None -> ()
     | Some q ->
       ignore (Order_queue.remove q order_id : [ `Ok | `No_such_key ]);
       (* drop the level once its last order leaves *)
       if Order_queue.is_empty q then set_side t side (Map.remove m price));
    Some order
;;

let remove t order_id = ignore (remove' t order_id)
let find t order_id = Hashtbl.find t.id_hash order_id

(* The best (most aggressive) level on a side, as its price and queue: the
   highest bid or the lowest ask. *)
let best_level_entry t side : (Price.t * Order.t Order_queue.t) option =
  let m = side_map t side in
  match (side : Side.t) with Buy -> Map.max_elt m | Sell -> Map.min_elt m
;;

(* The most aggressively priced marketable order on the opposite side: best
   price, then the oldest resting order at that price (the queue front). *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let opposite_side = Side.flip incoming_side in
  match best_level_entry t opposite_side with
  | None -> None
  | Some (_price, q) ->
    (match Order_queue.first q with
     | None -> None
     | Some resting ->
       if Price.is_marketable
            incoming_side
            ~price:(Order.price incoming)
            ~resting_price:(Order.price resting)
       then Some resting
       else None)
;;

let orders_on_side t side =
  Map.fold_right (side_map t side) ~init:[] ~f:(fun ~key:_ ~data:q acc ->
    List.append (Order_queue.to_list q) acc)
;;

let is_empty t = Map.is_empty t.bids && Map.is_empty t.asks

let count t side =
  Map.fold (side_map t side) ~init:0 ~f:(fun ~key:_ ~data:q acc ->
    acc + Order_queue.length q)
;;

(* Total resting size at one price level. *)
let level_size (q : Order.t Order_queue.t) : Size.t =
  Order_queue.fold q ~init:Size.zero ~f:(fun acc order ->
    Size.( + ) acc (Order.remaining_size order))
;;

let best_level t side : Level.t option =
  match best_level_entry t side with
  | None -> None
  | Some (price, q) -> Some { price; size = level_size q }
;;

let best_bid_offer t : Bbo.t =
  { bid = best_level t Buy; ask = best_level t Sell }
;;

let snapshot_side t (side : Side.t) : Level.t list =
  (* best-price-first: bids high -> low, asks low -> high *)
  let ordered =
    match side with
    | Buy -> Map.to_alist ~key_order:`Decreasing (side_map t side)
    | Sell -> Map.to_alist ~key_order:`Increasing (side_map t side)
  in
  List.map ordered ~f:(fun (price, q) : Level.t ->
    { price; size = level_size q })
;;

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
