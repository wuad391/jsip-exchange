open! Core
open! Async
open Jsip_gateway
open Jsip_types

let ok_str res =
  match res with
  | Ok _ -> ()
  | Error e -> print_endline [%string "%{(Error.to_string_hum e)}"]
;;

let with_server ?limits ~symbols f =
  let%bind server = Exchange_server.start ?limits ~symbols ~port:0 () in
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
