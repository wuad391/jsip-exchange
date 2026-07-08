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

(* A message encapsulates all data that can be fed to the matching engine in
   order. Currently, this includes requests (buy and sell) and cancels. By
   keeping all of the time/order sensative data in one place, we avoid any
   ordering issues due to server latency (like if we had a separate pipe for
   cancel). *)
module Message = struct
  type t =
    | Request of
        { participant : Participant.t
        ; request : Order.Request.t
        }
    | Cancel of Order.Cancel.t
end

(* Each queued message is stamped when it enters the queue so the matching
   loop can measure enqueue-to-matched latency — which, under load, is
   dominated by the time the message spends waiting in this queue. *)
module Timed_message = struct
  type t =
    { message : Message.t
    ; enqueued_at : Time_ns.t
    }
end

type t =
  { engine : Matching_engine.t
  ; dispatcher : Dispatcher.t
  ; message_writer : Timed_message.t Pipe.Writer.t
  ; tcp_server : (Socket.Address.Inet.t, int) Tcp.Server.t
  ; port : int
  }

(* Bound how many client requests can sit in the queue waiting for the
   matching engine. Once the queue is full, [Pipe.write] returns a pending
   deferred and the [submit_order_rpc] handler blocks until the engine has
   processed enough requests to free up space — clients get backpressure
   without the server's memory growing unboundedly. *)
let message_queue_size_budget = 1024

let handle_submit ~message_writer ~metrics (message : Message.t) =
  let enqueued_at = Time_ns.now () in
  let participant =
    match message with
    | Message.Request { participant; _ } -> participant
    | Message.Cancel { participant; _ } -> participant
  in
  Metrics.record_arrival metrics ~participant;
  let%map () =
    Pipe.write_if_open message_writer { Timed_message.message; enqueued_at }
  in
  Ok ()
;;

let start_matching_loop ~engine ~dispatcher ~metrics message_reader =
  don't_wait_for
    (Pipe.iter_without_pushback
       message_reader
       ~f:(fun { Timed_message.message; enqueued_at } ->
         let before = Time_ns.now () in
         let events, kind =
           match message with
           | Message.Request { participant; request } ->
             Matching_engine.submit engine ~participant request, `Submit
           | Message.Cancel cancel ->
             Matching_engine.cancel engine cancel, `Cancel
         in
         let matched_at = Time_ns.now () in
         Dispatcher.dispatch dispatcher events;
         let done_at = Time_ns.now () in
         Metrics.record_processed
           metrics
           ~kind
           ~latency:(Time_ns.diff matched_at enqueued_at)
           ~busy:(Time_ns.diff done_at before)))
;;

let start ~num_symbols ~port () =
  let engine = Matching_engine.create num_symbols in
  let dispatcher = Dispatcher.create () in
  let message_reader, message_writer = Pipe.create () in
  Pipe.set_size_budget message_writer message_queue_size_budget;
  let metrics =
    Metrics.create
      ~dispatcher
      ~matching_engine:engine
      ~request_queue_length:(fun () -> Pipe.length message_reader)
  in
  start_matching_loop ~engine ~dispatcher ~metrics message_reader;
  Metrics.start metrics;
  let implementations =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Rpc.Rpc.implement
            Rpc_protocol.submit_order_rpc
            (fun state request ->
               match Connection_state.session state with
               | None ->
                 return (Or_error.error_string "User is not logged in.")
               | Some _session ->
                 (* The participant is established at login and attached
                    server-side, so the client's request never carries it —
                    this is what makes an order attributable to the
                    authenticated session rather than a client-supplied name. *)
                 let participant =
                   Option.value
                     (Connection_state.participant state)
                     ~default:(Participant.of_string "anon")
                 in
                 let%bind result =
                   handle_submit
                     ~message_writer
                     ~metrics
                     (Request { participant; request })
                 in
                 (match result with
                  | Ok () -> return (Ok ())
                  | Error _ ->
                    return (Or_error.error_string "Request submission error")))
        ; Rpc.Rpc.implement' Rpc_protocol.book_query_rpc (fun state symbol ->
            ignore state;
            Matching_engine.book engine symbol
            |> Option.map ~f:Order_book.snapshot)
        ; Rpc.Rpc.implement
            Rpc_protocol.cancel_order_rpc
            (fun state client_order_id ->
               match Connection_state.participant state with
               | None ->
                 return (Or_error.error_string "User is not logged in.")
               | Some participant ->
                 let%bind result =
                   handle_submit
                     ~message_writer
                     ~metrics
                     (Cancel { participant; client_order_id })
                 in
                 (match result with
                  | Ok () -> return (Ok ())
                  | Error _ ->
                    return (Or_error.error_string "Cancel submission error")))
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
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.exchange_stats_rpc
            (fun state () ->
               ignore state;
               return (Ok (Metrics.subscribe metrics)))
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
          let%bind () = Rpc.Connection.close_finished _conn in
          match new_state.session with
          | None -> return ()
          | Some session -> Dispatcher.clean_up_session dispatcher session
        in
        don't_wait_for close_connection;
        new_state)
      ~where_to_listen:(Tcp.Where_to_listen.of_port port)
      ()
  in
  let actual_port = Tcp.Server.listening_on tcp_server in
  { engine; dispatcher; message_writer; tcp_server; port = actual_port }
;;

let port t = t.port

let close t =
  Pipe.close t.message_writer;
  Tcp.Server.close t.tcp_server
;;

let close_finished t = Tcp.Server.close_finished t.tcp_server
