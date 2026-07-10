open! Core
open Jsip_types
open Jsip_scenario_runner
open Jsip_symbol_directory
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module Noise_trader = Jsip_bots.Noise_trader
module Market_maker_bot = Jsip_market_maker.Market_maker_bot

let name = "calm-day"

let description =
  "Quiet single-symbol market: one market maker, one noise trader, no news."
;;

let symbol = Symbol.of_string "AAPL"
let initial_price_cents = 15000

let configure () : Scenario_config.t =
  (* This scenario trades a single symbol; build its name<->id directory here
     and resolve the id once. The exchange the runner boots is keyed on this
     same directory, so a client connecting to the run renders [AAPL]. *)
  let directory = Symbol_directory.of_names [ symbol ] in
  let symbol_id = Symbol_directory.id_exn directory symbol in
  (* Modest volatility and gentle mean reversion: the fundamental drifts
     quietly around its starting value with no dramatic moves. There are no
     news shocks in this scenario, so this OU noise is the *only* thing
     moving fair value -- keeping it small is what makes the day "calm". *)
  let oracle_config : Fundamental_oracle.Config.t =
    Symbol_id.Map.of_alist_exn
      [ ( symbol_id
        , { Fundamental_oracle.Config.initial_price_cents
          ; volatility_cents_per_sec = 3.0
          ; mean_reversion_strength = 0.05
          ; tick_interval = Time_ns.Span.of_sec 1.0
          } )
      ]
  in
  (* A standard two-sided market maker. Its wide tolerance means it keeps
     quoting through the whole (uneventful) day rather than ever standing
     aside -- there is no whale here to blow the spread out. *)
  let market_maker_spec =
    Bot_spec.T
      { bot = (module Market_maker_bot)
      ; config =
          Market_maker_bot.create_config
            ()
            ~size_per_level:10
            ~num_levels:5
            ~inventory_skew_cents_per_share:1
            ~symbols:[ symbol_id ]
      ; participant = Participant.of_string "market-maker"
      ; symbols = [ symbol_id ]
      ; rng_seed = 2001
      ; tick_interval = Time_ns.Span.of_sec 1.0
      ; is_marketdata_consumer = true
      }
  in
  (* One unhurried noise trader. Small sizes, a slow tick, and a coin-flip
     aggressiveness keep a steady but sparse trickle of orders crossing the
     maker's quotes -- enough to see a continuous stream of fills in the
     monitor without the book ever getting busy. A low [ioc_pct] means most
     of its orders rest, so the book stays populated between crossings. *)
  let noise_trader_spec =
    Bot_spec.T
      { bot = (module Noise_trader)
      ; config =
          Noise_trader.create_config
            ~symbols:[ symbol_id ]
            ~avg_size:6
            ~tick_chance:0.5
            ~aggressiveness_pct:45
            ~ioc_pct:30
      ; participant = Participant.of_string "noise-trader"
      ; symbols = [ symbol_id ]
      ; rng_seed = 3001
      ; tick_interval = Time_ns.Span.of_ms 400.0
      ; is_marketdata_consumer = true
      }
  in
  { name
  ; directory
  ; oracle_config
  ; news = []
  ; bots = [ market_maker_spec; noise_trader_spec ]
  }
;;
