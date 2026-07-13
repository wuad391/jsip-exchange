open! Core
open! Async
open Jsip_gateway
open Jsip_types

(* [Dispatcher]'s pipe-occupancy accessors feed the monitoring dashboard, so
   a subscriber must be measured as the one pipe it is — not once per symbol
   it registered for. *)

let%expect_test "market_data_queue_lengths counts each pipe once, not per \
                 symbol"
  =
  let t = Dispatcher.create () in
  let aapl = Symbol_id.of_int 0 in
  let msft = Symbol_id.of_int 3 in
  (* One pipe registered on two symbols, a second pipe on one: occupancy must
     see two distinct pipes (all empty → depth 0), not three registrations. *)
  let _reader_on_two = Dispatcher.subscribe_market_data t [ aapl; msft ] in
  let _reader_on_one = Dispatcher.subscribe_market_data t [ aapl ] in
  print_s [%sexp (Dispatcher.market_data_queue_lengths t : int list)];
  [%expect {| (0 0) |}];
  return ()
;;

let print_available label reader =
  match Pipe.read_now' reader with
  | `Nothing_available | `Eof -> print_endline [%string "%{label}: quiet"]
  | `Ok events ->
    Queue.iter events ~f:(fun event ->
      print_endline [%string "%{label}: %{Protocol.format_event event}"])
;;

let%expect_test "session set-up and clean-up announce themselves on the \
                 audit feed only"
  =
  let t = Dispatcher.create () in
  let audit = Dispatcher.subscribe_audit t in
  let alice = Participant.of_string "Alice" in
  let%bind () = Dispatcher.set_up_session t alice in
  let session = Option.value_exn (Dispatcher.lookup_session t alice) in
  (* Presence is operator telemetry: the participant's own feed must stay
     quiet while the audit feed hears both edges. *)
  print_available "alice's session feed" (Session.reader session);
  let%bind () = Dispatcher.clean_up_session t session in
  print_available "audit" audit;
  [%expect
    {|
    alice's session feed: quiet
    audit: SESSION Alice connected
    audit: SESSION Alice disconnected
    |}];
  return ()
;;
