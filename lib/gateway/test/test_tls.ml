(** TLS client-certificate tests: a real TLS-terminated [Exchange_server],
    real [Async_ssl] connections, and the certs checked into [certs/].
    Exercises the cert-derived identity path end to end alongside its
    rejection paths -- the plaintext [login_rpc] path is exercised everywhere
    else in this directory and is untouched by TLS support, so it isn't
    repeated here. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway
open Jsip_test_harness
open E2e_helpers

(* Dune mirrors the source tree under [_build]; [lib/gateway/test/dune]'s
   [(inline_tests (deps %{workspace_root}/certs/...))] is what actually pulls
   these files into the sandboxed test's working directory. *)
let certs_dir = "../../../certs"
let ca_file = certs_dir ^/ "ca.crt"
let server_crt = certs_dir ^/ "server.crt"
let server_key = certs_dir ^/ "server.key"
let alice_crt = certs_dir ^/ "Alice.crt"
let alice_key = certs_dir ^/ "Alice.key"
let bob_crt = certs_dir ^/ "Bob.crt"
let bob_key = certs_dir ^/ "Bob.key"

(* Signed by a CA the server doesn't trust ([certs/setup_rogue_ca.sh]) --
   CN=Alice on purpose, to prove rejection comes from the CA signature, not
   from an unrecognized name. *)
let rogue_crt = certs_dir ^/ "rogue.crt"
let rogue_key = certs_dir ^/ "rogue.key"

let with_tls_server ~symbols f =
  let transport =
    Exchange_server.Tls
      (Tls_config.server_config
         ~crt_file:server_crt
         ~key_file:server_key
         ~ca_file)
  in
  with_server ~transport ~symbols f
;;

(* The server's [on_handler_error] logs every rejected TLS connection via
   [Log.Global.error], and that message embeds a raw backtrace (from
   [Exn.to_string] on the underlying SSL/RPC exception) -- exactly what
   ppx_expect's "this test expectation appears to contain a backtrace"
   warning flags as too fragile to pin. These tests only care what
   the *client* observes, so silence global logging for their duration rather
   than asserting on the server's internal log line. *)
let with_quiet_logging f =
  let saved_output = Log.Global.get_output () in
  Log.Global.set_output [];
  Monitor.protect f ~finally:(fun () ->
    Log.Global.set_output saved_output;
    return ())
;;

(* Run [thunk], which is expected to fail before completing (a rejected TLS
   handshake, or a connection the server closes right after accepting it).

   Empirically (see the three tests below), all three rejection paths raise
   the same [Handshake_error ((Eof_during_step Header) ...)] shape from
   the *client's* point of view: a closed connection doesn't carry the
   server's specific reason, so a client genuinely can't distinguish "no
   cert" from "wrong CA" from "already logged in" -- only that the handshake
   didn't complete. (The specific reason is only visible in the server's own
   log, which [with_quiet_logging] silences for these tests.) Match on that
   stable signature rather than printing the raw exception text, which would
   otherwise embed the client's own ephemeral port in the "no certificate"
   case and vary on every run. *)
let attempt_rejected_connection (thunk : unit -> unit Deferred.t) =
  match%bind
    Clock_ns.with_timeout
      (Time_ns.Span.of_sec 5.)
      (Monitor.try_with_or_error ~extract_exn:true thunk)
  with
  | `Timeout -> return (print_endline "TIMED OUT waiting for rejection")
  | `Result (Ok ()) ->
    return (print_endline "BUG: connection unexpectedly succeeded")
  | `Result (Error e) ->
    let text = Error.to_string_hum e in
    return
      (print_endline
         (if String.is_substring text ~substring:"Eof_during_step"
          then "REJECTED: connection closed before the handshake completed"
          else [%string "REJECTED, but with an unrecognized error: %{text}"]))
;;

(* ---------------------------------------------------------------- *)
(* Positive path *)
(* ---------------------------------------------------------------- *)

let%expect_test "TLS: identity comes from the cert, no login_rpc, orders \
                 attributed correctly"
  =
  with_tls_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
    let%bind alice =
      connect_as_tls
        ~port
        ~crt_file:alice_crt
        ~key_file:alice_key
        ~ca_file
        Harness.alice
    in
    let%bind bob =
      connect_as_tls
        ~port
        ~crt_file:bob_crt
        ~key_file:bob_key
        ~ca_file
        Harness.bob
    in
    let%bind () =
      rpc_submit bob (Harness.sell ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect {| [for Bob] ACCEPTED id=1 AAPL SELL 100@$150.00 DAY |}];
    let%bind () =
      rpc_submit alice (Harness.buy ~price_cents:15000 ~client_order_id:1 ())
    in
    [%expect
      {|
      [for Alice] ACCEPTED id=2 AAPL BUY 100@$150.00 DAY
      [for Alice] FILL fill_id=1 AAPL $150.00 x100 aggressor=2(Alice w/ client order ID = 1) BUY resting=1(Bob w/ client order ID = 1)
      [for Bob] FILL fill_id=1 AAPL $150.00 x100 aggressor=2(Alice w/ client order ID = 1) BUY resting=1(Bob w/ client order ID = 1)
      |}];
    (* Confirm the book itself reflects the same attribution-free state a
       plaintext session would produce -- TLS only changes how identity is
       established, not anything downstream of it. *)
    let%bind book = rpc_book alice Harness.aapl in
    print_endline (Option.value_exn book |> Book.to_string);
    [%expect
      {|
      === AAPL ===
        BIDS: (empty)
        ASKS: (empty)
        BBO: - / -
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Rejection paths *)
(* ---------------------------------------------------------------- *)

let%expect_test "TLS: connecting with no certificate is rejected during the \
                 handshake"
  =
  with_quiet_logging (fun () ->
    with_tls_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
      let%bind () =
        attempt_rejected_connection (fun () ->
          let where =
            Tcp.Where_to_connect.of_host_and_port
              { host = "localhost"; port }
          in
          let%bind (_ : Rpc.Connection.t) =
            Rpc.Connection.client where >>| Result.ok_exn
          in
          return ())
      in
      [%expect
        {| REJECTED: connection closed before the handshake completed |}];
      return ()))
;;

let%expect_test "TLS: a certificate signed by a different CA is rejected" =
  with_quiet_logging (fun () ->
    with_tls_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
      let%bind () =
        attempt_rejected_connection (fun () ->
          let%bind (_ : client) =
            connect_as_tls
              ~port
              ~crt_file:rogue_crt
              ~key_file:rogue_key
              ~ca_file
              Harness.alice
          in
          return ())
      in
      [%expect
        {| REJECTED: connection closed before the handshake completed |}];
      return ()))
;;

(* ---------------------------------------------------------------- *)
(* Known rough edge: no clean Or_error for a cert-derived session conflict
   (see lib/gateway/src/exchange_server.ml's TLS accept path) -- this test
   pins today's behavior so a fix shows up as an intentional expect-output
   change, not a silent regression. *)
(* ---------------------------------------------------------------- *)

let%expect_test "TLS: the same participant's cert connecting twice closes \
                 the second connection instead of returning a clean error"
  =
  with_quiet_logging (fun () ->
    with_tls_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
      let%bind (_ : client) =
        connect_as_tls
          ~port
          ~crt_file:alice_crt
          ~key_file:alice_key
          ~ca_file
          Harness.alice
      in
      let%bind () =
        attempt_rejected_connection (fun () ->
          let%bind (_ : client) =
            connect_as_tls
              ~port
              ~crt_file:alice_crt
              ~key_file:alice_key
              ~ca_file
              Harness.alice
          in
          return ())
      in
      [%expect
        {| REJECTED: connection closed before the handshake completed |}];
      return ()))
;;
