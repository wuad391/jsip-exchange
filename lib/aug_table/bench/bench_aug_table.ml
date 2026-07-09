(** Benchmark: [Aug_table] vs [Core.Map].

    Keys are ints, values are orders, and the measure is the largest key
    ([combine = max], [identity = 0]). That lets us time the one operation
    the augmented table exists for — a whole-collection reduce — against Map,
    where the same max-key result costs an O(n) fold.

    Run (writes the comparison table to stdout):
    {v
      dune exec lib/aug_table/bench/bench_aug_table.exe \
        > performance/runs/aug_table_vs_map.txt
    v}

    Methodology: a simple best-of-N microbenchmark. Each operation runs as a
    batch of [ops] with the structure built *outside* the timed region; we
    keep the fastest trial (least disturbed by a GC pause) and report ns/op.
    This is a teaching comparison, not a core_bench-grade regression suite. *)

open! Core
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
let sample_order () =
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

(* Best-of-[trials]: run [f], which performs [ops] operations, and return the
   fastest observed ns/op — best-of rather than average so a GC pause in one
   trial doesn't inflate the estimate of intrinsic cost. *)
let ns_per_op ~ops ~trials ~f =
  let best = ref Float.infinity in
  for _ = 1 to trials do
    let start = Time_ns.now () in
    f ();
    let stop = Time_ns.now () in
    let per_op =
      Time_ns.Span.to_ns (Time_ns.diff stop start) /. Float.of_int ops
    in
    if Float.( < ) per_op !best then best := per_op
  done;
  !best
;;

(* Threaded through the read-only ops so the compiler cannot drop them. *)
let sink = ref 0
let sizes = [ 1_000; 100_000 ]
let trials = 5

let () =
  let order = sample_order () in
  printf
    "Aug_table vs Core.Map — keys:int values:Order.t measure:max-key \
     (combine=max, identity=0)\n";
  printf "best-of-%d trials; ns per operation, lower is better\n\n" trials;
  printf
    "  %-10s %-9s %13s %13s %10s\n"
    "op"
    "n"
    "aug_table"
    "core_map"
    "map/aug";
  printf "  %s\n" (String.make 59 '-');
  List.iter sizes ~f:(fun n ->
    (* keys 0..n-1 in a scrambled but deterministic order (97 is coprime with
       both sizes, so this is a permutation) *)
    let keys = Array.init n ~f:(fun i -> i * 97 mod n) in
    let fresh = Array.init n ~f:(fun i -> n + i) in
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
    let aug_base = build_aug () in
    let map_base = build_map () in
    let row op ~aug_ns ~map_ns =
      printf
        "  %-10s %-9d %13.1f %13.1f %9.1fx\n"
        op
        n
        aug_ns
        map_ns
        (map_ns /. aug_ns)
    in
    row
      "creation"
      ~aug_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () -> ignore (build_aug () : aug)))
      ~map_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () -> ignore (build_map () : map)));
    row
      "add"
      ~aug_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           Array.iter fresh ~f:(fun k ->
             ignore (Aug_table.set aug_base ~key:k ~data:order : aug))))
      ~map_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           Array.iter fresh ~f:(fun k ->
             ignore (Map.set map_base ~key:k ~data:order : map))));
    row
      "remove"
      ~aug_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           Array.iter keys ~f:(fun k ->
             ignore (Aug_table.remove aug_base k : aug))))
      ~map_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           Array.iter keys ~f:(fun k -> ignore (Map.remove map_base k : map))));
    row
      "find"
      ~aug_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           Array.iter keys ~f:(fun k ->
             match Aug_table.find aug_base k with
             | Some _ -> incr sink
             | None -> ())))
      ~map_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           Array.iter keys ~f:(fun k ->
             match Map.find map_base k with
             | Some _ -> incr sink
             | None -> ())));
    row
      "fold"
      ~aug_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           sink
           := !sink
              + Aug_table.fold aug_base ~init:0 ~f:(fun ~key ~data:_ acc ->
                acc + key)))
      ~map_ns:
        (ns_per_op ~ops:n ~trials ~f:(fun () ->
           sink
           := !sink
              + Map.fold map_base ~init:0 ~f:(fun ~key ~data:_ acc ->
                acc + key)));
    (* measure/reduce: aug_table reads the cached root measure (O(1)); Map
       must fold to recompute the max key (O(n)). We report ns per
       reduce-call, so the per-call budgets differ to keep total work
       bounded. *)
    let aug_calls = 1_000_000 in
    let map_calls = Int.max 1 (1_000_000 / n) in
    row
      "measure"
      ~aug_ns:
        (ns_per_op ~ops:aug_calls ~trials ~f:(fun () ->
           for _ = 1 to aug_calls do
             sink := !sink + Aug_table.measure aug_base
           done))
      ~map_ns:
        (ns_per_op ~ops:map_calls ~trials ~f:(fun () ->
           for _ = 1 to map_calls do
             sink
             := !sink
                + Map.fold map_base ~init:0 ~f:(fun ~key ~data:_ acc ->
                  Int.max acc key)
           done));
    (* For THIS measure (max key) Map has a specialized O(log n) accessor;
       the O(n) fold above stands in for a general monoid Map cannot
       shortcut. *)
    let map_maxelt_ns =
      ns_per_op ~ops:aug_calls ~trials ~f:(fun () ->
        for _ = 1 to aug_calls do
          match Map.max_elt map_base with
          | Some (k, _) -> sink := !sink + k
          | None -> ()
        done)
    in
    printf
      "             (Core.Map.max_elt gets this measure in O(log n): %.1f \
       ns/call)\n"
      map_maxelt_ns;
    printf "\n");
  printf "notes:\n";
  printf
    "  measure: aug_table returns the cached root measure in O(1), for any \
     monoid.\n";
  printf
    "  Core.Map has no cached reduce, so a general measure costs an O(n) \
     fold (shown).\n";
  printf
    "  For this particular measure (max key), Core.Map.max_elt is a special \
     O(log n)\n";
  printf "  case (shown per-n above), not O(n).\n";
  printf
    "  creation/add/remove/find: O(log n) both; the 2-5x favoring Core.Map \
     is its\n";
  printf
    "  constant-factor edge (Leaf-specialized nodes, tuned paths) plus the \
     measure\n";
  printf "  aug_table maintains on every write.\n";
  eprintf "checksum: %d\n" !sink
;;
