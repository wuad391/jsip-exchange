(** Exchange server.

    Runs the matching engine and listens for RPC connections from clients..

    Run with: dune exec app/server/bin/main.exe -- -port 12345

    Optionally seed the book with a market maker: dune exec
    app/server/bin/main.exe -- -port 12345 -seed-market-maker *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway
open Jsip_market_maker
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module Bot_runtime = Jsip_bot_runtime.Bot_runtime

let default_symbols =
  [ Symbol.of_string "AAPL"
  ; Symbol.of_string "TSLA"
  ; Symbol.of_string "GOOG"
  ; Symbol.of_string "MSFT"
  ]
;;

(* No session-feed subscription here: [connect_as] only drives the seed
   market makers in [trade_back_and_forth], which submit static ladders via
   [Market_maker.seed_book] and never react to fills, so they have no need to
   consume their session feed. *)
let connect_as ~where_to_connect participant =
  let%bind conn = Rpc.Connection.client where_to_connect >>| Result.ok_exn in
  let%bind login_result =
    Rpc.Rpc.dispatch_exn
      Rpc_protocol.login_rpc
      conn
      (Participant.to_string participant)
  in
  let () =
    match login_result with
    | Ok _ ->
      print_endline
        [%string
          "%{(Participant.to_string participant)#String} is logged in."]
    | Error _ ->
      print_endline
        [%string
          "Error logging %{(Participant.to_string participant)#String} in."]
  in
  return conn
;;

(* Bring up one [Market_maker_bot] end-to-end against [where_to_connect]: log
   in as [participant] (via [connect_as]), subscribe to its session feed and
   to market data for [symbols], then run the bot forever. Mirrors
   [Jsip_scenario_runner.Runner.start_bot] — that function isn't exposed
   outside the scenario runner, and it only supports a single shared oracle
   for every bot, which [trade_back_and_forth] below can't use (each of its
   two market makers needs its own, differently-anchored oracle). *)
let start_market_maker_bot
  ~where_to_connect
  ~participant
  ~oracle
  ~rng_seed
  ~config
  ~symbols
  =
  let%bind connection = connect_as ~where_to_connect participant in
  let submit request =
    Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc connection request
  in
  let cancel client_order_id =
    Rpc.Rpc.dispatch_exn
      Rpc_protocol.cancel_order_rpc
      connection
      client_order_id
  in
  let bot =
    Bot_runtime.create
      (module Market_maker_bot)
      config
      ~participant
      ~oracle
      ~rng:(Splittable_random.of_int rng_seed)
      ~submit
      ~cancel
      ~tick_interval:(Time_ns.Span.of_sec 1.)
  in
  let%bind session_feed, _metadata =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc connection ()
  in
  let%bind market_data, _metadata =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.market_data_rpc connection symbols
  in
  don't_wait_for
    (Pipe.iter
       (Pipe.interleave [ session_feed; market_data ])
       ~f:(Bot_runtime.feed_event bot));
  don't_wait_for (Bot_runtime.start bot);
  return ()
;;

(* Two dynamic [Market_maker_bot]s per symbol, each tracking its own
   independently-anchored fundamental-price oracle: MM_Low's oracle is
   anchored [low_offset_cents] below the shared anchor, MM_High's
   [high_offset_cents] above. That persistent gap means MM_High's bid
   regularly crosses MM_Low's ask, producing a steady stream of [Fill] /
   [Trade_report] events across multiple symbols for the monitor to render —
   replacing the old pair of one-shot, non-cancelling
   [Market_maker.seed_book] calls with bots that track inventory and re-quote
   on fills and on market moves.

   [Market_maker_bot]'s half-spread isn't a config knob — it's derived from
   the observed BBO, and defaults to a wide 50 cents on a symbol's very first
   ladder, before any BBO exists. Both bots place that first ladder at once,
   so the anchor gap needs to clear roughly [50 + 50 + 2*(num_levels-1)]
   cents (the two default half-spreads plus the outward per-level offset at
   the widest level) for the very first seed to cross directly — otherwise it
   can take several rounds of the bots narrowing onto each other's observed
   quotes to converge, if it converges at all within a short demo run. 150
   cents comfortably clears that for [num_levels = 3] and guarantees an
   immediate cross.

   Each oracle still mean-reverts toward its own anchor, but the two walk
   independently, so the gap isn't fixed the way the old static fair values
   were — it can narrow or (rarely) invert for a while. That's an acceptable,
   more realistic trade-off for a demo; it isn't tuned for guaranteed
   crossing over arbitrarily long runs. *)
let trade_back_and_forth ~where_to_connect =
  let symbol_anchors =
    [ Symbol.of_string "AAPL", 15000
    ; Symbol.of_string "TSLA", 25000
    ; Symbol.of_string "GOOG", 28000
    ]
  in
  let symbols = List.map symbol_anchors ~f:fst in
  let low_offset_cents = -75 in
  let high_offset_cents = 75 in
  let oracle_config_for ~offset_cents : Fundamental_oracle.Config.t =
    List.map symbol_anchors ~f:(fun (symbol, anchor) ->
      ( symbol
      , { Fundamental_oracle.Config.initial_price_cents =
            anchor + offset_cents
        ; volatility_cents_per_sec = 3.0
        ; mean_reversion_strength = 0.05
        ; tick_interval = Time_ns.Span.of_sec 1.0
        } ))
    |> Symbol.Map.of_alist_exn
  in
  (* [size_per_level] is deliberately small. A full [num_levels]-deep cross
     shifts each side's skewed center by
     [2 * size_per_level * num_levels * inventory_skew_cents_per_share]
     cents; at the default (larger) size_per_level that single burst can
     exceed the anchor gap and fully invert which side is ahead, leaving both
     quoting away from each other with nothing left to trigger a re-cross.
     Keeping the per-burst shift well under the anchor gap means one round
     can't invert the relationship, so crossing continues. *)
  let market_maker_config () =
    Market_maker_bot.create_config
      ()
      ~symbols
      ~size_per_level:5
      ~num_levels:3
      ~inventory_skew_cents_per_share:2
  in
  let oracle_low =
    Fundamental_oracle.create
      (oracle_config_for ~offset_cents:low_offset_cents)
      ~seed:4242
  in
  let oracle_high =
    Fundamental_oracle.create
      (oracle_config_for ~offset_cents:high_offset_cents)
      ~seed:4343
  in
  don't_wait_for (Fundamental_oracle.start oracle_low);
  don't_wait_for (Fundamental_oracle.start oracle_high);
  Deferred.all_unit
    [ start_market_maker_bot
        ~where_to_connect
        ~participant:(Participant.of_string "MM_Low")
        ~oracle:oracle_low
        ~rng_seed:5252
        ~config:(market_maker_config ())
        ~symbols
    ; start_market_maker_bot
        ~where_to_connect
        ~participant:(Participant.of_string "MM_High")
        ~oracle:oracle_high
        ~rng_seed:5353
        ~config:(market_maker_config ())
        ~symbols
    ]
;;

let start ~port ~market_maker_behavior =
  let%bind server =
    Exchange_server.start ~symbols:default_symbols ~port ()
  in
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port { host = "localhost"; port }
  in
  let%bind () =
    match market_maker_behavior with
    | `Trade_back_and_forth ->
      let%map () =
        print_endline
          "=== Starting two market makers trading back-and-forth ===";
        trade_back_and_forth ~where_to_connect
      in
      print_endline ""
    | `Do_nothing -> Deferred.unit
  in
  print_endline
    [%string
      "JSIP Exchange server listening on port %{Exchange_server.port \
       server#Int}"];
  let symbols =
    List.map default_symbols ~f:Symbol.to_string |> String.concat ~sep:", "
  in
  print_endline [%string "Trading: %{symbols}"];
  Exchange_server.close_finished server
;;

let () =
  Command.async
    ~summary:"JSIP Exchange server"
    (let%map_open.Command port =
       flag "-port" (required int) ~doc:"PORT port to listen on"
     and market_maker_behavior =
       choose_one
         ~if_nothing_chosen:(Default_to `Do_nothing)
         [ flag
             "-trade-back-and-forth"
             (no_arg_some `Trade_back_and_forth)
             ~doc:
               " run two market makers in a loop, generating sustained \
                traffic for the monitor (mutually exclusive with \
                -seed-market-maker)"
         ]
     and () = Log.Global.set_level_via_param () in
     fun () -> start ~port ~market_maker_behavior)
  |> Command_unix.run
;;
