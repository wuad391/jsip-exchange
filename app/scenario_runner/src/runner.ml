open! Core
open! Async
open Jsip_types
open Jsip_gateway
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module News_injector = Jsip_news_injector.News_injector
module Bot_runtime = Jsip_bot_runtime.Bot_runtime

(* Whole-run tally of how many times bots called [submit] and [cancel],
   driven by the [-count-orders] flag. This is the "frequency" half of a cost
   x frequency analysis: the order-book benchmarks say what each operation
   costs, and this says how often a real scenario drives the two entry points
   that fan out into those operations. One shared record rather than a
   per-participant table — we only want the totals, to see which order-book
   functions are worth optimizing. *)
module Call_counts = struct
  type t =
    { mutable submits : int
    ; mutable cancels : int
    }

  let create () = { submits = 0; cancels = 0 }
end

let print_call_counts (counts : Call_counts.t) =
  print_endline
    [%string
      "[scenario] order flow this run: %{counts.submits#Int} submits, \
       %{counts.cancels#Int} cancels"]
;;

(* Bring up one bot end-to-end: open its own RPC connection, log in,
   subscribe to the session feed (and market data when the spec asks for it),
   pump events into [on_event], and start the tick loop. Every piece —
   connection, tick loop, feed — is retained in the returned [Bot_handle.t]
   so the interactive console can tear the bot down again mid-run. *)
let start_bot ?counts ~where_to_connect ~oracle (Bot_spec.T spec) =
  let%bind connection =
    Rpc.Connection.client where_to_connect
    >>| Result.map_error ~f:Error.of_exn
    >>| ok_exn
  in
  let%bind login_result =
    Rpc.Rpc.dispatch_exn
      Rpc_protocol.login_rpc
      connection
      (Participant.to_string spec.participant)
  in
  match login_result with
  | Error error ->
    let%bind () = Rpc.Connection.close connection in
    return
      (Or_error.error_s
         [%message
           "bot login failed"
             ~participant:(spec.participant : Participant.t)
             (error : Error.t)])
  | Ok (_ : Participant.t) ->
    let submit request =
      Option.iter counts ~f:(fun (c : Call_counts.t) ->
        c.submits <- c.submits + 1);
      Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc connection request
    in
    let cancel client_order_id =
      Option.iter counts ~f:(fun (c : Call_counts.t) ->
        c.cancels <- c.cancels + 1);
      Rpc.Rpc.dispatch_exn
        Rpc_protocol.cancel_order_rpc
        connection
        client_order_id
    in
    let bot =
      Bot_runtime.create
        spec.bot
        spec.config
        ~participant:spec.participant
        ~oracle
        ~rng:(Splittable_random.of_int spec.rng_seed)
        ~submit
        ~cancel
        ~tick_interval:spec.tick_interval
    in
    let%bind session_feed, _metadata =
      Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc connection ()
    in
    (* Only subscribe to market data if this bot actually consumes it. A bot
       that opts out (e.g. a pure order/cancel spammer) then never receives
       MD, saving the subscription and the per-event [feed_event] work. *)
    let%bind market_data_feeds =
      if spec.is_marketdata_consumer
      then (
        let%map md_pipe, _metadata =
          Rpc.Pipe_rpc.dispatch_exn
            Rpc_protocol.market_data_rpc
            connection
            spec.symbols
        in
        [ md_pipe ])
      else return []
    in
    let feed = Pipe.interleave (session_feed :: market_data_feeds) in
    let feed_pump = Pipe.iter feed ~f:(Bot_runtime.feed_event bot) in
    (* Retained in the handle for teardown, and ALSO [don't_wait_for]'d so an
       escaping exception is routed to the enclosing monitor instead of
       silently parked in the handle. *)
    don't_wait_for feed_pump;
    print_endline
      [%string "[scenario] starting bot %{spec.participant#Participant}"];
    let tick_loop = Bot_runtime.start bot in
    don't_wait_for tick_loop;
    return
      (Ok
         { Bot_handle.participant = spec.participant
         ; kind = Bot_runtime.bot_name bot
         ; symbols = spec.symbols
         ; connection
         ; runtime = bot
         ; tick_loop
         ; feed
         ; feed_pump
         ; started_at = Time_ns.now ()
         })
;;

let run ?(count_orders = false) (config : Scenario_config.t) ~port ~seed =
  print_endline
    [%string
      "[scenario] starting %{config.name} on port %{port#Int} \
       (seed=%{seed#Int})"];
  (* The scenario's own directory fixes the exchange's symbol universe, so a
     client connecting to this run resolves the same ids back to names. *)
  let%bind server =
    Exchange_server.start ~directory:config.directory ~port ()
  in
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port
      { Host_and_port.host = "localhost"; port }
  in
  let oracle = Fundamental_oracle.create config.oracle_config ~seed in
  let injector = News_injector.create oracle config.news in
  let counts = if count_orders then Some (Call_counts.create ()) else None in
  (* Scenarios run until interrupted, so print the tally both on a clean
     shutdown and when the operator hits Ctrl-C (SIGINT/SIGTERM), routing the
     signal through [Shutdown] so [at_shutdown] fires exactly once. *)
  Option.iter counts ~f:(fun counts ->
    Shutdown.at_shutdown (fun () ->
      print_call_counts counts;
      return ());
    Signal.handle [ Signal.int; Signal.term ] ~f:(fun (_ : Signal.t) ->
      Shutdown.shutdown 0));
  (* Background tasks. *)
  don't_wait_for (Fundamental_oracle.start oracle);
  don't_wait_for (News_injector.start injector);
  (* Scenario bots and (soon) console-spawned bots share one roster, so an
     interactive session can kill or crash the bots the scenario booted. *)
  let registry = Bot_registry.create () in
  let%bind () =
    Deferred.List.iter ~how:`Parallel config.bots ~f:(fun spec ->
      match%map start_bot ?counts ~where_to_connect ~oracle spec with
      | Ok handle ->
        (match Bot_registry.add registry handle with
         | Ok () -> ()
         | Error error -> print_s [%sexp (error : Error.t)])
      | Error error -> print_s [%sexp (error : Error.t)])
  in
  Exchange_server.close_finished server
;;
