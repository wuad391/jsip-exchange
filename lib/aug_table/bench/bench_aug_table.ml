(** Benchmark: [Aug_table] vs [Core.Map], via [core_bench].

    Keys are ints, values orders, and the measure is the largest key
    ([combine = max], [identity = 0]). We compare creation, add, remove,
    find, fold, and measure/reduce. The operation of interest is [measure]:
    aug_table returns the cached root measure in O(1), whereas Core.Map has
    no cached reduce and must fold in O(n) to recompute the same value. For
    this particular measure (max key) Map also has the specialized O(log n)
    [max_elt], benched as an honest reference.

    Because both structures are persistent, repeating a single [add]/[remove]
    on a fixed base is a clean microbenchmark (the base is never mutated), so
    core_bench can time every operation directly.

    Run:
    {v
      dune exec lib/aug_table/bench/bench_aug_table.exe -- -ascii -quota 1 \
        > performance/runs/aug_table_vs_map.txt
    v} *)

open! Core
open Core_bench
open Jsip_types
open Jsip_aug_table

(* The augmentation under test: measure = the largest key present. *)
module By_max_key = struct
  type key = int
  type data = Order.t
  type measure = int

  let compare_key = Int.compare
  let identity = 0
  let combine = Int.max
  let measure_of_entry ~key ~data:_ = key
end

type aug = (int, Order.t, int) Aug_table.t
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
  let build_aug () =
    Array.fold
      keys
      ~init:(Aug_table.empty (module By_max_key))
      ~f:(fun t k -> Aug_table.set t ~key:k ~data:order)
  in
  let build_map () =
    Array.fold
      keys
      ~init:(Map.empty (module Int))
      ~f:(fun t k -> Map.set t ~key:k ~data:order)
  in
  let aug = build_aug () in
  let map = build_map () in
  let test label f =
    Bench.Test.create ~name:[%string "%{label} n=%{n#Int}"] f
  in
  [ test "aug creation" (fun () -> ignore (build_aug () : aug))
  ; test "map creation" (fun () -> ignore (build_map () : map))
  ; test "aug add" (fun () ->
      ignore (Aug_table.set aug ~key:absent ~data:order : aug))
  ; test "map add" (fun () ->
      ignore (Map.set map ~key:absent ~data:order : map))
  ; test "aug remove" (fun () -> ignore (Aug_table.remove aug present : aug))
  ; test "map remove" (fun () -> ignore (Map.remove map present : map))
  ; test "aug find" (fun () ->
      ignore (Aug_table.find aug present : Order.t option))
  ; test "map find" (fun () ->
      ignore (Map.find map present : Order.t option))
  ; test "aug fold" (fun () ->
      ignore
        (Aug_table.fold aug ~init:0 ~f:(fun ~key ~data:_ acc -> acc + key)
         : int))
  ; test "map fold" (fun () ->
      ignore
        (Map.fold map ~init:0 ~f:(fun ~key ~data:_ acc -> acc + key) : int))
  ; test "aug measure O(1)" (fun () -> ignore (Aug_table.measure aug : int))
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
