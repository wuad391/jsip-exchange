open! Core
open! Async
open Jsip_types
open Jsip_order_book

module Connection_state = struct
  type t = { mutable session : Session.t option }

  let participant t = Option.map t.session ~f:Session.participant
  let session t = t.session
  let update_session t session = t.session <- Some session
end

type t =
  { engine : Matching_engine.t
  ; dispatcher : Dispatcher.t
  ; request_writer : Order.Request.t Pipe.Writer.t
  ; tcp_server : (Socket.Address.Inet.t, int) Tcp.Server.t
  ; port : int
  }

(* Bound how many client requests can sit in the queue waiting for the
   matching engine. Once the queue is full, [Pipe.write] returns a pending
   deferred and the [submit_order_rpc] handler blocks until the engine has
   processed enough requests to free up space — clients get backpressure
   without the server's memory growing unboundedly. *)
let request_queue_size_budget = 1024

let handle_submit ~request_writer (request : Order.Request.t) =
  let%map () = Pipe.write_if_open request_writer request in
  Ok ()
;;

let start_matching_loop ~engine ~dispatcher request_reader =
  don't_wait_for
    (Pipe.iter_without_pushback request_reader ~f:(fun request ->
       let events = Matching_engine.submit engine request in
       Dispatcher.dispatch dispatcher events))
;;

let start ~symbols ~port () =
  let engine = Matching_engine.create symbols in
  let dispatcher = Dispatcher.create () in
  let request_reader, request_writer = Pipe.create () in
  Pipe.set_size_budget request_writer request_queue_size_budget;
  start_matching_loop ~engine ~dispatcher request_reader;
  let implementations =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Rpc.Rpc.implement
            Rpc_protocol.submit_order_rpc
            (fun state request ->
               let () = print_endline [%string "I am in submit_order_rpc"] in
               match Connection_state.session state with
               | None ->
                 return (Or_error.error_string "User is not logged in.")
                 (* TODO how to not use wildcard but otherwise i get unused
                    var warning *)
               | Some _ ->
                 let valid_request =
                   { request with
                     participant =
                       Option.value
                         (Connection_state.participant state)
                         ~default:(Participant.of_string "anon")
                   }
                 in
                 let%bind result =
                   handle_submit ~request_writer valid_request
                 in
                 (match result with
                  | Ok () -> return (Ok ())
                  | Error _ ->
                    return (Or_error.error_string "Submission error")))
        ; Rpc.Rpc.implement' Rpc_protocol.book_query_rpc (fun state symbol ->
            ignore state;
            Matching_engine.book engine symbol
            |> Option.map ~f:Order_book.snapshot)
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.market_data_rpc
            (fun state symbols ->
               ignore state;
               let reader =
                 Dispatcher.subscribe_market_data dispatcher symbols
               in
               return (Ok reader))
        ; Rpc.Pipe_rpc.implement Rpc_protocol.audit_log_rpc (fun state () ->
            ignore state;
            let reader = Dispatcher.subscribe_audit dispatcher in
            return (Ok reader))
        ; Rpc.Rpc.implement
            Rpc_protocol.login_rpc
            (fun state participant_str ->
               if String.is_empty (String.strip participant_str)
               then
                 return
                   (Or_error.error_string
                      "Whitespace names not allowed for login_rpc")
               else (
                 let participant = Participant.of_string participant_str in
                 if Dispatcher.is_active dispatcher participant
                 then
                   return
                     (Or_error.error_string
                        [%string
                          "Participant %{(participant_str)#String} already \
                           has a session active."])
                 else (
                   let%bind () =
                     Dispatcher.set_up_session dispatcher participant
                   in
                   (* let () = Dispatcher.print_sessions dispatcher in *)
                   let has_active_session =
                     Dispatcher.lookup_session dispatcher participant
                   in
                   match has_active_session with
                   | None ->
                     return
                       (Or_error.error_string "This should not be possible")
                   | Some session ->
                     let () =
                       Connection_state.update_session state session
                     in
                     return (Ok participant))))
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.session_feed_rpc
            (fun state () ->
               match Connection_state.session state with
               | None ->
                 return
                   (Error (Error.of_string "not logged in")
                    : (Exchange_event.t Pipe.Reader.t, Error.t) result)
               | Some session -> return (Ok (Session.reader session)))
        ]
      ~on_unknown_rpc:`Close_connection
      ~on_exception:Log_on_background_exn
  in
  let%map tcp_server =
    Rpc.Connection.serve
      ~implementations
      ~initial_connection_state:(fun _addr _conn ->
        let new_state : Connection_state.t = { session = None } in
        let close_connection =
          let%bind () =
            match new_state.session with
            | None -> return ()
            | Some session -> Dispatcher.clean_up_session dispatcher session
          in
          Rpc.Connection.close_finished _conn
        in
        don't_wait_for close_connection;
        new_state)
      ~where_to_listen:(Tcp.Where_to_listen.of_port port)
      ()
  in
  let actual_port = Tcp.Server.listening_on tcp_server in
  { engine; dispatcher; request_writer; tcp_server; port = actual_port }
;;

let port t = t.port

let close t =
  Pipe.close t.request_writer;
  Tcp.Server.close t.tcp_server
;;

let close_finished t = Tcp.Server.close_finished t.tcp_server
