(** Exchange client.

    Connects to a running exchange server and provides an interactive
    command-line interface for submitting orders and querying the book.

    Run with: dune exec app/client/bin/main.exe -- -host localhost -port
    12345 -name Alice *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway

let run_interactive ~host ~port ~participant_name ~participant conn =
  print_endline
    [%string
      {|
            Connected to exchange at %{host}:%{port#Int} as %{participant#Participant}
            Commands: BUY|SELL <symbol> <size> <price> [IOC|DAY]
                      BOOK <symbol>
                      SUBSCRIBE <symbol>  (stream market data)

            Order acknowledgements, fills, and cancellations are temporarily printed
            by the server process; the SUBSCRIBE command attaches you to a per-symbol
            market-data feed.|}];
  let rec loop () =
    print_string "> ";
    match%bind Reader.read_line (Lazy.force Reader.stdin) with
    | `Eof ->
      print_endline "\nDisconnected.";
      Deferred.Or_error.ok_unit
    | `Ok line ->
      let line = String.strip line in
      if String.is_empty line
      then loop ()
      else (
        let parse_result =
          Or_error.try_with_join (fun () ->
            Exchange_command.parse ~default_participant:participant line)
        in
        match parse_result with
        | Error e ->
          print_s [%sexp (e : Error.t)];
          loop ()
        | Ok verb ->
          (match verb with
           | Book symbol ->
             let%bind result =
               Rpc.Rpc.dispatch_exn Rpc_protocol.book_query_rpc conn symbol
             in
             (match result with
              | None ->
                print_endline
                  [%string "No book available for %{symbol#Symbol}"]
              | Some result -> print_endline (Book.to_string result));
             loop ()
           | Subscribe symbol ->
             let%bind result =
               Rpc.Pipe_rpc.dispatch
                 Rpc_protocol.market_data_rpc
                 conn
                 [ symbol ]
             in
             (match result with
              | Error err | Ok (Error err) ->
                print_endline
                  [%string "ERROR subscribing: %{Error.to_string_hum err}"];
                loop ()
              | Ok (Ok (reader, _id)) ->
                print_endline
                  [%string
                    {| Subscribed to %{symbol#Symbol} market data. Updates will appear below.
                            Continue entering commands as normal.|}];
                (* Read market data in the background; the command loop
                   continues running concurrently. *)
                don't_wait_for
                  (Pipe.iter_without_pushback reader ~f:(fun event ->
                     print_endline
                       [%string "[MD] %{Protocol.format_event event}"]));
                loop ())
           | Submit request ->
             let%bind result =
               Rpc.Rpc.dispatch Rpc_protocol.submit_order_rpc conn request
             in
             (match result with
              | Error err | Ok (Error err) ->
                print_endline
                  [%string
                    "ERROR submitting order: %{Error.to_string_hum err}"]
              | Ok (Ok ()) -> ());
             loop ()
           | Cancel cancel ->
             let%bind result =
               Rpc.Rpc.dispatch
                 Rpc_protocol.cancel_order_rpc
                 conn
                 cancel.client_order_id
             in
             (match result with
              | Error err | Ok (Error err) ->
                print_endline
                  [%string
                    "ERROR cancelling order: %{Error.to_string_hum err}"]
              | Ok (Ok ()) -> ());
             loop ()))
  in
  let%bind session_feed, _ =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc conn ()
  in
  let () =
    don't_wait_for
      (Pipe.iter_without_pushback session_feed ~f:(fun event ->
         let event_string =
           Protocol.format_event
             ~participant:(Some (Participant.of_string participant_name))
             event
         in
         print_endline event_string))
  in
  loop ()
;;

let run_client_plaintext ~host ~port ~participant_name =
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port { host; port }
  in
  let%bind conn = Rpc.Connection.client where_to_connect >>| Result.ok_exn in
  let%bind login_result =
    Rpc.Rpc.dispatch_exn Rpc_protocol.login_rpc conn participant_name
  in
  match login_result with
  | Error s ->
    return
      (Or_error.error_string
         [%string "Login error: %{(Error.to_string_hum s)#String}"])
  | Ok participant ->
    run_interactive ~host ~port ~participant_name ~participant conn
;;

(* Identity here comes from the TLS handshake, not from any RPC -- there's no
   login_rpc call, and so no name conflict to fail on client-side.
   [participant_name] (the [-name] flag) is only used for local display; the
   server never sees or trusts it. *)
let run_client_tls ~host ~port ~participant_name ~crt_file ~key_file ~ca_file
  =
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port { host; port }
  in
  let tls_config = Tls_config.client_config ~crt_file ~key_file ~ca_file in
  let%bind _socket, _ssl_conn, reader, writer =
    Async_ssl.Tls.Expert.connect tls_config where_to_connect
  in
  let%bind conn =
    Rpc.Connection.create ~connection_state:(fun _ -> ()) reader writer
    >>| Result.ok_exn
  in
  run_interactive
    ~host
    ~port
    ~participant_name
    ~participant:(Participant.of_string participant_name)
    conn
;;

let run_client ~host ~port ~participant_name ~crt_file ~key_file ~ca_file =
  match crt_file, key_file, ca_file with
  | None, None, None -> run_client_plaintext ~host ~port ~participant_name
  | Some crt_file, Some key_file, Some ca_file ->
    run_client_tls ~host ~port ~participant_name ~crt_file ~key_file ~ca_file
  | _, _, _ ->
    return
      (Or_error.error_string
         "-cert, -key, and -ca-file must all be given together, or all \
          omitted (to connect without TLS)")
;;

let () =
  Command.async_or_error
    ~summary:"JSIP Exchange client"
    (let%map_open.Command host =
       flag
         "-host"
         (optional_with_default "localhost" string)
         ~doc:"HOST server hostname"
     and port = flag "-port" (required int) ~doc:"PORT server port"
     and participant_name =
       flag
         "-name"
         (optional_with_default (Core_unix.getlogin ()) string)
         ~doc:"NAME participant name"
     and crt_file =
       flag
         "-cert"
         (optional string)
         ~doc:
           "FILE client certificate; enables TLS (requires -key and \
            -ca-file too)"
     and key_file =
       flag "-key" (optional string) ~doc:"FILE client private key"
     and ca_file =
       flag
         "-ca-file"
         (optional string)
         ~doc:"FILE CA certificate used to verify the server"
     in
     fun () ->
       run_client ~host ~port ~participant_name ~crt_file ~key_file ~ca_file)
  |> Command_unix.run
;;
