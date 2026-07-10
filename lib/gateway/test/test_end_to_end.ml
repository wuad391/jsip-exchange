(** End-to-end tests with a real server and RPC clients.

    These tests spin up an actual exchange server on a local port, connect
    one or more clients via RPC, log them in, and verify the full path:
    client -> network -> server -> matching engine -> dispatcher -> session
    feed -> client. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway
open Jsip_test_harness
open E2e_helpers

(* ---------------------------------------------------------------- *)
(* Log in tests *)
(* ---------------------------------------------------------------- *)
let%expect_test "Log in required before submit or cancel" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port ~login:false Harness.alice in
    let%bind bob = connect_as ~login:false ~port Harness.bob in
    (* Bob places a sell *)
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect {| User is not logged in. |}];
    (* Alice places a buy — should cross *)
    let%bind () = rpc_cancel alice (Harness.cancel ~client_order_id:1) in
    [%expect {| User is not logged in. |}];
    return ())
;;

let%expect_test "Cannot log in two users under the same name" =
  let%bind res =
    Monitor.try_with_or_error ~extract_exn:true (fun () ->
      with_server ~num_symbols:1 (fun ~server:_ ~port ->
        let%bind _ = connect_as ~port Harness.alice in
        (* let res = Or_error.try_with (fun () -> let%bind _ = connect_as
           ~port Harness.alice in return ()) in let () = match res with | Ok
           _ -> () | Error e -> print_endline
           [%string "%{(Error.to_string_hum e)}"] in *)
        let%bind _ = connect_as ~port Harness.alice in
        return ()))
  in
  let () =
    match res with
    | Ok _ -> ()
    | Error e -> print_endline [%string "%{Error.to_string_hum e}"]
  in
  [%expect
    {|
    Participant Alice already has a session active.
    (Async_rpc_kernel__Rpc.Pipe_rpc.Pipe_rpc_failed)
    |}];
  return ()
;;

let%expect_test "Log in and submit order guard against duplicate client \
                 order IDs"
  =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind bob = connect_as ~port Harness.bob in
    (* Bob places a sell *)
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~client_order_id:1 ())
    in
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect
      {|
      [for Bob] ACCEPTED id=1 0 SELL 100@$150.00 DAY
      [for Bob] REJECTED 0 SELL 100@$150.00 reason=Duplicate client order ID
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Cancellation tests *)
(* ---------------------------------------------------------------- *)
let%expect_test "Submit then cancel" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    (* Bob places a sell *)
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect {| [for Bob] ACCEPTED id=1 0 SELL 100@$150.00 DAY |}];
    let%bind res =
      Async.try_with (fun () ->
        rpc_submit alice (Harness.buy ~price_cents:1 ~client_order_id:1 ()))
    in
    let%bind () =
      match res with
      | Ok _ -> return ()
      | Error e -> return (print_endline [%string "%{(Exn.to_string e)}"])
    in
    [%expect {| [for Alice] ACCEPTED id=2 0 BUY 100@$0.01 DAY |}];
    [%expect {||}];
    (* Alice places a buy — should cross *)
    let%bind () = rpc_cancel alice (Harness.cancel ~client_order_id:1) in
    [%expect
      {| [for Alice] CANCELLED id=2 0 remaining=100 reason=PARTICIPANT_REQUESTED |}];
    return ())
;;

let%expect_test "Canceling an already filled order" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    (* Bob places a sell *)
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:1 ~client_order_id:1 ())
    in
    [%expect {| [for Bob] ACCEPTED id=1 0 SELL 100@$0.01 DAY |}];
    let%bind () =
      rpc_submit alice (Harness.buy ~price_cents:1 ~client_order_id:1 ())
    in
    [%expect
      {|
      [for Alice] ACCEPTED id=2 0 BUY 100@$0.01 DAY
      [for Alice] FILL fill_id=1 0 $0.01 x100 aggressor=2(Alice w/ client order ID = 1) BUY resting=1(Bob w/ client order ID = 1)
      [for Bob] FILL fill_id=1 0 $0.01 x100 aggressor=2(Alice w/ client order ID = 1) BUY resting=1(Bob w/ client order ID = 1)
      |}];
    (* Alice places a buy — should cross *)
    let%bind () = rpc_cancel bob (Harness.cancel ~client_order_id:1) in
    [%expect
      {| [for Bob] REJECTED CANCEL because Cannot cancel non-existent order |}];
    let%bind () = rpc_cancel alice (Harness.cancel ~client_order_id:1) in
    [%expect
      {| [for Alice] REJECTED CANCEL because Cannot cancel non-existent order |}];
    return ())
;;

let%expect_test "Canceling a non existent order" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind () = rpc_cancel alice (Harness.cancel ~client_order_id:1) in
    [%expect
      {| [for Alice] REJECTED CANCEL because Cannot cancel non-existent order |}];
    return ())
;;

let%expect_test "BBO update after cancel" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    (* Bob places a sell *)
    let%bind () = rpc_subscribe alice [ Harness.aapl ] "Alice" in
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:1 ~client_order_id:1 ())
    in
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:100 ~client_order_id:2 ())
    in
    [%expect
      {|
      [for Bob] ACCEPTED id=1 0 SELL 100@$0.01 DAY
      [for Alice] BBO 0 bid=- ask=$0.01 x100
      [for Bob] ACCEPTED id=2 0 SELL 100@$1.00 DAY
      |}];
    (* let%bind () = rpc_submit alice (Harness.buy ~price_cents:100
       ~participant:Harness.alice ~client_order_id:1 ()) in [%expect {| |}]; *)
    (* Alice places a buy — should cross *)
    let%bind () = rpc_cancel bob (Harness.cancel ~client_order_id:1) in
    [%expect
      {|
      [for Bob] CANCELLED id=1 0 remaining=100 reason=PARTICIPANT_REQUESTED
      [for Alice] BBO 0 bid=- ask=$1.00 x100
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Multiple client tests *)
(* ---------------------------------------------------------------- *)

let%expect_test "e2e: two clients trade with each other" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    (* Bob places a sell *)
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect {| [for Bob] ACCEPTED id=1 0 SELL 100@$150.00 DAY |}];
    (* Alice places a buy — should cross *)
    let%bind () =
      rpc_submit alice (Harness.buy ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect
      {|
      [for Alice] ACCEPTED id=2 0 BUY 100@$150.00 DAY
      [for Alice] FILL fill_id=1 0 $150.00 x100 aggressor=2(Alice w/ client order ID = 1) BUY resting=1(Bob w/ client order ID = 1)
      [for Bob] FILL fill_id=1 0 $150.00 x100 aggressor=2(Alice w/ client order ID = 1) BUY resting=1(Bob w/ client order ID = 1)
      |}];
    return ())
;;

let%expect_test "e2e: three clients, sequential orders, shared book" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    let%bind charlie = connect_as ~port Harness.charlie in
    (* Bob posts a sell *)
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~size:50 ())
    in
    [%expect {| [for Bob] ACCEPTED id=1 0 SELL 50@$150.00 DAY |}];
    (* Charlie posts a sell at a higher price *)
    let%bind () =
      rpc_submit charlie (Harness.sell ~price_cents:15010 ~size:50 ())
    in
    [%expect {| [for Charlie] ACCEPTED id=2 0 SELL 50@$150.10 DAY |}];
    (* Alice buys 80 — should sweep through both *)
    let%bind () =
      rpc_submit alice (Harness.buy ~price_cents:15010 ~size:80 ())
    in
    [%expect
      {|
      [for Alice] ACCEPTED id=3 0 BUY 80@$150.10 DAY
      [for Alice] FILL fill_id=1 0 $150.00 x50 aggressor=3(Alice w/ client order ID = 7) BUY resting=1(Bob w/ client order ID = 5)
      [for Alice] FILL fill_id=2 0 $150.10 x30 aggressor=3(Alice w/ client order ID = 7) BUY resting=2(Charlie w/ client order ID = 6)
      [for Bob] FILL fill_id=1 0 $150.00 x50 aggressor=3(Alice w/ client order ID = 7) BUY resting=1(Bob w/ client order ID = 5)
      [for Charlie] FILL fill_id=2 0 $150.10 x30 aggressor=3(Alice w/ client order ID = 7) BUY resting=2(Charlie w/ client order ID = 6)
      |}];
    (* Verify book state *)
    let%bind book = rpc_book alice Harness.aapl in
    print_endline (Option.value_exn book |> Book.to_string);
    [%expect
      {|
      === 0 ===
        BIDS: (empty)
        ASKS:
          $150.10 x20
        BBO: - / $150.10 x20
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Market data subscription tests *)
(* ---------------------------------------------------------------- *)

let%expect_test "e2e: market data subscriber receives trade and BBO updates" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind sub = connect_as ~port (Participant.of_string "Sub") in
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    let%bind result =
      Rpc.Pipe_rpc.dispatch
        Rpc_protocol.market_data_rpc
        (connection sub)
        [ Harness.aapl ]
    in
    let reader =
      match result with
      | Ok (Ok (reader, _id)) -> reader
      | _ -> failwith "subscribe failed"
    in
    don't_wait_for
      (Pipe.iter_without_pushback reader ~f:(fun event ->
         let e = Protocol.format_event event in
         print_endline [%string "[MD Subscriber] %{e}"]));
    (* Post a sell *)
    let%bind () = rpc_submit bob (Harness.sell ~price_cents:15000 ()) in
    [%expect
      {|
      [for Bob] ACCEPTED id=1 0 SELL 100@$150.00 DAY
      [MD Subscriber] BBO 0 bid=- ask=$150.00 x100
      |}];
    (* Cross it with a buy *)
    let%bind () = rpc_submit alice (Harness.buy ~price_cents:15000 ()) in
    [%expect
      {|
      [for Alice] ACCEPTED id=2 0 BUY 100@$150.00 DAY
      [for Alice] FILL fill_id=1 0 $150.00 x100 aggressor=2(Alice w/ client order ID = 9) BUY resting=1(Bob w/ client order ID = 8)
      [for Bob] FILL fill_id=1 0 $150.00 x100 aggressor=2(Alice w/ client order ID = 9) BUY resting=1(Bob w/ client order ID = 8)
      [MD Subscriber] TRADE 0 $150.00 x100
      [MD Subscriber] BBO 0 bid=- ask=-
      |}];
    return ())
;;

let%expect_test "e2e: subscriber only sees events for subscribed symbol" =
  with_server ~num_symbols:2 (fun ~server:_ ~port ->
    let%bind sub = connect_as ~port (Participant.of_string "Sub") in
    let%bind bob = connect_as ~port Harness.bob in
    let%bind result =
      Rpc.Pipe_rpc.dispatch
        Rpc_protocol.market_data_rpc
        (connection sub)
        [ Harness.aapl ]
    in
    let reader =
      match result with
      | Ok (Ok (reader, _id)) -> reader
      | _ -> failwith "subscribe failed"
    in
    don't_wait_for
      (Pipe.iter_without_pushback reader ~f:(fun event ->
         let e = Protocol.format_event event in
         print_endline [%string "[MD Subscriber] %{e}"]));
    (* Post on TSLA — subscriber should NOT see this *)
    let%bind () =
      rpc_submit
        bob
        (Harness.sell ~price_cents:20000 ~symbol:Harness.tsla ())
    in
    [%expect {| [for Bob] ACCEPTED id=1 1 SELL 100@$200.00 DAY |}];
    (* Post on AAPL — subscriber SHOULD see this *)
    let%bind () = rpc_submit bob (Harness.sell ~price_cents:15000 ()) in
    [%expect
      {|
      [for Bob] ACCEPTED id=2 0 SELL 100@$150.00 DAY
      [MD Subscriber] BBO 0 bid=- ask=$150.00 x100
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Concurrent submission test *)
(* ---------------------------------------------------------------- *)

let%expect_test "e2e: many clients submit orders concurrently" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind seed = connect_as ~port Harness.bob in
    let%bind () =
      Deferred.List.iter
        (List.init 10 ~f:Fn.id)
        ~how:`Sequential
        ~f:(fun i ->
          rpc_submit seed (Harness.sell ~price_cents:(15000 + i) ())
          |> Deferred.ignore_m)
    in
    let%bind () =
      Deferred.List.iter (List.init 5 ~f:Fn.id) ~how:`Parallel ~f:(fun i ->
        let participant = Participant.of_string [%string "Trader%{i#Int}"] in
        let%bind client = connect_as ~port participant in
        rpc_submit client (Harness.buy ~price_cents:15010 ())
        |> Deferred.ignore_m)
    in
    (* The dispatcher's placeholder [for <Participant>] prints land on stdout
       in an order that depends on which parallel buy was processed first.
       Swallow the trace and assert on the deterministic remaining book state
       instead: 10 sells went in, the 5 buys at $150.10 each hit the
       lowest-priced sell, so 5 sells should remain. *)
    let (_ : string) = [%expect.output] in
    let%bind book = rpc_book seed Harness.aapl in
    let book = Option.value_exn book in
    let remaining_orders = List.length book.bids + List.length book.asks in
    [%test_result: int] remaining_orders ~expect:5;
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Audit log subscription tests *)
(* ---------------------------------------------------------------- *)

let%expect_test "e2e: audit log subscriber sees full unfiltered stream \
                 across symbols"
  =
  with_server ~num_symbols:2 (fun ~server:_ ~port ->
    let%bind sub = connect_as ~port (Participant.of_string "Auditor") in
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    let%bind result =
      Rpc.Pipe_rpc.dispatch Rpc_protocol.audit_log_rpc (connection sub) ()
    in
    let reader =
      match result with
      | Ok (Ok (reader, _id)) -> reader
      | _ -> failwith "subscribe failed"
    in
    don't_wait_for
      (Pipe.iter_without_pushback reader ~f:(fun event ->
         let e = Protocol.format_event event in
         print_endline [%string "[AUDIT] %{e}"]));
    (* Post a sell on AAPL — audit subscriber should see ACCEPTED and BBO. *)
    let%bind () = rpc_submit bob (Harness.sell ~price_cents:15000 ()) in
    [%expect
      {|
      [AUDIT] ACCEPTED id=1 0 SELL 100@$150.00 DAY
      [AUDIT] BBO 0 bid=- ask=$150.00 x100
      [for Bob] ACCEPTED id=1 0 SELL 100@$150.00 DAY
      |}];
    (* Post a sell on TSLA — audit subscriber should see this too
       (multi-symbol). *)
    let%bind () =
      rpc_submit
        bob
        (Harness.sell ~price_cents:20000 ~symbol:Harness.tsla ())
    in
    [%expect
      {|
      [AUDIT] ACCEPTED id=2 1 SELL 100@$200.00 DAY
      [AUDIT] BBO 1 bid=- ask=$200.00 x100
      [for Bob] ACCEPTED id=2 1 SELL 100@$200.00 DAY
      |}];
    (* Cross the AAPL sell — the audit log should see ACCEPTED + FILL + BBO. *)
    let%bind () = rpc_submit alice (Harness.buy ~price_cents:15000 ()) in
    [%expect
      {|
      [AUDIT] ACCEPTED id=3 0 BUY 100@$150.00 DAY
      [AUDIT] FILL fill_id=1 0 $150.00 x100 aggressor=3(Alice w/ client order ID = 29) BUY resting=1(Bob w/ client order ID = 27)
      [AUDIT] TRADE 0 $150.00 x100
      [AUDIT] BBO 0 bid=- ask=-
      [for Alice] ACCEPTED id=3 0 BUY 100@$150.00 DAY
      [for Alice] FILL fill_id=1 0 $150.00 x100 aggressor=3(Alice w/ client order ID = 29) BUY resting=1(Bob w/ client order ID = 27)
      [for Bob] FILL fill_id=1 0 $150.00 x100 aggressor=3(Alice w/ client order ID = 29) BUY resting=1(Bob w/ client order ID = 27)
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Session-status (presence) tests *)
(* ---------------------------------------------------------------- *)

(* Await exactly one audit event and print it. Blocking on the pipe (rather
   than yielding and hoping) makes the test deterministic: the login /
   disconnect happened on the server across a real network round-trip, and
   this rendezvouses with its announcement. *)
let read_one_audit_event reader =
  match%bind Pipe.read_exactly reader ~num_values:1 with
  | `Exactly events ->
    Queue.iter events ~f:(fun event ->
      print_endline [%string "[AUDIT] %{Protocol.format_event event}"]);
    return ()
  | `Eof | `Fewer _ ->
    print_endline "[AUDIT] unexpected end of stream";
    return ()
;;

let%expect_test "e2e: audit log announces logins and disconnects" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind auditor =
      connect_as ~port ~login:false (Participant.of_string "Auditor")
    in
    let%bind result =
      Rpc.Pipe_rpc.dispatch
        Rpc_protocol.audit_log_rpc
        (connection auditor)
        ()
    in
    let reader =
      match result with
      | Ok (Ok (reader, _id)) -> reader
      | _ -> failwith "subscribe failed"
    in
    let%bind alice = connect_as ~port Harness.alice in
    let%bind () = read_one_audit_event reader in
    [%expect {| [AUDIT] SESSION Alice connected |}];
    let%bind () = Rpc.Connection.close (connection alice) in
    let%bind () = read_one_audit_event reader in
    [%expect {| [AUDIT] SESSION Alice disconnected |}];
    (* Stop reading before teardown so nothing races the test's end. *)
    Pipe.close_read reader;
    return ())
;;

let%expect_test "dispatcher: closing a subscriber's reader removes the \
                 writer"
  =
  let dispatcher = Dispatcher.create () in
  print_s
    [%message
      "initial"
        ~count:
          (Dispatcher.For_testing.audit_subscriber_count dispatcher : int)];
  [%expect {| (initial (count 0)) |}];
  let reader_a = Dispatcher.subscribe_audit dispatcher in
  let reader_b = Dispatcher.subscribe_audit dispatcher in
  print_s
    [%message
      "after subscribe"
        ~count:
          (Dispatcher.For_testing.audit_subscriber_count dispatcher : int)];
  [%expect {| ("after subscribe" (count 2)) |}];
  Pipe.close_read reader_a;
  let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
  print_s
    [%message
      "after closing reader_a"
        ~count:
          (Dispatcher.For_testing.audit_subscriber_count dispatcher : int)];
  [%expect {| ("after closing reader_a" (count 1)) |}];
  Pipe.close_read reader_b;
  let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
  print_s
    [%message
      "after closing reader_b"
        ~count:
          (Dispatcher.For_testing.audit_subscriber_count dispatcher : int)];
  [%expect {| ("after closing reader_b" (count 0)) |}];
  return ()
;;

(* ---------------------------------------------------------------- *)
(* Cancel-all tests *)
(* ---------------------------------------------------------------- *)

let%expect_test "e2e: cancel-all sweeps only the caller's resting orders" =
  with_server ~num_symbols:2 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    let%bind bob = connect_as ~port Harness.bob in
    let%bind () =
      rpc_submit alice (Harness.buy ~price_cents:15000 ~client_order_id:1 ())
    in
    let%bind () =
      rpc_submit alice (Harness.buy ~price_cents:14900 ~client_order_id:2 ())
    in
    let%bind () =
      rpc_submit
        alice
        (Harness.sell
           ~price_cents:20100
           ~symbol:Harness.tsla
           ~client_order_id:3
           ())
    in
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15100 ~client_order_id:1 ())
    in
    [%expect
      {|
      [for Alice] ACCEPTED id=1 0 BUY 100@$150.00 DAY
      [for Alice] ACCEPTED id=2 0 BUY 100@$149.00 DAY
      [for Alice] ACCEPTED id=3 1 SELL 100@$201.00 DAY
      [for Bob] ACCEPTED id=4 0 SELL 100@$151.00 DAY
      |}];
    let%bind count = rpc_cancel_all alice in
    print_s [%sexp (count : int Or_error.t)];
    [%expect
      {|
      [for Alice] CANCELLED id=1 0 remaining=100 reason=MASS_CANCEL
      [for Alice] CANCELLED id=2 0 remaining=100 reason=MASS_CANCEL
      [for Alice] CANCELLED id=3 1 remaining=100 reason=MASS_CANCEL
      (Ok 3)
      |}];
    (* bob's book survived alice's sweep; a second sweep finds nothing. *)
    let%bind book = rpc_book bob Harness.aapl in
    print_endline (Option.value_exn book |> Book.to_string);
    let%bind count = rpc_cancel_all alice in
    print_s [%sexp (count : int Or_error.t)];
    [%expect
      {|
      === 0 ===
        BIDS: (empty)
        ASKS:
          $151.00 x100
        BBO: - / $151.00 x100
      (Ok 0)
      |}];
    return ())
;;

let%expect_test "e2e: cancel-all is ordered behind an in-flight submit" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind alice = connect_as ~port Harness.alice in
    (* Dispatch a submit and, WITHOUT awaiting it, a cancel-all on the same
       connection: both ride the server's single ordered request queue, so
       the sweep must catch the order the submit just placed — no
       resurrection race where a late accept survives the kill. *)
    let submitted =
      rpc_submit alice (Harness.buy ~price_cents:15000 ~client_order_id:1 ())
    in
    let%bind count = rpc_cancel_all alice in
    let%bind () = submitted in
    print_s [%sexp (count : int Or_error.t)];
    [%expect
      {|
      [for Alice] ACCEPTED id=1 0 BUY 100@$150.00 DAY
      [for Alice] CANCELLED id=1 0 remaining=100 reason=MASS_CANCEL
      (Ok 1)
      |}];
    return ())
;;

let%expect_test "e2e: cancel-all requires login" =
  with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind stranger =
      connect_as ~port ~login:false (Participant.of_string "Stranger")
    in
    let%bind count = rpc_cancel_all stranger in
    print_s [%sexp (count : int Or_error.t)];
    [%expect {| (Error "User is not logged in.") |}];
    return ())
;;
