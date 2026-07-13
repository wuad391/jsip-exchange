(** Benchmark: a nested price->queue order book vs the flat
    [(price, order_id)] map, via [core_bench].

    Models one side of a book (bids: the best resting order is the highest
    price, and among equal prices the earliest [order_id] — price-time
    priority, with [order_id] standing in for arrival time). Six
    representations of that side:

    - [Flat]: one persistent [Map] keyed by [(-price_cents, order_id)], so
      [Map.min_elt] is the price-time-priority best order. This is what
      {!Jsip_order_book.Order_book} ships today.
    - [Nested_map]: [Key_aug_table] from price to a persistent [Map] from
      order_id to order — a fully persistent "map of maps".
    - [Nested_hq]: [Key_aug_table] from price to a {e mutable} sized hash
      queue per level. O(1) enqueue / peek-oldest / cancel. [best] and [bbo]
      reach the top level with [Key_aug_table.max_elt], an O(log P)
      right-spine walk.
    - [Nested_hq_map]: the same sized hash queue, but the outer price index
      is a plain [Core.Map]. Its [best]/[bbo] are a [Map.max_elt] walk — also
      O(log P).
    - [Nested_aug]: [Aug_table] from price to the sized hash queue, whose
      cached measure is [(best_price, queue_at_best_price)]. Because the
      measure carries the winning queue by {e reference}, [best] and [bbo]
      read the root measure in O(1) — no walk — and stay fresh across
      in-place enqueues (the queue tracks its own depth; the measure only
      holds a pointer to it). This is the contender under test: does the O(1)
      measure beat the O(log P) walk?
    - [Nested_hq_tracked]: the [Nested_hq_map] design (plain [Core.Map] +
      sized hash queue) plus a cached [(best_price, queue)] field beside the
      map — the very pair [Nested_aug] holds as its measure, but maintained
      by hand instead of baked into a custom tree. [best]/[bbo] read the
      cached field in O(1); [find]/[update]/[build] keep [Core.Map]'s tuned
      speed. The bet: get [Nested_aug]'s O(1) top-of-book without paying its
      slower hand-rolled tree on the write path.

    With P price levels and k orders per level (N = P*k total), a point op on
    the flat map is O(log N). A nested op splits into an outer O(log P) plus
    an inner op; since log P + log k = log N, the nesting only pays off when
    the inner op is O(1) (the hash-queue designs). Reaching the best level is
    what varies: O(1) (measure) vs O(log P) (a spine walk) vs O(log N + k)
    (flat: find the best price, then scan its k orders to sum depth). P — not
    N — gates that cost, so we vary the number of {e levels} directly.

    Every benched operation is net-zero on state, so it measures fairly on
    the mutable designs as well as the persistent ones — no per-iteration
    reset is needed:
    - [build]: construct the whole book (creation cost).
    - [find]: look up the order at a known [(price, order_id)].
    - [best]: the price-time-priority best resting order.
    - [bbo]: the best price and the total resting size at it.
    - [update]: replace the value at an already-present [(price, order_id)].
    - [round_trip]: add a transient order, then immediately remove it.
    - [churn_top]: drop the best price level off the index and re-insert it
      (queue preserved). The worst case for the two designs that cache the
      top of book: the cache is invalidated, so [Nested_hq_tracked] pays an
      explicit O(log P) [Map.max_elt] to re-derive it, while [Nested_aug]'s
      tree refreshes its measure for free as part of the same remove. Popping
      a still-full level costs the index exactly what the real "cancel the
      last order, level empties" event would, but stays net-zero for the
      benchmark.

    Run:
    {v
      dune exec lib/aug_table/bench/bench_order_book.exe --root . -- \
        -ascii -quota 1 > performance/runs/order_book_nested_vs_flat.txt
    v} *)

open! Core
open Core_bench
open Jsip_types
open Jsip_aug_table

(* Orders per price level, held fixed while the number of levels (P) varies,
   so a change in [best]/[bbo] is attributable to P alone. *)
let orders_per_level = 16
let base_cents = 100_00

let make_order ~price ~order_id =
  Order.create
    { symbol = Symbol.of_string "AAPL"
    ; participant = Participant.of_string "Alice"
    ; side = Buy
    ; price
    ; size = Size.of_int 100
    ; time_in_force = Day
    ; client_order_id = Client_order_id.of_int 1
    }
    ~order_id
;;

(* [levels] price levels, [orders_per_level] to a level, each order with a
   sequential order_id (= arrival time), so within a level ids increase with
   arrival. *)
let make_orders ~levels =
  let n = levels * orders_per_level in
  let gen = Order_id.Generator.create () in
  Array.init n ~f:(fun i ->
    make_order
      ~price:(Price.of_int_cents (base_cents + (i / orders_per_level)))
      ~order_id:(Order_id.Generator.next gen))
;;

(* A mutable hash queue (hash table + doubly-linked list: O(1) enqueue /
   peek-oldest / cancel) that also tracks the total resting size of the
   orders it holds, so a level's depth is O(1) instead of an O(k) fold. The
   running size is what makes [bbo] cheap; carrying a {e reference} to one of
   these in an [Aug_table] measure keeps the measure fresh across enqueues
   (the pointer is stable even as the depth behind it changes). *)
module Sized_q = struct
  module Q = Hash_queue.Make (Order_id)

  type t =
    { orders : Order.t Q.t
    ; mutable total_size : int
    }

  let create () = { orders = Q.create (); total_size = 0 }
  let size_of order = Size.to_int (Order.size order)

  let enqueue_back_exn t id order =
    Q.enqueue_back_exn t.orders id order;
    t.total_size <- t.total_size + size_of order
  ;;

  let remove t id =
    (match Q.lookup t.orders id with
     | None -> ()
     | Some order -> t.total_size <- t.total_size - size_of order);
    ignore (Q.remove t.orders id : [ `Ok | `No_such_key ])
  ;;

  let replace t id order =
    (match Q.lookup t.orders id with
     | None -> ()
     | Some old -> t.total_size <- t.total_size - size_of old + size_of order);
    ignore (Q.replace t.orders id order : [ `Ok | `No_such_key ])
  ;;

  let first t = Q.first t.orders
  let lookup t id = Q.lookup t.orders id
  let total_size t = t.total_size
end

module type Book_side = sig
  type t

  (* Fold the orders into a book in arrival (array/order_id) order — which is
     how a real book fills, and what keeps each level ordered oldest-first. *)
  val build : Order.t array -> t

  (* the price-time-priority best resting order *)
  val best : t -> Order.t option

  (* the best price and the total resting size at it *)
  val bbo : t -> (Price.t * int) option

  (* the order resting at [(price, order_id)], if any *)
  val find : t -> Price.t -> Order_id.t -> Order.t option

  (* replace the value at an already-present [(price, order_id)]; for the
     mutable representations this returns the same (mutated) [t] *)
  val update : t -> Order.t -> t

  (* add [order] then immediately remove it (net zero). [order]'s price must
     already have a level so the outer tree does not churn. *)
  val round_trip : t -> Order.t -> t

  (* drop the best price level off the index and re-insert it (net zero). The
     worst case for a design that caches the top of book: the cache is
     invalidated and must be rebuilt. *)
  val churn_top : t -> t
end

(* One persistent map keyed by [(-price_cents, order_id)]: [min_elt] is the
   highest price and, among ties, the earliest id — the best order. *)
module Flat : Book_side = struct
  module Rank_key = struct
    module T = struct
      type t = int * Order_id.t [@@deriving sexp, compare]
    end

    include T
    include Comparable.Make (T)
  end

  type t = Order.t Map.M(Rank_key).t

  let key_of price id = -Price.to_int_cents price, id
  let key order = key_of (Order.price order) (Order.order_id order)

  let build orders =
    Array.fold
      orders
      ~init:(Map.empty (module Rank_key))
      ~f:(fun m o -> Map.set m ~key:(key o) ~data:o)
  ;;

  let best t = Option.map (Map.min_elt t) ~f:snd

  (* The best price is the leading run of the map, so sum sizes from the
     front and stop as soon as the price changes: O(k), not O(N). *)
  let bbo t =
    match Map.min_elt t with
    | None -> None
    | Some ((neg_price, _), _) ->
      let total =
        With_return.with_return (fun { return } ->
          Map.fold t ~init:0 ~f:(fun ~key:(np, _) ~data acc ->
            if Int.equal np neg_price
            then acc + Size.to_int (Order.size data)
            else return acc))
      in
      Some (Price.of_int_cents (-neg_price), total)
  ;;

  let find t price id = Map.find t (key_of price id)
  let update t order = Map.set t ~key:(key order) ~data:order

  let round_trip t order =
    let k = key order in
    Map.remove (Map.set t ~key:k ~data:order) k
  ;;

  (* No cached top to rebuild: drop the leading run sharing the best price
     and re-insert it. O(k log N), the cost of clearing and rebuilding a
     level. *)
  let churn_top t =
    match Map.min_elt t with
    | None -> t
    | Some ((neg_price, _), _) ->
      let top =
        With_return.with_return (fun { return } ->
          Map.fold t ~init:[] ~f:(fun ~key ~data acc ->
            let neg, _id = key in
            if Int.equal neg neg_price
            then (key, data) :: acc
            else return acc))
      in
      let t = List.fold top ~init:t ~f:(fun t (k, _) -> Map.remove t k) in
      List.fold top ~init:t ~f:(fun t (k, d) -> Map.set t ~key:k ~data:d)
  ;;
end

(* price -> persistent Map(order_id -> order): fully persistent map of maps. *)
module Nested_map : Book_side = struct
  type t = Order.t Map.M(Order_id).t Key_aug_table.t

  let empty_inner : Order.t Map.M(Order_id).t = Map.empty (module Order_id)

  let add t order =
    let price = Order.price order in
    let inner =
      Option.value (Key_aug_table.find t price) ~default:empty_inner
    in
    let inner = Map.set inner ~key:(Order.order_id order) ~data:order in
    Key_aug_table.set t ~key:price ~data:inner
  ;;

  let build orders = Array.fold orders ~init:Key_aug_table.empty ~f:add

  let best t =
    match Key_aug_table.max_elt t with
    | None -> None
    | Some (_price, inner) -> Option.map (Map.min_elt inner) ~f:snd
  ;;

  let bbo t =
    match Key_aug_table.max_elt t with
    | None -> None
    | Some (price, inner) ->
      let total =
        Map.fold inner ~init:0 ~f:(fun ~key:_ ~data acc ->
          acc + Size.to_int (Order.size data))
      in
      Some (price, total)
  ;;

  let find t price id =
    match Key_aug_table.find t price with
    | None -> None
    | Some inner -> Map.find inner id
  ;;

  let update t order = add t order

  let round_trip t order =
    let price = Order.price order in
    let t = add t order in
    match Key_aug_table.find t price with
    | None -> t
    | Some inner ->
      let inner = Map.remove inner (Order.order_id order) in
      if Map.is_empty inner
      then Key_aug_table.remove t price
      else Key_aug_table.set t ~key:price ~data:inner
  ;;

  let churn_top t =
    match Key_aug_table.max_elt t with
    | None -> t
    | Some (price, inner) ->
      let t = Key_aug_table.remove t price in
      Key_aug_table.set t ~key:price ~data:inner
  ;;
end

(* price -> mutable sized hash queue, outer index [Key_aug_table].
   [best]/[bbo] reach the top level with [max_elt] — an O(log P) spine walk;
   the aug table's O(1) [max_key] measure is a price only, so it cannot
   answer [bbo]. *)
module Nested_hq : Book_side = struct
  type t = Sized_q.t Key_aug_table.t

  let add t order =
    let price = Order.price order in
    let id = Order.order_id order in
    match Key_aug_table.find t price with
    | Some q ->
      Sized_q.enqueue_back_exn q id order;
      t
    | None ->
      let q = Sized_q.create () in
      Sized_q.enqueue_back_exn q id order;
      Key_aug_table.set t ~key:price ~data:q
  ;;

  let build orders = Array.fold orders ~init:Key_aug_table.empty ~f:add

  let best t =
    match Key_aug_table.max_elt t with
    | None -> None
    | Some (_price, q) -> Sized_q.first q
  ;;

  let bbo t =
    match Key_aug_table.max_elt t with
    | None -> None
    | Some (price, q) -> Some (price, Sized_q.total_size q)
  ;;

  let find t price id =
    match Key_aug_table.find t price with
    | None -> None
    | Some q -> Sized_q.lookup q id
  ;;

  let update t order =
    (match Key_aug_table.find t (Order.price order) with
     | None -> ()
     | Some q -> Sized_q.replace q (Order.order_id order) order);
    t
  ;;

  let round_trip t order =
    (match Key_aug_table.find t (Order.price order) with
     | None -> ()
     | Some q ->
       let id = Order.order_id order in
       Sized_q.enqueue_back_exn q id order;
       Sized_q.remove q id);
    t
  ;;

  let churn_top t =
    match Key_aug_table.max_elt t with
    | None -> t
    | Some (price, q) ->
      let t = Key_aug_table.remove t price in
      Key_aug_table.set t ~key:price ~data:q
  ;;
end

(* Same sized hash queue, but the outer price index is a plain [Core.Map].
   [best]/[bbo] are a [Map.max_elt] walk — also O(log P) — so this is the
   honest O(log P) rival to [Nested_aug]'s O(1) measure. *)
module Nested_hq_map : Book_side = struct
  type t = Sized_q.t Map.M(Price).t

  let add t order =
    let price = Order.price order in
    let id = Order.order_id order in
    match Map.find t price with
    | Some q ->
      Sized_q.enqueue_back_exn q id order;
      t
    | None ->
      let q = Sized_q.create () in
      Sized_q.enqueue_back_exn q id order;
      Map.set t ~key:price ~data:q
  ;;

  let build orders =
    Array.fold orders ~init:(Map.empty (module Price)) ~f:add
  ;;

  let best t =
    match Map.max_elt t with
    | None -> None
    | Some (_price, q) -> Sized_q.first q
  ;;

  let bbo t =
    match Map.max_elt t with
    | None -> None
    | Some (price, q) -> Some (price, Sized_q.total_size q)
  ;;

  let find t price id =
    match Map.find t price with
    | None -> None
    | Some q -> Sized_q.lookup q id
  ;;

  let update t order =
    (match Map.find t (Order.price order) with
     | None -> ()
     | Some q -> Sized_q.replace q (Order.order_id order) order);
    t
  ;;

  let round_trip t order =
    (match Map.find t (Order.price order) with
     | None -> ()
     | Some q ->
       let id = Order.order_id order in
       Sized_q.enqueue_back_exn q id order;
       Sized_q.remove q id);
    t
  ;;

  let churn_top t =
    match Map.max_elt t with
    | None -> t
    | Some (price, q) ->
      let t = Map.remove t price in
      Map.set t ~key:price ~data:q
  ;;
end

(* price -> mutable sized hash queue, outer index a general [Aug_table] whose
   measure is [(best_price, queue_at_best_price)]. [Aug_table.measure]
   returns that root measure in O(1), so [best] and [bbo] never walk the
   tree: the measure hands back the winning queue (by reference, so it stays
   live) and the queue answers [first]/[total_size] in O(1). *)
module Nested_aug : Book_side = struct
  module Best = struct
    type key = Price.t
    type data = Sized_q.t

    (* [None] before any level exists; [Some (price, queue)] names the best
       level and carries its queue by reference. *)
    type measure = (Price.t * Sized_q.t) option

    let compare_key = Price.compare
    let measure_of_entry ~key ~data = Some (key, data)

    (* [identity] is the measure of an empty subtree — no level, so [None]. *)
    let identity : measure = None

    (* Keep the best (highest-price) level. A [None] subtree loses; two
       [Some]s never share a price (price is a unique key), so a plain max is
       a valid, associative monoid — which is what lets the root cache the
       top of book. *)
    let combine (a : measure) (b : measure) : measure =
      match a, b with
      | None, other | other, None -> other
      | Some (price_a, _), Some (price_b, _) ->
        if Price.compare price_a price_b >= 0 then a else b
    ;;
  end

  type t = (Price.t, Sized_q.t, (Price.t * Sized_q.t) option) Aug_table.t

  let empty () = Aug_table.empty (module Best)

  let add t order =
    let price = Order.price order in
    let id = Order.order_id order in
    match Aug_table.find t price with
    | Some q ->
      Sized_q.enqueue_back_exn q id order;
      t
    | None ->
      let q = Sized_q.create () in
      Sized_q.enqueue_back_exn q id order;
      Aug_table.set t ~key:price ~data:q
  ;;

  let build orders = Array.fold orders ~init:(empty ()) ~f:add

  let best t =
    match Aug_table.measure t with
    | None -> None
    | Some (_price, q) -> Sized_q.first q
  ;;

  let bbo t =
    match Aug_table.measure t with
    | None -> None
    | Some (price, q) -> Some (price, Sized_q.total_size q)
  ;;

  let find t price id =
    match Aug_table.find t price with
    | None -> None
    | Some q -> Sized_q.lookup q id
  ;;

  let update t order =
    (match Aug_table.find t (Order.price order) with
     | None -> ()
     | Some q -> Sized_q.replace q (Order.order_id order) order);
    t
  ;;

  let round_trip t order =
    (match Aug_table.find t (Order.price order) with
     | None -> ()
     | Some q ->
       let id = Order.order_id order in
       Sized_q.enqueue_back_exn q id order;
       Sized_q.remove q id);
    t
  ;;

  (* Drop the best level and re-insert it. [Aug_table.remove]/[set] recompute
     the measure — the top of book — for free as part of the same rebalance,
     so there is no explicit best lookup. This is the contrast with
     [Nested_hq_tracked]: two tree ops, no [max_elt]. *)
  let churn_top t =
    match Aug_table.measure t with
    | None -> t
    | Some (price, q) ->
      let t = Aug_table.remove t price in
      Aug_table.set t ~key:price ~data:q
  ;;
end

(* [Nested_hq_map] (plain [Core.Map] + sized hash queue) with one addition: a
   cached [(best_price, queue)] beside the map — the exact pair [Nested_aug]
   carries as its measure, but maintained by hand rather than baked into a
   custom tree. [best]/[bbo] read the cached field in O(1) (no [max_elt]
   walk), while [find]/[update]/[build] keep [Core.Map]'s tuned tree. The
   cache only needs refreshing when a new, higher level appears — a
   structural change that already rebuilds the record. (A book that also
   {e removed} the top level would re-derive the cache with one O(log P)
   [Map.max_elt], paid only when the best empties; this benchmark, like the
   other hash-queue designs, never removes a level.) *)
module Nested_hq_tracked : Book_side = struct
  type t =
    { levels : Sized_q.t Map.M(Price).t
    ; best : (Price.t * Sized_q.t) option
    (* the highest-price level and its queue, held by reference *)
    }

  let empty = { levels = Map.empty (module Price); best = None }

  let add t order =
    let price = Order.price order in
    let id = Order.order_id order in
    match Map.find t.levels price with
    | Some q ->
      (* Existing level: enqueue in place. Its price is already <= the cached
         best, so [best] is unchanged and the record is reused. *)
      Sized_q.enqueue_back_exn q id order;
      t
    | None ->
      let q = Sized_q.create () in
      Sized_q.enqueue_back_exn q id order;
      let levels = Map.set t.levels ~key:price ~data:q in
      (* A brand-new level [price -> q] was just inserted. Keep the cached
         [best] unless this level is a new highest price, in which case the
         top of book becomes [Some (price, q)]. Carry [q] by reference (not a
         size snapshot) so the cache stays live as the queue's depth changes
         in place — exactly how [Nested_aug]'s measure stays fresh. *)
      let best =
        match t.best with
        | None -> Some (price, q)
        | Some (best_price, _) ->
          if Price.compare price best_price > 0
          then Some (price, q)
          else t.best
      in
      { levels; best }
  ;;

  let build orders = Array.fold orders ~init:empty ~f:add

  let best t =
    match t.best with None -> None | Some (_price, q) -> Sized_q.first q
  ;;

  let bbo t =
    match t.best with
    | None -> None
    | Some (price, q) -> Some (price, Sized_q.total_size q)
  ;;

  let find t price id =
    match Map.find t.levels price with
    | None -> None
    | Some q -> Sized_q.lookup q id
  ;;

  let update t order =
    (match Map.find t.levels (Order.price order) with
     | None -> ()
     | Some q -> Sized_q.replace q (Order.order_id order) order);
    t
  ;;

  let round_trip t order =
    (match Map.find t.levels (Order.price order) with
     | None -> ()
     | Some q ->
       let id = Order.order_id order in
       Sized_q.enqueue_back_exn q id order;
       Sized_q.remove q id);
    t
  ;;

  (* Worst case for the cached best: dropping the top level invalidates the
     cache, so we re-derive it with an explicit O(log P) [Map.max_elt] — the
     work [Nested_aug]'s tree folds into the remove for free. Re-inserting
     the level restores the cache in O(1) (it is once again the max). *)
  let churn_top t =
    match t.best with
    | None -> t
    | Some (price, q) ->
      let dropped = Map.remove t.levels price in
      let t = { levels = dropped; best = Map.max_elt dropped } in
      let levels = Map.set t.levels ~key:price ~data:q in
      { levels; best = Some (price, q) }
  ;;
end

let tests_for_config ~levels =
  let orders = make_orders ~levels in
  let n = Array.length orders in
  (* a present, mid-book order (for find/update) *)
  let existing = orders.(n / 2) in
  let existing_price = Order.price existing in
  let existing_id = Order.order_id existing in
  (* a transient order at the (existing) top price with a fresh id, for the
     add+remove round trip *)
  let transient =
    make_order
      ~price:(Price.of_int_cents (base_cents + levels - 1))
      ~order_id:(Order_id.For_testing.of_int (n + 1))
  in
  let flat = Flat.build orders in
  let nmap = Nested_map.build orders in
  let nhq = Nested_hq.build orders in
  let nhqm = Nested_hq_map.build orders in
  let aug = Nested_aug.build orders in
  let nhqt = Nested_hq_tracked.build orders in
  (* Correctness guard. Every price level holds [orders_per_level] orders, so
     [best] is always resolved through a price tie; the correct winner is the
     earliest arrival (smallest order_id) at the top price, i.e. the first
     order built for that level, [orders.(n - orders_per_level)]. [bbo] must
     name that top price and the total resting size there ([orders_per_level]
     orders of [size]). Checking against those known answers — not just
     mutual agreement — verifies each representation breaks the tie by time
     priority and sums depth correctly. *)
  let same a b = Option.equal Order.equal a b in
  let same_bbo a b =
    Option.equal
      (fun (p1, s1) (p2, s2) -> Price.equal p1 p2 && Int.equal s1 s2)
      a
      b
  in
  let best_under_tie = orders.(n - orders_per_level) in
  let top_price = Price.of_int_cents (base_cents + levels - 1) in
  let bbo_expected =
    Some (top_price, orders_per_level * Size.to_int (Order.size orders.(0)))
  in
  assert (same (Flat.best flat) (Some best_under_tie));
  assert (same (Nested_map.best nmap) (Some best_under_tie));
  assert (same (Nested_hq.best nhq) (Some best_under_tie));
  assert (same (Nested_hq_map.best nhqm) (Some best_under_tie));
  assert (same (Nested_aug.best aug) (Some best_under_tie));
  assert (same (Nested_hq_tracked.best nhqt) (Some best_under_tie));
  assert (same_bbo (Flat.bbo flat) bbo_expected);
  assert (same_bbo (Nested_map.bbo nmap) bbo_expected);
  assert (same_bbo (Nested_hq.bbo nhq) bbo_expected);
  assert (same_bbo (Nested_hq_map.bbo nhqm) bbo_expected);
  assert (same_bbo (Nested_aug.bbo aug) bbo_expected);
  assert (same_bbo (Nested_hq_tracked.bbo nhqt) bbo_expected);
  assert (same (Flat.find flat existing_price existing_id) (Some existing));
  assert (
    same (Nested_map.find nmap existing_price existing_id) (Some existing));
  assert (
    same (Nested_hq.find nhq existing_price existing_id) (Some existing));
  assert (
    same (Nested_hq_map.find nhqm existing_price existing_id) (Some existing));
  assert (
    same (Nested_aug.find aug existing_price existing_id) (Some existing));
  assert (
    same
      (Nested_hq_tracked.find nhqt existing_price existing_id)
      (Some existing));
  (* [churn_top] is net zero, so the top of book must be unchanged afterward.
     This checks [Nested_hq_tracked]'s [max_elt] fallback and [Nested_aug]'s
     measure refresh actually restore the right best. *)
  assert (same (Flat.best (Flat.churn_top flat)) (Some best_under_tie));
  assert (
    same (Nested_map.best (Nested_map.churn_top nmap)) (Some best_under_tie));
  assert (
    same (Nested_hq.best (Nested_hq.churn_top nhq)) (Some best_under_tie));
  assert (
    same
      (Nested_hq_map.best (Nested_hq_map.churn_top nhqm))
      (Some best_under_tie));
  assert (
    same (Nested_aug.best (Nested_aug.churn_top aug)) (Some best_under_tie));
  assert (
    same
      (Nested_hq_tracked.best (Nested_hq_tracked.churn_top nhqt))
      (Some best_under_tie));
  assert (same_bbo (Nested_aug.bbo (Nested_aug.churn_top aug)) bbo_expected);
  assert (
    same_bbo
      (Nested_hq_tracked.bbo (Nested_hq_tracked.churn_top nhqt))
      bbo_expected);
  let test label f =
    Bench.Test.create ~name:[%string "%{label} P=%{levels#Int}"] f
  in
  [ test "flat build" (fun () -> ignore (Flat.build orders : Flat.t))
  ; test "nmap build" (fun () ->
      ignore (Nested_map.build orders : Nested_map.t))
  ; test "nhq build" (fun () ->
      ignore (Nested_hq.build orders : Nested_hq.t))
  ; test "nhqm build" (fun () ->
      ignore (Nested_hq_map.build orders : Nested_hq_map.t))
  ; test "aug build" (fun () ->
      ignore (Nested_aug.build orders : Nested_aug.t))
  ; test "nhqt build" (fun () ->
      ignore (Nested_hq_tracked.build orders : Nested_hq_tracked.t))
  ; test "flat find" (fun () ->
      ignore (Flat.find flat existing_price existing_id : Order.t option))
  ; test "nmap find" (fun () ->
      ignore
        (Nested_map.find nmap existing_price existing_id : Order.t option))
  ; test "nhq find" (fun () ->
      ignore (Nested_hq.find nhq existing_price existing_id : Order.t option))
  ; test "nhqm find" (fun () ->
      ignore
        (Nested_hq_map.find nhqm existing_price existing_id : Order.t option))
  ; test "aug find" (fun () ->
      ignore
        (Nested_aug.find aug existing_price existing_id : Order.t option))
  ; test "nhqt find" (fun () ->
      ignore
        (Nested_hq_tracked.find nhqt existing_price existing_id
         : Order.t option))
  ; test "flat best" (fun () -> ignore (Flat.best flat : Order.t option))
  ; test "nmap best" (fun () ->
      ignore (Nested_map.best nmap : Order.t option))
  ; test "nhq best" (fun () -> ignore (Nested_hq.best nhq : Order.t option))
  ; test "nhqm best" (fun () ->
      ignore (Nested_hq_map.best nhqm : Order.t option))
  ; test "aug best" (fun () -> ignore (Nested_aug.best aug : Order.t option))
  ; test "nhqt best" (fun () ->
      ignore (Nested_hq_tracked.best nhqt : Order.t option))
  ; test "flat bbo" (fun () ->
      ignore (Flat.bbo flat : (Price.t * int) option))
  ; test "nmap bbo" (fun () ->
      ignore (Nested_map.bbo nmap : (Price.t * int) option))
  ; test "nhq bbo" (fun () ->
      ignore (Nested_hq.bbo nhq : (Price.t * int) option))
  ; test "nhqm bbo" (fun () ->
      ignore (Nested_hq_map.bbo nhqm : (Price.t * int) option))
  ; test "aug bbo" (fun () ->
      ignore (Nested_aug.bbo aug : (Price.t * int) option))
  ; test "nhqt bbo" (fun () ->
      ignore (Nested_hq_tracked.bbo nhqt : (Price.t * int) option))
  ; test "flat update" (fun () ->
      ignore (Flat.update flat existing : Flat.t))
  ; test "nmap update" (fun () ->
      ignore (Nested_map.update nmap existing : Nested_map.t))
  ; test "nhq update" (fun () ->
      ignore (Nested_hq.update nhq existing : Nested_hq.t))
  ; test "nhqm update" (fun () ->
      ignore (Nested_hq_map.update nhqm existing : Nested_hq_map.t))
  ; test "aug update" (fun () ->
      ignore (Nested_aug.update aug existing : Nested_aug.t))
  ; test "nhqt update" (fun () ->
      ignore (Nested_hq_tracked.update nhqt existing : Nested_hq_tracked.t))
  ; test "flat add+remove" (fun () ->
      ignore (Flat.round_trip flat transient : Flat.t))
  ; test "nmap add+remove" (fun () ->
      ignore (Nested_map.round_trip nmap transient : Nested_map.t))
  ; test "nhq add+remove" (fun () ->
      ignore (Nested_hq.round_trip nhq transient : Nested_hq.t))
  ; test "nhqm add+remove" (fun () ->
      ignore (Nested_hq_map.round_trip nhqm transient : Nested_hq_map.t))
  ; test "aug add+remove" (fun () ->
      ignore (Nested_aug.round_trip aug transient : Nested_aug.t))
  ; test "nhqt add+remove" (fun () ->
      ignore
        (Nested_hq_tracked.round_trip nhqt transient : Nested_hq_tracked.t))
  ; test "flat churn" (fun () -> ignore (Flat.churn_top flat : Flat.t))
  ; test "nmap churn" (fun () ->
      ignore (Nested_map.churn_top nmap : Nested_map.t))
  ; test "nhq churn" (fun () ->
      ignore (Nested_hq.churn_top nhq : Nested_hq.t))
  ; test "nhqm churn" (fun () ->
      ignore (Nested_hq_map.churn_top nhqm : Nested_hq_map.t))
  ; test "aug churn" (fun () ->
      ignore (Nested_aug.churn_top aug : Nested_aug.t))
  ; test "nhqt churn" (fun () ->
      ignore (Nested_hq_tracked.churn_top nhqt : Nested_hq_tracked.t))
  ]
;;

let () =
  (* Vary P (price levels) with k fixed: a realistic book (~hundreds of
     levels) and a stress book (thousands), to see where the O(1) measure
     overtakes the O(log P) walk. *)
  let tests =
    List.concat_map [ 128; 8192 ] ~f:(fun levels -> tests_for_config ~levels)
  in
  Command_unix.run (Bench.make_command tests)
;;
