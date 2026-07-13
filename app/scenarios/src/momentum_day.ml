open! Core
open Jsip_types
open Jsip_scenario_runner
open Jsip_symbol_directory
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module News_injector = Jsip_news_injector.News_injector
module Momentum_trader = Jsip_bots.Momentum_trader_hansel
module Noise_trader = Jsip_bots.Noise_trader
module Market_maker_bot = Jsip_market_maker.Market_maker_bot

let name = "momentum-day"

let description =
  "Scripted up-then-down trend that the momentum trader chases, with a \
   market maker quoting and a noise trader adding organic activity."
;;

let symbol = Symbol.of_string "AAPL"
let initial_price_cents = 15000

(* Low intrinsic volatility and gentle mean reversion, so the fundamental
   drifts quietly on its own. The visible price *moves* in this scenario come
   from the scripted news shocks below, not from the oracle's own noise --
   that keeps the momentum trader's signal driven by the trend we scripted
   rather than by random wiggles. *)
let oracle_config ~symbol_id : Fundamental_oracle.Config.t =
  Symbol_id.Map.of_alist_exn
    [ ( symbol_id
      , { Fundamental_oracle.Config.initial_price_cents
        ; volatility_cents_per_sec = 1.0
        ; mean_reversion_strength = 0.02
        ; tick_interval = Time_ns.Span.of_sec 1.0
        } )
    ]
;;

(* A staircase of shocks: a run of positive steps builds a sustained uptrend,
   then a run of negative steps reverses it into a downtrend. Each step is
   larger than the momentum trader's [threshold_cents] and they arrive a few
   seconds apart, so the trader's price window fills with a clear one-way
   move and its signal crosses the threshold in each direction in turn -- it
   should buy into the rise and sell into the fall. Priced in a single place
   so the trend's shape is easy to retune. *)
let trend_news ~symbol_id =
  let step_cents = 40 in
  let step_every = Time_ns.Span.of_sec 3.0 in
  let up_steps = 6 in
  let down_steps = 6 in
  let event ~index ~delta ~label : News_injector.Event.t =
    { at = Time_ns.Span.scale step_every (Float.of_int index)
    ; symbol = symbol_id
    ; delta_cents = delta
    ; description = label
    }
  in
  let ups =
    List.init up_steps ~f:(fun i ->
      event ~index:(i + 1) ~delta:step_cents ~label:"uptrend step (+)")
  in
  let downs =
    List.init down_steps ~f:(fun i ->
      event
        ~index:(up_steps + i + 1)
        ~delta:(-step_cents)
        ~label:"downtrend step (-)")
  in
  ups @ downs
;;

(* The star of the scenario. A short window and a modest threshold make it
   react within a couple of steps of a trend; [cooldown_ticks] keeps one
   sustained move from firing on literally every tick. [Ioc] entries take
   whatever the market maker and noise trader are resting near the touch and
   cancel the rest, so the trader's position tracks the trend without leaving
   stale orders behind. *)
let momentum_trader_spec ~symbol_id =
  Bot_spec.T
    { bot = (module Momentum_trader)
    ; config =
        Momentum_trader.Config.create_exn
          ~symbol:symbol_id
          ~window_capacity:5
          ~threshold_cents:15
          ~max_order_size:25
          ~max_position:200
          ~cooldown_ticks:1
          ()
    ; participant = Participant.of_string "momentum-trader"
    ; symbols = [ symbol_id ]
    ; rng_seed = 4001
    ; tick_interval = Time_ns.Span.of_ms 500.0
    ; is_marketdata_consumer = true
    }
;;

(* Quotes both sides so the momentum trader's marketable [Ioc] entries always
   have resting liquidity to hit, and so the book has a sensible spread as
   the fundamental walks with the news. *)
let market_maker_spec ~symbols =
  Bot_spec.T
    { bot = (module Market_maker_bot)
    ; config =
        Market_maker_bot.create_config
          ()
          ~size_per_level:10
          ~num_levels:5
          ~inventory_skew_cents_per_share:1
          ~symbols
    ; participant = Participant.of_string "market-maker"
    ; symbols
    ; rng_seed = 2001
    ; tick_interval = Time_ns.Span.of_sec 1.0
    ; is_marketdata_consumer = true
    }
;;

(* Organic two-sided flow so the trade tape has prints between shocks -- the
   momentum trader reads [Trade_report]s, so this keeps its price window fed
   even during the quiet stretches between news steps. *)
let noise_trader_spec ~symbols =
  Bot_spec.T
    { bot = (module Noise_trader)
    ; config =
        Noise_trader.create_config
          ~symbols
          ~avg_size:8
          ~tick_chance:0.8
          ~aggressiveness_pct:50
          ~ioc_pct:40
    ; participant = Participant.of_string "noise-trader"
    ; symbols
    ; rng_seed = 3001
    ; tick_interval = Time_ns.Span.of_ms 200.0
    ; is_marketdata_consumer = true
    }
;;

let configure () : Scenario_config.t =
  let directory = Symbol_directory.of_names [ symbol ] in
  let symbol_id = Symbol_directory.id_exn directory symbol in
  let symbols = [ symbol_id ] in
  { name
  ; directory
  ; oracle_config = oracle_config ~symbol_id
  ; news = trend_news ~symbol_id
  ; bots =
      [ momentum_trader_spec ~symbol_id
      ; market_maker_spec ~symbols
      ; noise_trader_spec ~symbols
      ]
  }
;;
