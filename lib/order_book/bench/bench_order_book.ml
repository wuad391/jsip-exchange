(** Benchmarks for the order book and matching engine.

    Run with: dune exec lib/order_book/bench/bench_order_book.exe -- -ascii
    -quota 5

    These benchmarks measure the core operations of the exchange and are
    designed to give you meaningful feedback on the performance of the system
    and the effect of any optimizations you make.

    {2 How to read the results}

    Core_bench reports time per operation in nanoseconds. Lower is better.
    Focus on:
    - [find_match]: the hot path — called on every incoming order
    - [submit_ioc_cross]: end-to-end order submission with a fill
    - [add/remove]: book mutation performance
    - [best_price]: how fast you can query the BBO

    {2 Tips for meaningful benchmarks}

    {ul
     {- Use [-quota 5] or higher for stable results (5 seconds per bench). }
     {- Run on a quiet machine (no heavy background processes). }
     {- Compare before/after by saving results:

       {v
          dune exec lib/order_book/bench/bench_order_book.exe -- -ascii -quota 5 > before.txt
          # ... make your changes ...
          dune exec lib/order_book/bench/bench_order_book.exe -- -ascii -quota 5 > after.txt
          diff before.txt after.txt
       v}
    }
    } *)

open! Core
open Core_bench
open Jsip_types
open Jsip_order_book

(* ---------------------------------------------------------------- *)
(* Setup helpers *)
(* ---------------------------------------------------------------- *)

let aapl = Symbol.of_string "AAPL"
let alice = Participant.of_string "Alice"
let bob = Participant.of_string "Bob"
let client_order_id_test_ref = ref 1

let new_client_order_id () =
  client_order_id_test_ref := !client_order_id_test_ref + 1;
  Client_order_id.of_int !client_order_id_test_ref
;;

(** Build a book with [n] resting sell orders. By default they sit at
    distinct prices 1..n (in cents) above [min_price], giving a realistic
    spread for benchmarking find_match and best_price queries. Pass
    [~same_price:true] to stack all [n] orders at [min_price] instead —
    useful for benchmarking operations (like snapshot aggregation) whose cost
    depends on how many orders share a price level. *)
let book_with_n_asks ?(min_price = 10_000) ?(same_price = false) n =
  let book = Order_book.create aapl in
  let gen = Order_id.Generator.create () in
  for i = 1 to n do
    let order =
      Order.create
        { symbol = aapl
        ; participant = bob
        ; side = Sell
        ; price =
            Price.of_int_cents
              (if same_price then min_price else min_price + i)
        ; size = Size.of_int 100
        ; time_in_force = Day
        ; client_order_id = new_client_order_id ()
        }
        ~order_id:(Order_id.Generator.next gen)
    in
    Order_book.add book order
  done;
  book, gen
;;

(** Build a matching engine with [n] resting sells on AAPL. *)
let engine_with_n_asks ?(min_price = 10_000) n =
  let engine = Matching_engine.create [ aapl ] in
  for i = 1 to n do
    ignore
      (Matching_engine.submit
         engine
         ~participant:bob
         { symbol = aapl
         ; participant = bob
         ; side = Sell
         ; price = Price.of_int_cents (min_price + i)
         ; size = Size.of_int 100
         ; time_in_force = Day
         ; client_order_id = new_client_order_id ()
         }
       : Exchange_event.t list)
  done;
  engine
;;

(** Build a matching engine trading [n] distinct (empty) symbols. Returns the
    engine and the last symbol created, so a lookup pays the full cost
    regardless of how the underlying structure orders its keys. *)
let engine_with_n_symbols n =
  let symbols =
    List.init n ~f:(fun i -> Symbol.of_string [%string "SYM%{i#Int}"])
  in
  Matching_engine.create symbols, List.last_exn symbols
;;

(* ---------------------------------------------------------------- *)
(* Order_book micro-benchmarks *)
(* ---------------------------------------------------------------- *)

let bench_find_match ~n =
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  (* Incoming buy at a price that matches the best ask *)
  let incoming =
    Order.create
      { symbol = aapl
      ; participant = alice
      ; side = Buy
      ; price = Price.of_int_cents (min_price + n)
      ; size = Size.of_int 100
      ; time_in_force = Ioc
      ; client_order_id = new_client_order_id ()
      }
      ~order_id:(Order_id.Generator.next gen)
  in
  Bench.Test.create ~name:[%string "find_match (n=%{n#Int})"] (fun () ->
    ignore (Order_book.find_match book incoming : Order.t option))
;;

let bench_find_match_no_cross ~n =
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  (* Incoming buy at a price below all asks — no match possible *)
  let incoming =
    Order.create
      { symbol = aapl
      ; participant = alice
      ; side = Buy
      ; price = Price.of_int_cents (min_price - 1)
      ; size = Size.of_int 100
      ; time_in_force = Ioc
      ; client_order_id = new_client_order_id ()
      }
      ~order_id:(Order_id.Generator.next gen)
  in
  Bench.Test.create ~name:[%string "find_match_miss (n=%{n#Int})"] (fun () ->
    ignore (Order_book.find_match book incoming : Order.t option))
;;

let bench_best_bid_offer ~n =
  let book, _gen = book_with_n_asks n in
  Bench.Test.create ~name:[%string "best_bid_offer (n=%{n#Int})"] (fun () ->
    ignore (Order_book.best_bid_offer book : Bbo.t))
;;

let bench_add_remove ~n =
  (* Pre-build the book, then measure add+remove cycle *)
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  let order =
    Order.create
      { symbol = aapl
      ; participant = alice
      ; side = Sell
      ; price = Price.of_int_cents (min_price + 500)
      ; size = Size.of_int 100
      ; time_in_force = Day
      ; client_order_id = new_client_order_id ()
      }
      ~order_id:(Order_id.Generator.next gen)
  in
  let oid = Order.order_id order in
  Bench.Test.create ~name:[%string "add+remove (n=%{n#Int})"] (fun () ->
    Order_book.add book order;
    Order_book.remove book oid)
;;

let bench_snapshot ~n =
  (* All [n] orders stack at a single price, so this measures the aggregation
     cost that a book spread across distinct prices (like
     [book_with_n_asks]'s default) wouldn't exercise at all. *)
  let book, _gen = book_with_n_asks ~same_price:true n in
  Bench.Test.create ~name:[%string "snapshot (n=%{n#Int})"] (fun () ->
    ignore (Order_book.snapshot book : Book.t))
;;

(* ---------------------------------------------------------------- *)
(* Basic functions: unit cost of each order-book base operation *)
(* ---------------------------------------------------------------- *)

(* These isolate the individual building blocks the matching engine leans on,
   so we can read each one's cost curve as the book deepens at a fixed price
   band. The story is in the slopes: [find] and [count] are O(1);
   [find_match] is a single [Map.min_elt] (O(log n), effectively flat);
   [best_bid_offer] and [orders_on_side] walk the whole side via
   [Map.to_alist], so they climb linearly. Pair these with the
   [-count-orders] scenario tally (how often each runs) to see where
   wall-clock actually goes. *)

let bench_find ~n =
  (* Look up an id known to be resting: seed one extra order past the band
     and keep its id, so every call is a guaranteed hit through the id
     hashtable. *)
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  let order =
    Order.create
      { symbol = aapl
      ; participant = bob
      ; side = Sell
      ; price = Price.of_int_cents (min_price + n + 1)
      ; size = Size.of_int 100
      ; time_in_force = Day
      ; client_order_id = new_client_order_id ()
      }
      ~order_id:(Order_id.Generator.next gen)
  in
  Order_book.add book order;
  let oid = Order.order_id order in
  Bench.Test.create ~name:[%string "find (n=%{n#Int})"] (fun () ->
    ignore (Order_book.find book oid : Order.t option))
;;

let bench_count ~n =
  let book, _gen = book_with_n_asks n in
  Bench.Test.create ~name:[%string "count (n=%{n#Int})"] (fun () ->
    ignore (Order_book.count book Sell : int))
;;

let bench_orders_on_side ~n =
  let book, _gen = book_with_n_asks n in
  Bench.Test.create ~name:[%string "orders_on_side (n=%{n#Int})"] (fun () ->
    ignore (Order_book.orders_on_side book Sell : Order.t list))
;;

(* ---------------------------------------------------------------- *)
(* Separate add / remove timing (manual — core_bench can't isolate them) *)
(* ---------------------------------------------------------------- *)

(** Pre-generate [n] distinct-price sell orders, not yet in any book, so a
    benchmark can add or remove them with all order construction done up
    front and outside the timed region. Safe to replay into a fresh book each
    trial: [Order_book.add] keys on the order id, and a fresh book starts
    with an empty id table, so the shared orders never collide. *)
let pregenerate_asks ?(min_price = 10_000) n =
  let gen = Order_id.Generator.create () in
  Array.init n ~f:(fun i ->
    Order.create
      { symbol = aapl
      ; participant = bob
      ; side = Sell
      ; price = Price.of_int_cents (min_price + i)
      ; size = Size.of_int 100
      ; time_in_force = Day
      ; client_order_id = new_client_order_id ()
      }
      ~order_id:(Order_id.Generator.next gen))
;;

(* core_bench times a whole closure and chooses its own batch sizes, so it
   can't isolate a single [add] or [remove]: the op isn't reversible, so
   repeating it either grows the book without bound (add) or drains it and
   then measures no-op misses (remove). Instead we time a batch of [n] of one
   operation directly, with the book build/teardown done *outside* the timed
   region. We report the fastest trial (best-of-N): each trial still does [n]
   real ops, but the fastest one is the least disturbed by a GC pause landing
   mid-measurement, so it estimates intrinsic op cost with far less noise
   than an average. This is the number to watch when comparing data
   structures — a list's O(n) remove or a sorted array's O(n) insert surfaces
   here, where a symmetric round-trip average would hide it. *)
let measure_per_op ~name ~n ~build ~op =
  let target_ops = 100_000 in
  let trials = Int.max 1 (target_ops / n) in
  let best_ns_per_op = ref Float.infinity in
  for _ = 1 to trials do
    let book = build () in
    let start = Time_ns.now () in
    op book;
    let stop = Time_ns.now () in
    let ns_per_op =
      Time_ns.Span.to_ns (Time_ns.diff stop start) /. Float.of_int n
    in
    if Float.( < ) ns_per_op !best_ns_per_op then best_ns_per_op := ns_per_op
  done;
  printf
    "  %-14s %7.1f ns/op  (best of %d trials x %d ops)\n"
    name
    !best_ns_per_op
    trials
    n
;;

let measure_add ~n =
  let orders = pregenerate_asks n in
  measure_per_op
    ~name:[%string "add (n=%{n#Int})"]
    ~n
    ~build:(fun () -> Order_book.create aapl)
    ~op:(fun book ->
      Array.iter orders ~f:(fun order -> Order_book.add book order))
;;

let measure_remove ~n =
  let orders = pregenerate_asks n in
  let ids = Array.map orders ~f:Order.order_id in
  measure_per_op
    ~name:[%string "remove (n=%{n#Int})"]
    ~n
    ~build:(fun () ->
      let book = Order_book.create aapl in
      Array.iter orders ~f:(fun order -> Order_book.add book order);
      book)
    ~op:(fun book -> Array.iter ids ~f:(fun id -> Order_book.remove book id))
;;

(* ---------------------------------------------------------------- *)
(* Matching engine end-to-end benchmarks *)
(* ---------------------------------------------------------------- *)

let bench_submit_ioc_cross ~n =
  (* Measure submitting an IOC order that crosses the best ask. This is the
     most common hot path: order in, fill out. We re-seed a resting order
     after each iteration to keep the book state consistent. *)
  let min_price = 10_000 in
  let max_price = 20_000 in
  let engine = engine_with_n_asks ~min_price n in
  let next_price = ref (min_price + 1) in
  Bench.Test.create
    ~name:[%string "submit_ioc_cross (n=%{n#Int})"]
    (fun () ->
       let events =
         Matching_engine.submit
           engine
           ~participant:alice
           { symbol = aapl
           ; participant = alice
           ; side = Buy
           ; price = Price.of_int_cents max_price
           ; size = Size.of_int 100
           ; time_in_force = Ioc
           ; client_order_id = new_client_order_id ()
           }
       in
       ignore (events : Exchange_event.t list);
       (* Re-seed: add back a resting sell to replace the one we consumed *)
       ignore
         (Matching_engine.submit
            engine
            ~participant:bob
            { symbol = aapl
            ; participant = bob
            ; side = Sell
            ; price = Price.of_int_cents !next_price
            ; size = Size.of_int 100
            ; time_in_force = Day
            ; client_order_id = new_client_order_id ()
            }
          : Exchange_event.t list);
       next_price := !next_price + 1;
       if !next_price > max_price then next_price := min_price + 1)
;;

let bench_submit_ioc_no_match ~n =
  let min_price = 10_000 in
  let engine = engine_with_n_asks ~min_price n in
  Bench.Test.create ~name:[%string "submit_ioc_miss (n=%{n#Int})"] (fun () ->
    ignore
      (Matching_engine.submit
         engine
         ~participant:alice
         { symbol = aapl
         ; participant = alice
         ; side = Buy
         ; price = Price.of_int_cents (min_price - 1)
         ; size = Size.of_int 100
         ; time_in_force = Ioc
         ; client_order_id = new_client_order_id ()
         }
       : Exchange_event.t list))
;;

let bench_submit_sweep ~n =
  (* Measure an aggressive order that sweeps through the entire book.
     Re-seeds the book after each sweep. This is worst-case: every resting
     order is visited and filled. *)
  let engine = ref (engine_with_n_asks n) in
  Bench.Test.create ~name:[%string "submit_sweep_%{n#Int}_levels"] (fun () ->
    ignore
      (Matching_engine.submit
         !engine
         ~participant:alice
         { symbol = aapl
         ; participant = alice
         ; side = Buy
         ; price = Price.of_int_cents 99_999
         ; size = Size.of_int (n * 100)
         ; time_in_force = Ioc
         ; client_order_id = new_client_order_id ()
         }
       : Exchange_event.t list);
    (* Re-seed entire book *)
    engine := engine_with_n_asks n)
;;

(* ---------------------------------------------------------------- *)
(* Symbol lookup (Exercise 2): pure [book] lookup, no submit/cancel *)
(* ---------------------------------------------------------------- *)

let bench_symbol_lookup ~n =
  let engine, symbol = engine_with_n_symbols n in
  Bench.Test.create ~name:[%string "book_lookup (n=%{n#Int})"] (fun () ->
    ignore (Matching_engine.book engine symbol : Order_book.t option))
;;

(* ---------------------------------------------------------------- *)
(* Allocation measurement *)
(* ---------------------------------------------------------------- *)

let bench_find_match_alloc ~n =
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  let incoming =
    Order.create
      { symbol = aapl
      ; participant = alice
      ; side = Buy
      ; price = Price.of_int_cents (min_price + n)
      ; size = Size.of_int 100
      ; time_in_force = Ioc
      ; client_order_id = new_client_order_id ()
      }
      ~order_id:(Order_id.Generator.next gen)
  in
  (* Measure minor-heap allocations *)
  let measure_alloc f =
    Gc.compact ();
    let before = (Gc.stat ()).minor_words in
    for _ = 1 to 1000 do
      f ()
    done;
    let after = (Gc.stat ()).minor_words in
    (after -. before) /. 1000.0
  in
  let words_per_call =
    measure_alloc (fun () ->
      ignore (Order_book.find_match book incoming : Order.t option))
  in
  Bench.Test.create
    ~name:
      (sprintf "find_match_alloc (n=%d, %.1f words/call)" n words_per_call)
    (fun () -> ignore (Order_book.find_match book incoming : Order.t option))
;;

(* ---------------------------------------------------------------- *)
(* Main *)
(* ---------------------------------------------------------------- *)

let sizes = [ 10; 50; 100; 500 ]
let symbol_counts = [ 10; 100; 10_000 ]

let () =
  let tests =
    List.concat
      [ (* Order book micro-benchmarks at various sizes *)
        List.map sizes ~f:(fun n -> bench_find_match ~n)
      ; List.map sizes ~f:(fun n -> bench_find_match_no_cross ~n)
      ; List.map sizes ~f:(fun n -> bench_best_bid_offer ~n)
      ; [ bench_add_remove ~n:100 ]
      ; (* Matching engine end-to-end *)
        List.map sizes ~f:(fun n -> bench_submit_ioc_cross ~n)
      ; List.map sizes ~f:(fun n -> bench_submit_ioc_no_match ~n)
      ; List.map [ 10; 50; 100 ] ~f:(fun n -> bench_submit_sweep ~n)
      ; (* Allocation awareness *)
        [ bench_find_match_alloc ~n:100 ]
      ]
  in
  (* [basic-functions] reports both halves of the cost story in one
     invocation. Every test below goes into core_bench's own table, including
     the reversible add+remove round-trip — the one mutation core_bench can
     bench, since it sizes its own batches and reruns the closure many times
     per batch, so it needs an op whose repetition leaves the book unchanged.
     We then *also* time add and remove on their own — see [measure_per_op] —
     and print that breakdown underneath, so the statistically-rigorous
     round-trip and the cruder separate estimates sit side by side for
     cross-checking. [make_command_ext] hands us the parsed
     [-quota]/[-ascii]/... configs so the core_bench half still behaves
     exactly like a normal benchmark command. *)
  let basic_function_tests =
    List.concat
      [ List.map sizes ~f:(fun n -> bench_find ~n)
      ; List.map sizes ~f:(fun n -> bench_count ~n)
      ; List.map sizes ~f:(fun n -> bench_find_match ~n)
      ; List.map sizes ~f:(fun n -> bench_best_bid_offer ~n)
      ; List.map sizes ~f:(fun n -> bench_orders_on_side ~n)
      ; List.map sizes ~f:(fun n -> bench_snapshot ~n)
      ; List.map sizes ~f:(fun n -> bench_add_remove ~n)
      ]
  in
  Command_unix.run
    (Command.group
       ~summary:"JSIP order-book benchmarks"
       [ "existing", Bench.make_command tests
       ; ( "basic-functions"
         , Bench.make_command_ext
             ~summary:
               "order-book base-operation costs: core_bench read table, \
                then separate add/remove (manual timing)"
             (Command.Param.return
                (fun (analysis_configs, display_config, source) ->
                   match source with
                   | `Run (save_to_file, run_config) ->
                     Bench.bench
                       ~analysis_configs
                       ~display_config
                       ~run_config
                       ?save_to_file
                       basic_function_tests;
                     print_endline "";
                     print_endline
                       "separate add / remove cost (manual timing — \
                        core_bench can't isolate a non-reversible op; book \
                        build/teardown untimed):";
                     List.iter sizes ~f:(fun n -> measure_add ~n);
                     List.iter sizes ~f:(fun n -> measure_remove ~n)
                   | `From_file filenames ->
                     let results =
                       List.filter_map filenames ~f:(fun filename ->
                         let measurement =
                           Bench.Measurement.load ~filename
                         in
                         match
                           Bench.analyze ~analysis_configs measurement
                         with
                         | Ok result -> Some result
                         | Error err ->
                           Bench.Display_config.print_warning
                             display_config
                             (Error.to_string_hum err);
                           None)
                     in
                     Bench.display ~display_config results)) )
       ; ( "snapshot"
         , Bench.make_command
             (List.map sizes ~f:(fun n -> bench_snapshot ~n)) )
       ; ( "symbol-lookup"
         , Bench.make_command
             (List.map symbol_counts ~f:(fun n -> bench_symbol_lookup ~n)) )
       ])
;;
