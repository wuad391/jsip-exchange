(** Benchmark: [Aug_table] vs [Key_monoid_table] vs [Key_aug_table] vs
    [Core.Map], via [core_bench].

    Keys are ints (except [kmono], keyed by [Price.t] = int cents), values
    orders, and the measure is the largest key present. The monoid is the
    same "max" for every contender ([Int.max], or [Price.max] for [kmono]),
    so they stay directly comparable. Four rungs, each removing one cost from
    the rung above it:

    - [aug]: the fully generic {!Aug_table} — ordering, monoid, and
      [measure_of_entry] all supplied as closures over a separate ['measure]
      type.
    - [kpoly]: {!Key_monoid_table} — the measure collapsed into the key type,
      so [measure_of_entry] and the separate ['measure] type are gone;
      [compare_key] and [combine] are still closures (keys stay polymorphic).
      So [aug] vs [kpoly] isolates the cost of [measure_of_entry] + the
      separate measure type.
    - [kmono]: {!Key_aug_table} — the same tree monomorphized to [Price.t]
      keys with [Price.max] named directly, no closures at all. [kpoly] vs
      [kmono] isolates monomorphization (with the caveat that [Price.max] is
      a [Comparable.Make] direct call, not an [int] primitive, and [Price.t]
      is still unboxed int cents so the tree shape is unchanged).
    - [map]: {!Core.Map} — no measure at all, plus its [Leaf] specialization
      and tuning. [kmono] vs [map] isolates those.

    All four are persistent, so repeating a single [add]/[remove] on a fixed
    base is a clean microbenchmark (the base is never mutated).

    Run:
    {v
      dune exec lib/aug_table/bench/bench_aug_table.exe -- -ascii -quota 1 \
        > performance/runs/aug_table_vs_map.txt
    v} *)

open! Core
open Core_bench
open Jsip_types
open Jsip_aug_table

(* measure = largest key. [Aug_table] needs a full [Arg] (with a separate
   measure type and [measure_of_entry]); [Key_monoid_table] needs the same
   monoid but over the key type, with neither. *)
module Aug_by_max = struct
  type key = int
  type data = Order.t
  type measure = int

  let compare_key = Int.compare
  let identity = 0
  let combine = Int.max
  let measure_of_entry ~key ~data:_ = key
end

module Kpoly_by_max = struct
  type key = int

  let compare_key = Int.compare
  let identity = 0
  let combine = Int.max
end

type aug = (int, Order.t, int) Aug_table.t
type kpoly = (int, Order.t) Key_monoid_table.t
type kmono = Order.t Key_aug_table.t
type map = (int, Order.t, Int.comparator_witness) Map.t

(* Values are irrelevant to the measure and to tree shape (keyed by int), so
   a single shared order is fine as filler. *)
let order =
  let gen = Order_id.Generator.create () in
  Order.create
    { symbol = Symbol.of_string "AAPL"
    ; participant = Participant.of_string "Alice"
    ; side = Buy
    ; price = Price.of_int_cents 10_000
    ; size = Size.of_int 100
    ; time_in_force = Day
    ; client_order_id = Client_order_id.of_int 1
    }
    ~order_id:(Order_id.Generator.next gen)
;;

let tests_for_size n =
  (* keys 0..n-1 in a scrambled but deterministic order (97 is coprime with
     both sizes, so this is a permutation) *)
  let keys = Array.init n ~f:(fun i -> i * 97 mod n) in
  let present = keys.(0) in
  let absent = n in
  (* [Key_aug_table] is keyed by [Price.t] (= unboxed int cents), so it takes
     price-typed versions of the same keys; the tree shape is identical. *)
  let present_price = Price.of_int_cents present in
  let absent_price = Price.of_int_cents absent in
  let build_aug () =
    Array.fold
      keys
      ~init:(Aug_table.empty (module Aug_by_max))
      ~f:(fun t k -> Aug_table.set t ~key:k ~data:order)
  in
  let build_kpoly () =
    Array.fold
      keys
      ~init:(Key_monoid_table.empty (module Kpoly_by_max))
      ~f:(fun t k -> Key_monoid_table.set t ~key:k ~data:order)
  in
  let build_kmono () =
    Array.fold keys ~init:Key_aug_table.empty ~f:(fun t k ->
      Key_aug_table.set t ~key:(Price.of_int_cents k) ~data:order)
  in
  let build_map () =
    Array.fold
      keys
      ~init:(Map.empty (module Int))
      ~f:(fun t k -> Map.set t ~key:k ~data:order)
  in
  let aug = build_aug () in
  let kpoly = build_kpoly () in
  let kmono = build_kmono () in
  let map = build_map () in
  let test label f =
    Bench.Test.create ~name:[%string "%{label} n=%{n#Int}"] f
  in
  [ test "aug creation" (fun () -> ignore (build_aug () : aug))
  ; test "kpoly creation" (fun () -> ignore (build_kpoly () : kpoly))
  ; test "kmono creation" (fun () -> ignore (build_kmono () : kmono))
  ; test "map creation" (fun () -> ignore (build_map () : map))
  ; test "aug add" (fun () ->
      ignore (Aug_table.set aug ~key:absent ~data:order : aug))
  ; test "kpoly add" (fun () ->
      ignore (Key_monoid_table.set kpoly ~key:absent ~data:order : kpoly))
  ; test "kmono add" (fun () ->
      ignore (Key_aug_table.set kmono ~key:absent_price ~data:order : kmono))
  ; test "map add" (fun () ->
      ignore (Map.set map ~key:absent ~data:order : map))
  ; test "aug remove" (fun () -> ignore (Aug_table.remove aug present : aug))
  ; test "kpoly remove" (fun () ->
      ignore (Key_monoid_table.remove kpoly present : kpoly))
  ; test "kmono remove" (fun () ->
      ignore (Key_aug_table.remove kmono present_price : kmono))
  ; test "map remove" (fun () -> ignore (Map.remove map present : map))
  ; test "aug find" (fun () ->
      ignore (Aug_table.find aug present : Order.t option))
  ; test "kpoly find" (fun () ->
      ignore (Key_monoid_table.find kpoly present : Order.t option))
  ; test "kmono find" (fun () ->
      ignore (Key_aug_table.find kmono present_price : Order.t option))
  ; test "map find" (fun () ->
      ignore (Map.find map present : Order.t option))
  ; test "aug fold" (fun () ->
      ignore
        (Aug_table.fold aug ~init:0 ~f:(fun ~key ~data:_ acc -> acc + key)
         : int))
  ; test "kpoly fold" (fun () ->
      ignore
        (Key_monoid_table.fold kpoly ~init:0 ~f:(fun ~key ~data:_ acc ->
           acc + key)
         : int))
  ; test "kmono fold" (fun () ->
      ignore
        (Key_aug_table.fold kmono ~init:0 ~f:(fun ~key ~data:_ acc ->
           acc + Price.to_int_cents key)
         : int))
  ; test "map fold" (fun () ->
      ignore
        (Map.fold map ~init:0 ~f:(fun ~key ~data:_ acc -> acc + key) : int))
  ; test "aug measure O(1)" (fun () -> ignore (Aug_table.measure aug : int))
  ; test "kpoly measure O(1)" (fun () ->
      ignore (Key_monoid_table.measure kpoly : int))
  ; test "kmono measure O(1)" (fun () ->
      ignore (Key_aug_table.max_key kmono : Price.t))
  ; test "map measure O(n) fold" (fun () ->
      ignore
        (Map.fold map ~init:0 ~f:(fun ~key ~data:_ acc -> Int.max acc key)
         : int))
  ; test "map measure O(log n) max_elt" (fun () ->
      ignore (Map.max_elt map : (int * Order.t) option))
  ]
;;

let () =
  let tests = List.concat_map [ 1_000; 100_000 ] ~f:tests_for_size in
  Command_unix.run (Bench.make_command tests)
;;
