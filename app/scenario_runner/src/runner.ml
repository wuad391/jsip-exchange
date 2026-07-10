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

(* Bring up one bot end-to-end: open its own RPC connection, subscribe to the
   market-data stream for the symbols listed in the spec, and run the bot.
   Once the session feed exists (week 2 exercise 1) this is also where each
   bot will log in and subscribe to its session-feed RPC, so its [on_event]
   handler can react to the matching engine's responses to its own orders and
   to fills against its resting orders. *)
let start_bot ~where_to_connect ~oracle ~counts (Bot_spec.T spec) =
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
  let () =
    match login_result with
    | Ok _ -> print_endline [%string "Bot is logged in and running."]
    | Error _ -> print_endline [%string "Error logging bot in."]
  in
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
     that opts out (e.g. a pure order/cancel spammer) then never receives MD,
     saving the subscription and the per-event [feed_event] work. *)
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
  let output = Pipe.interleave (session_feed :: market_data_feeds) in
  don't_wait_for (Pipe.iter output ~f:(Bot_runtime.feed_event bot));
  print_endline
    [%string "[scenario] starting bot %{spec.participant#Participant}"];
  don't_wait_for (Bot_runtime.start bot);
  return ()
;;

let run ?(count_orders = false) (config : Scenario_config.t) ~port ~seed =
  print_endline
    [%string
      "[scenario] starting %{config.name} on port %{port#Int} \
       (seed=%{seed#Int})"];
  (* The scenario's own directory fixes the exchange's symbol universe, so a
     client connecting to this run resolves the same ids back to names. *)
  let%bind server =
    Exchange_server.start
      ~directory:config.directory
      ~dispatcher_config:Dispatcher.Config.default
      ~port
      ()
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
  let%bind () =
    Deferred.List.iter
      ~how:`Parallel
      config.bots
      ~f:(start_bot ~where_to_connect ~oracle ~counts)
  in
  Exchange_server.close_finished server
;;
