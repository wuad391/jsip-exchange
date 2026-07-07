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
  let t = Dispatcher.create () in
  let aapl = Symbol.of_string "AAPL" in
  let msft = Symbol.of_string "MSFT" in
  (* One pipe registered on two symbols, a second pipe on one: occupancy must
     see two distinct pipes (all empty → depth 0), not three registrations. *)
  let _reader_on_two = Dispatcher.subscribe_market_data t [ aapl; msft ] in
  let _reader_on_one = Dispatcher.subscribe_market_data t [ aapl ] in
  print_s [%sexp (Dispatcher.market_data_queue_lengths t : int list)];
  [%expect {| (0 0) |}]
;;
