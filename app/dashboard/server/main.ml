open! Core
open! Async
open Jsip_gateway
module Dashboard_state = Jsip_dashboard.Dashboard_state

(* The dashboard's native half. It connects to a running exchange, subscribes
   to its per-second stats stream ([Rpc_protocol.exchange_stats_rpc]), folds
   each snapshot into a rolling window, and serves that window to browsers:
   the window over a websocket RPC the browser polls, and the compiled Bonsai
   app as static files over HTTP. Keeping the web serving here — not in the
   exchange — matches "a separate binary that connects to a running
   exchange". *)

let connect_to_exchange ~host ~port =
  let%map result =
    Rpc.Connection.client
      (Tcp.Where_to_connect.of_host_and_port { host; port })
  in
  match result with
  | Ok connection -> connection
  | Error exn ->
    raise_s
      [%message
        "dashboard: failed to connect to exchange"
          (host : string)
          (port : int)
          (exn : Exn.t)]
;;

let subscribe_stats ~connection ~host ~port =
  match%map
    Rpc.Pipe_rpc.dispatch Rpc_protocol.exchange_stats_rpc connection ()
  with
  | Error err | Ok (Error err) ->
    raise_s
      [%message
        "dashboard: exchange-stats subscription failed"
          (host : string)
          (port : int)
          (err : Error.t)]
  | Ok (Ok (pipe, _metadata)) -> pipe
;;

(* Serve the compiled client bundle ([main.bc.js], copied next to this exe by
   a dune rule) plus a boilerplate index page whose body holds a
   [<div id="app">] for Bonsai to mount into. *)
let static_handler =
  Cohttp_static_handler.Single_page_handler.create_handler
    (Cohttp_static_handler.Single_page_handler.default_with_body_div
       ~div_id:"app")
    ~assets:
      [ Cohttp_static_handler.Asset.local
          Cohttp_static_handler.Asset.Kind.javascript
          (Cohttp_static_handler.Asset.What_to_serve.file
             ~relative_to:`Exe
             ~path:"main.bc.js")
      ]
    ~on_unknown_url:`Index
;;

let serve ~http_port ~window =
  let implementations =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Polling_state_rpc.implement
            ~on_client_and_server_out_of_sync:(fun details ->
              Core.eprint_s
                [%message
                  "dashboard: client and server out of sync"
                    (details : Sexp.t)])
            Jsip_dashboard_protocol.stats_rpc
            (fun (_ : unit) () -> return (Dashboard_state.snapshots !window))
        ]
      ~on_unknown_rpc:`Close_connection
      ~on_exception:Close_connection
  in
  (* [Polling_state_rpc] tracks per-client diff state keyed by the connection,
     so the implementation's connection state must carry the [Rpc.Connection.t]
     alongside our own (empty) state. *)
  Rpc_websocket.Rpc.serve
    ~where_to_listen:(Tcp.Where_to_listen.of_port http_port)
    ~implementations
    ~initial_connection_state:(fun () _ _ connection -> (), connection)
    ~http_handler:(fun () -> static_handler)
    ()
;;

let main ~exchange_host ~exchange_port ~http_port () =
  let%bind connection =
    connect_to_exchange ~host:exchange_host ~port:exchange_port
  in
  let%bind stats =
    subscribe_stats ~connection ~host:exchange_host ~port:exchange_port
  in
  (* Fold the exchange's snapshots into the rolling window as they arrive;
     the poll RPC just reads the current window. *)
  let window = ref Dashboard_state.empty in
  don't_wait_for
    (Pipe.iter_without_pushback stats ~f:(fun snapshot ->
       window := Dashboard_state.add !window snapshot));
  let%bind _server = serve ~http_port ~window in
  Core.print_s
    [%message
      "dashboard: serving"
        ~url:(sprintf "http://localhost:%d" http_port : string)];
  Deferred.never ()
;;

let command =
  Command.async
    ~summary:
      "JSIP monitoring dashboard: subscribes to a running exchange's stats \
       stream and serves a bonsai_web dashboard over HTTP."
    (let%map_open.Command exchange_host =
       flag
         "-exchange-host"
         (optional_with_default "localhost" string)
         ~doc:"HOST exchange server hostname (default localhost)"
     and exchange_port =
       flag
         "-exchange-port"
         (optional_with_default 12345 int)
         ~doc:"PORT exchange server port (default 12345)"
     and http_port =
       flag
         "-http-port"
         (optional_with_default 8080 int)
         ~doc:"PORT port to serve the dashboard on (default 8080)"
     in
     fun () -> main ~exchange_host ~exchange_port ~http_port ())
    ~behave_nicely_in_pipeline:false
;;

let () = Command_unix.run command
