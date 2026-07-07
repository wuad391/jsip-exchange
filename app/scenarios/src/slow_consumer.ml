open! Core
open Jsip_types
open Jsip_scenario_runner
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module Market_maker_bot = Jsip_market_maker.Market_maker_bot
module Noise_trader = Jsip_bots.Noise_trader
module Slow_consumer_bot = Jsip_bots.Slow_consumer

let name = "slow-consumer"

let description =
  "One symbol, a fast-quoting market maker, and one or more subscribers \
   that read their market-data feed too slowly to keep up — so events pile \
   up in the exchange-side buffer. Demonstrates the unbounded-buffering \
   pathology."
;;

let aapl = Symbol.of_string "AAPL"

(* A gently drifting fundamental so the market maker's quotes keep moving,
   which keeps market-data events flowing for the slow consumers to fall
   behind on. Deterministic given the runner's seed. *)
let oracle_config : Fundamental_oracle.Config.t =
  Symbol.Map.of_alist_exn
    [ ( aapl
      , { Fundamental_oracle.Config.initial_price_cents = 15000
        ; volatility_cents_per_sec = 10.0
        ; mean_reversion_strength = 0.05
        ; tick_interval = Time_ns.Span.of_sec 0.5
        } )
    ]
;;

(* Build one market-maker instance. Each instance needs its own [participant]
   name — the gateway keys sessions by participant, so reusing a name would
   evict the earlier session — and its own [rng_seed]. *)
let market_maker_spec ~participant ~rng_seed =
  Bot_spec.T
    { bot = (module Market_maker_bot)
    ; config =
        Market_maker_bot.create_config
          ()
          ~size_per_level:100
          ~num_levels:3
          ~inventory_skew_cents_per_share:1
          ~symbols:[ aapl ]
    ; participant
    ; symbols = [ aapl ]
    ; rng_seed
    ; (* Re-quote four times a second: a brisk stream of BBO updates. *)
      tick_interval = Time_ns.Span.of_sec 0.25
    ; is_marketdata_consumer = false
    }
;;

(* Build one slow-consumer instance. [read_delay] tunes how far behind this
   particular consumer falls: the bigger it is relative to the market maker's
   event rate, the faster this subscriber's exchange-side buffer grows. *)
let slow_consumer_spec ~participant ~rng_seed ~read_delay =
  Bot_spec.T
    { bot = (module Slow_consumer_bot)
    ; config = Slow_consumer_bot.Config.create ~read_delay
    ; participant
    ; symbols = [ aapl ]
    ; rng_seed
    ; tick_interval = Time_ns.Span.of_sec 5.0
    ; is_marketdata_consumer = true
    }
;;

(* The roster of consumers to launch side by side. Each entry is
   [(participant name, rng seed, per-event read delay)]. Distinct names and
   seeds let every instance run and lag independently; varied delays let you
   compare a mildly-slow consumer against a hopelessly-slow one in a single
   run. Add or remove rows to change the cast. *)
let consumer_roster =
  [ "SlowConsumer-2s", 2, Time_ns.Span.of_sec 2.0
  ; "SlowConsumer-5s", 3, Time_ns.Span.of_sec 5.0
  ]
;;

(* [Market_maker_bot] only re-quotes in reaction to a [Fill] on its own
   resting orders (see its [on_event]); its [on_tick] just refreshes the
   cached fair value and never submits anything. Left on its own, it seeds
   one ladder at [on_start] and then sits there forever, since nothing here
   crosses its spread — no fills, no re-quotes, no market data for the slow
   consumers to fall behind on. These noise traders exist to be that
   counterparty: fairly aggressive and fairly frequent, so the maker keeps
   getting filled and keeps re-quoting, producing the "brisk stream" this
   scenario is supposed to demonstrate. *)
let noise_trader_spec ~participant ~rng_seed =
  Bot_spec.T
    { bot = (module Noise_trader)
    ; config =
        Noise_trader.create_config
          ~symbols:[ aapl ]
          ~avg_size:20
          ~tick_chance:0.8
          ~aggressiveness_pct:60
          ~ioc_pct:40
    ; participant
    ; symbols = [ aapl ]
    ; rng_seed
    ; tick_interval = Time_ns.Span.of_ms 200.0
    ; is_marketdata_consumer = true
    }
;;

let noise_trader_roster =
  [ "NoiseTrader-1", 101; "NoiseTrader-2", 102 ]
;;

let configure () : Scenario_config.t =
  let market_makers =
    [ market_maker_spec
        ~participant:(Participant.of_string "MarketMaker")
        ~rng_seed:1
    ]
  in
  let slow_consumers =
    List.map consumer_roster ~f:(fun (name, rng_seed, read_delay) ->
      slow_consumer_spec
        ~participant:(Participant.of_string name)
        ~rng_seed
        ~read_delay)
  in
  let noise_traders =
    List.map noise_trader_roster ~f:(fun (name, rng_seed) ->
      noise_trader_spec ~participant:(Participant.of_string name) ~rng_seed)
  in
  { name
  ; symbols = [ aapl ]
  ; oracle_config
  ; news = []
  ; bots = market_makers @ noise_traders @ slow_consumers
  }
;;
