open! Core
open Jsip_gateway
open Jsip_types

(* [Dispatcher]'s pipe-occupancy accessors feed the monitoring dashboard, so
   a subscriber must be measured as the one pipe it is — not once per symbol
   it registered for. The subscribe/measure path is synchronous, so no
   scheduler is needed here. *)

let%expect_test "market_data_queue_lengths counts each pipe once, not per \
                 symbol"
  =
  let t =
    Dispatcher.create
      (Dispatcher.Config.uniform
         { max_length = 8; policy = Bounded_pipe.Policy.Drop_newest })
  in
  let aapl = Symbol_id.of_int 0 in
  let msft = Symbol_id.of_int 3 in
  (* One pipe registered on two symbols, a second pipe on one: occupancy must
     see two distinct pipes (all empty → depth 0), not three registrations. *)
  let _reader_on_two = Dispatcher.subscribe_market_data t [ aapl; msft ] in
  let _reader_on_one = Dispatcher.subscribe_market_data t [ aapl ] in
  print_s [%sexp (Dispatcher.market_data_queue_lengths t : int list)];
  [%expect {| (0 0) |}]
;;

(* §3a.1: a bounded market-data pipe with a reader that never drains must
   stop its buffer from growing. These drive [Dispatcher.dispatch] with an
   explicit config so they pin the mechanism, not whatever policy the server
   later settles on in [Config.default]. *)

let aapl = Symbol_id.of_int 0

let trade price_cents =
  Exchange_event.Trade_report
    { symbol = aapl
    ; price = Price.of_int_cents price_cents
    ; size = Size.of_int 1
    }
;;

let%expect_test "drop-newest keeps the oldest events and drops the rest" =
  let t =
    Dispatcher.create
      (Dispatcher.Config.uniform
         { max_length = 2; policy = Bounded_pipe.Policy.Drop_newest })
  in
  let reader = Dispatcher.subscribe_market_data t [ aapl ] in
  (* Never read [reader]. Dispatch five trades into a buffer capped at two. *)
  Dispatcher.dispatch t (List.init 5 ~f:(fun i -> trade (15000 + i)));
  print_s [%sexp (Dispatcher.market_data_queue_lengths t : int list)];
  [%expect {| (2) |}];
  let drained =
    match Async.Pipe.read_now' reader with
    | `Eof | `Nothing_available -> []
    | `Ok q -> Queue.to_list q
  in
  print_s [%sexp (drained : Exchange_event.t list)];
  [%expect
    {|
    ((Trade_report (symbol 0) (price 15000) (size 1))
     (Trade_report (symbol 0) (price 15001) (size 1)))
    |}]
;;

let%expect_test "disconnect closes the pipe once the buffer is full" =
  let t =
    Dispatcher.create
      (Dispatcher.Config.uniform
         { max_length = 2; policy = Bounded_pipe.Policy.Disconnect })
  in
  let reader = Dispatcher.subscribe_market_data t [ aapl ] in
  Dispatcher.dispatch t (List.init 3 ~f:(fun i -> trade (15000 + i)));
  (* The third trade hits the cap of two, so the policy closes the pipe. Its
     two predecessors stay buffered (a closed pipe still drains) and no third
     event is added: the buffer is bounded and the reader now sees EOF. *)
  print_s
    [%message
      (Async.Pipe.is_closed reader : bool)
        (Dispatcher.market_data_queue_lengths t : int list)];
  [%expect
    {|
    (("Async.Pipe.is_closed reader" true)
     ("Dispatcher.market_data_queue_lengths t" (2)))
    |}]
;;
