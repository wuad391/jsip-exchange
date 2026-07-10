open! Core
open Jsip_types
open Jsip_scenario_runner
open Jsip_symbol_directory
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle

let name = "sandbox"

let description =
  "Empty playground: three symbols, a calm oracle, no bots, no news — the \
   natural home of the -interactive console."
;;

(* Same tickers and starting prices as the cancel-storm scenario, so anyone
   hopping between scenarios sees familiar books. *)
let symbol_table =
  [ Symbol.of_string "AAPL", 15000
  ; Symbol.of_string "GOOG", 28000
  ; Symbol.of_string "MSFT", 41000
  ]
;;

let configure () : Scenario_config.t =
  let directory = Symbol_directory.of_names (List.map symbol_table ~f:fst) in
  (* calm-day's oracle settings: quiet drift, gentle mean reversion. With no
     bots and no news, the market only moves when console-spawned bots make
     it move — which is the point. *)
  let oracle_config =
    List.map symbol_table ~f:(fun (symbol, initial_price_cents) ->
      ( Symbol_directory.id_exn directory symbol
      , { Fundamental_oracle.Config.initial_price_cents
        ; volatility_cents_per_sec = 3.0
        ; mean_reversion_strength = 0.05
        ; tick_interval = Time_ns.Span.of_sec 1.0
        } ))
    |> Symbol_id.Map.of_alist_exn
  in
  { name; directory; oracle_config; news = []; bots = [] }
;;
