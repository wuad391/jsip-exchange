open! Core
open Jsip_types

(* Representation: each price level is a FIFO hash queue of orders keyed by
   [Order_id], paired with a running [total_size] — the sum of the remaining
   sizes of the orders in that queue. A [Hash_queue] gives O(1) enqueue /
   peek-oldest / cancel, and its front-to-back order is arrival order —
   exactly price-time priority within a level. Each side is a [Core.Map] from
   price to that level. A separate [id_hash] maps every resting order id to
   its order so [find] and [remove] stay O(1) without needing the price.
   Empty levels are dropped from the map so [is_empty] and the best-level
   lookups never see a zero-size price.

   Two caches keep the hot reads O(1):

   - [total_size] per level: the summed remaining size, so a level's size
     never needs folding. Maintained on add (+), remove (-), and fill_resting
     (-).

   - [best_bid] / [best_ask] on the book: the current top-of-book level (its
     price and record) for each side, so [best_bid_offer] and [find_match]
     never walk the price map. Maintained incrementally: an add whose price
     is strictly more aggressive than the current best (which is always a
     brand-new level) becomes the new best in O(1); removing the last order
     at the best level recomputes via [Map.max_elt]/[Map.min_elt] in O(log P)
     — the only path that still walks. A resting fill only shrinks the best
     level's [total_size] in place (the cache points at that same record), so
     the pointer needs no update. *)

module Order_queue = Hash_queue.Make (Order_id)

type price_level =
  { queue : Order.t Order_queue.t
  ; mutable total_size : Size.t
  }

type side_book = price_level Map.M(Price).t

(* [Hash_queue] is not sexpable, so flatten each level to its ordered order
   list — this also reads better than a raw queue dump. *)
let sexp_of_side_book (m : side_book) : Sexp.t =
  Map.to_alist m
  |> List.map ~f:(fun (price, level) ->
    price, Order_queue.to_list level.queue)
  |> [%sexp_of: (Price.t * Order.t list) list]
;;

type t =
  { symbol : Symbol_id.t
  ; mutable bids : side_book
  ; mutable asks : side_book
  ; mutable best_bid : ((Price.t * price_level) option[@sexp.opaque])
  ; mutable best_ask : ((Price.t * price_level) option[@sexp.opaque])
  ; id_hash : (Order_id.t, Order.t) Hashtbl.t
  }
[@@deriving sexp_of]

let create symbol =
  { symbol
  ; bids = Map.empty (module Price)
  ; asks = Map.empty (module Price)
  ; best_bid = None
  ; best_ask = None
  ; id_hash = Hashtbl.create (module Order_id)
  }
;;

let symbol t = t.symbol

(* the price -> level map for one side *)
let side_map t side : side_book =
  match (side : Side.t) with Buy -> t.bids | Sell -> t.asks
;;

let set_side t side m =
  match (side : Side.t) with Buy -> t.bids <- m | Sell -> t.asks <- m
;;

(* the cached top-of-book level for one side: (price, level) or None *)
let best_ref t side : (Price.t * price_level) option =
  match (side : Side.t) with Buy -> t.best_bid | Sell -> t.best_ask
;;

let set_best t side v =
  match (side : Side.t) with
  | Buy -> t.best_bid <- v
  | Sell -> t.best_ask <- v
;;

(* The best (most aggressive) level on a side by walking the price map: the
   highest bid or the lowest ask. This is the O(log P) recompute the
   [best_bid]/[best_ask] caches exist to avoid; it runs only when the best
   level empties. *)
let best_level_entry t side : (Price.t * price_level) option =
  let m = side_map t side in
  match (side : Side.t) with Buy -> Map.max_elt m | Sell -> Map.min_elt m
;;

let add t order =
  if not (Symbol_id.equal (Order.symbol order) t.symbol)
  then
    raise_s
      [%message
        "Order_book.add: order symbol does not match this book"
          ~book_symbol:(t.symbol : Symbol_id.t)
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
    let size = Order.remaining_size order in
    Hashtbl.add_exn t.id_hash ~key:id ~data:order;
    let m = side_map t side in
    (* If the level exists we enqueue in place (no structural write) and grow
       its cached total; only a brand-new price grows the map. *)
    let level =
      match Map.find m price with
      | Some level ->
        Order_queue.enqueue_back_exn level.queue id order;
        level.total_size <- Size.( + ) level.total_size size;
        level
      | None ->
        let queue = Order_queue.create () in
        Order_queue.enqueue_back_exn queue id order;
        let level = { queue; total_size = size } in
        set_side t side (Map.set m ~key:price ~data:level);
        level
    in
    (* Maintain the best cache: only a strictly more aggressive price can
       displace the current best, and such a price is always a brand-new
       level (an existing level's price is already at least as aggressive as
       best). *)
    match best_ref t side with
    | None -> set_best t side (Some (price, level))
    | Some (best_price, _) ->
      if Price.is_more_aggressive side ~price ~than:best_price
      then set_best t side (Some (price, level)))
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
     | Some level ->
       ignore
         (Order_queue.remove level.queue order_id : [ `Ok | `No_such_key ]);
       (* the order still carries its remaining size, so subtract exactly its
          contribution from the level's cached total *)
       level.total_size
       <- Size.( - ) level.total_size (Order.remaining_size order);
       (* drop the level once its last order leaves *)
       if Order_queue.is_empty level.queue
       then (
         set_side t side (Map.remove m price);
         (* the level just vanished; if it was the cached best, the best
            moves to the next level (or to None) — recompute with the
            O(log P) walk *)
         match best_ref t side with
         | Some (best_price, _) when Price.equal best_price price ->
           set_best t side (best_level_entry t side)
         | _ -> ()));
    Some order
;;

let remove t order_id = ignore (remove' t order_id)
let find t order_id = Hashtbl.find t.id_hash order_id

(* Fill [by] units of a resting order, keeping this book's cached level total
   in step. The matching engine calls this instead of a bare
   {!Jsip_types.Order.fill} for an order that is resting on the book: because
   a partially filled order stays put at its price, that level's cached total
   must shrink by the same [by], or {!best_bid_offer} reports a stale size.
   The [best_bid]/[best_ask] pointers need no update: the resting order is at
   the best level (find_match guarantees it), and this only shrinks that
   level's [total_size] in place — the cache already points at that record. *)
let fill_resting (t : t) (order : Order.t) ~(by : Size.t) : unit =
  Order.fill order ~by;
  let price = Order.price order in
  let side = Order.side order in
  match Map.find (side_map t side) price with
  | Some level -> level.total_size <- Size.( - ) level.total_size by
  | None ->
    (* A resting order must have a live level; its absence is a broken book
       invariant, not a recoverable condition. *)
    raise_s
      [%message
        "Order_book.fill_resting: no price level for a resting order"
          (order : Order.t)]
;;

(* The most aggressively priced marketable order on the opposite side: best
   price (read from the cache), then the oldest resting order at that price
   (the queue front). *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let opposite_side = Side.flip incoming_side in
  match best_ref t opposite_side with
  | None -> None
  | Some (_price, level) ->
    (match Order_queue.first level.queue with
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
  Map.fold_right (side_map t side) ~init:[] ~f:(fun ~key:_ ~data:level acc ->
    List.append (Order_queue.to_list level.queue) acc)
;;

let is_empty t = Map.is_empty t.bids && Map.is_empty t.asks

let count t side =
  Map.fold (side_map t side) ~init:0 ~f:(fun ~key:_ ~data:level acc ->
    acc + Order_queue.length level.queue)
;;

(* Top-of-book for one side, read straight off the cache in O(1): the cached
   level's price and its (also cached) total size. *)
let best_level t side : Level.t option =
  match best_ref t side with
  | None -> None
  | Some (price, level) -> Some { price; size = level.total_size }
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
  List.map ordered ~f:(fun (price, level) : Level.t ->
    { price; size = level.total_size })
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
