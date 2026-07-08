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
  Command_unix.run
    (Command.group
       ~summary:"JSIP order-book benchmarks"
       [ "existing", Bench.make_command tests
       ; ( "snapshot"
         , Bench.make_command
             (List.map sizes ~f:(fun n -> bench_snapshot ~n)) )
       ])
;;
