open! Core
open! Async
open Jsip_gateway
open Jsip_types

let ok_str res =
  match res with
  | Ok _ -> ()
  | Error e -> print_endline [%string "%{(Error.to_string_hum e)}"]
;;

(* Tests still ask for a symbol count, not a name set — the id math is what
   they exercise. We synthesize a directory so the server has one: the first
   few ids get the canonical tickers (matching [app/server]'s set, so a test
   that does render names sees familiar ones), and any beyond that get a
   generated [SYM<n>] placeholder. *)
let canonical_names = [ "AAPL"; "TSLA"; "GOOG"; "MSFT" ]

let default_directory ~num_symbols =
  List.init num_symbols ~f:(fun i ->
    match List.nth canonical_names i with
    | Some name -> name
    | None -> [%string "SYM%{i#Int}"])
  |> List.map ~f:Symbol.of_string
  |> Symbol_directory.of_names
;;

let with_server ~num_symbols f =
  let directory = default_directory ~num_symbols in
  let%bind server = Exchange_server.start ~directory ~port:0 () in
  let port = Exchange_server.port server in
  Monitor.protect
    (fun () -> f ~server ~port)
    ~finally:(fun () -> Exchange_server.close server)
;;

type client = { conn : Rpc.Connection.t }

let connect_as ~port ?(login = true) participant =
  let where =
    Tcp.Where_to_connect.of_host_and_port { host = "localhost"; port }
  in
  let%bind conn = Rpc.Connection.client where >>| Result.ok_exn in
  if not login
  then return { conn }
  else (
    let%bind () =
      Rpc.Rpc.dispatch_exn
        Rpc_protocol.login_rpc
        conn
        (Participant.to_string participant)
      >>| ok_str
    in
    let%bind session_feed, _metadata =
      Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc conn ()
    in
    don't_wait_for
      (Pipe.iter_without_pushback session_feed ~f:(fun event ->
         let e = Protocol.format_event event in
         print_endline [%string "[for %{(participant)#Participant}] %{e}"]));
    return { conn })
;;

let connection client = client.conn

let rpc_submit client request =
  Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc client.conn request
  >>| ok_str
;;

let rpc_book client symbol =
  Rpc.Rpc.dispatch_exn Rpc_protocol.book_query_rpc client.conn symbol
;;

let rpc_cancel client client_order_id =
  Rpc.Rpc.dispatch_exn
    Rpc_protocol.cancel_order_rpc
    client.conn
    client_order_id
  >>| ok_str
;;

let rpc_cancel_all client =
  Rpc.Rpc.dispatch_exn Rpc_protocol.cancel_all_rpc client.conn ()
;;

let rpc_subscribe client symbols participant_name =
  let%bind market_feed, _metadata =
    Rpc.Pipe_rpc.dispatch_exn
      Rpc_protocol.market_data_rpc
      client.conn
      symbols
  in
  let () =
    don't_wait_for
      (Pipe.iter_without_pushback market_feed ~f:(fun event ->
         let e = Protocol.format_event event in
         print_endline [%string "[for %{participant_name}] %{e}"]))
  in
  return ()
;;
