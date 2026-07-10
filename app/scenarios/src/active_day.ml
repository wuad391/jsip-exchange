open! Core
open Jsip_types
open Jsip_scenario_runner
open Jsip_symbol_directory
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module Noise_trader = Jsip_bots.Noise_trader
module Market_maker_bot = Jsip_market_maker.Market_maker_bot

let name = "active-day"

let description =
  "Multi-symbol busy market: several market makers and a higher-throughput \
   noise trader."
;;

(* The whole scenario is driven off this one table: each row is a symbol, its
   starting/mean price, and the RNG seed for that symbol's market maker.
   Every derived structure below (the oracle config, the per-symbol market
   makers) is a [List.map] over it, so adding a fourth symbol is a single new
   row -- it automatically gets an oracle entry, its own market maker, and
   market data for the shared noise trader. *)
let symbol_table =
  [ Symbol.of_string "AAPL", 15000, 2001
  ; Symbol.of_string "GOOG", 28000, 2002
  ; Symbol.of_string "MSFT", 41000, 2003
  ]
;;

let symbol_names = List.map symbol_table ~f:(fun (symbol, _, _) -> symbol)

(* Moderate volatility on every symbol so all three books stay lively at once
   -- an "active" day is one where there is always something happening
   somewhere. *)
let oracle_config ~directory : Fundamental_oracle.Config.t =
  List.map symbol_table ~f:(fun (symbol, initial_price_cents, _) ->
    ( Symbol_directory.id_exn directory symbol
    , { Fundamental_oracle.Config.initial_price_cents
      ; volatility_cents_per_sec = 4.0
      ; mean_reversion_strength = 0.05
      ; tick_interval = Time_ns.Span.of_sec 1.0
      } ))
  |> Symbol_id.Map.of_alist_exn
;;

(* One dedicated market maker per symbol, each quoting (and consuming market
   data for) only its own symbol. Distinct participant names and seeds keep
   them independent, and a self-trade-preventing engine means a maker never
   fills against itself -- the crossing flow comes from the noise trader. The
   participant name keeps the human ticker (e.g. [market-maker-AAPL]), read
   from the table's [Symbol.t] before it is resolved to an id. *)
let market_maker_specs ~directory =
  List.map symbol_table ~f:(fun (symbol, _, seed) ->
    let symbol_id = Symbol_directory.id_exn directory symbol in
    Bot_spec.T
      { bot = (module Market_maker_bot)
      ; config =
          Market_maker_bot.create_config
            ()
            ~size_per_level:10
            ~num_levels:5
            ~inventory_skew_cents_per_share:1
            ~symbols:[ symbol_id ]
      ; participant =
          Participant.of_string [%string "market-maker-%{symbol#Symbol}"]
      ; symbols = [ symbol_id ]
      ; rng_seed = seed
      ; tick_interval = Time_ns.Span.of_sec 1.0
      ; is_marketdata_consumer = true
      })
;;

(* A single high-throughput noise trader spanning every symbol: it ticks
   fast, trades larger sizes, and crosses the spread half the time, so all
   three books see heavy two-sided flow from one bot. Because it subscribes
   to every symbol's market data, its internal BBO cache stays fresh across
   the board. *)
let noise_trader_spec ~symbols =
  Bot_spec.T
    { bot = (module Noise_trader)
    ; config =
        Noise_trader.create_config
          ~symbols
          ~avg_size:12
          ~tick_chance:0.9
          ~aggressiveness_pct:55
          ~ioc_pct:45
    ; participant = Participant.of_string "noise-trader"
    ; symbols
    ; rng_seed = 3001
    ; tick_interval = Time_ns.Span.of_ms 100.0
    ; is_marketdata_consumer = true
    }
;;

let configure () : Scenario_config.t =
  let directory = Symbol_directory.of_names symbol_names in
  let symbols =
    List.map symbol_table ~f:(fun (symbol, _, _) ->
      Symbol_directory.id_exn directory symbol)
  in
  { name
  ; directory
  ; oracle_config = oracle_config ~directory
  ; news = []
  ; bots = market_maker_specs ~directory @ [ noise_trader_spec ~symbols ]
  }
;;
