open! Core
open Jsip_types
open Jsip_scenario_runner
module Cancel_storm = Jsip_bots.Cancel_storm
module Market_maker_bot = Jsip_market_maker.Market_maker_bot
module Momentum_trader = Jsip_bots.Momentum_trader_hansel
module Noise_trader = Jsip_bots.Noise_trader
module Spammer = Jsip_bots.Spammer

(* [Entry.resolve_knobs] guarantees every declared knob is present in the map
   handed to [make], so a lookup here can only miss if an entry reads a knob
   it forgot to declare — a bug in this file, hence [_exn]. *)
let knob knobs name = Map.find_exn knobs name

let tick_interval knobs =
  Time_ns.Span.of_ms (Float.of_int (knob knobs "tick_ms"))
;;

let tick_ms ~default : Bot_menu.Knob.t =
  { name = "tick_ms"; doc = "tick interval in milliseconds"; default }
;;

(* Defaults from calm-day's market maker (calm_day.ml). *)
let market_maker : Bot_menu.Entry.t =
  { kind = "mm"
  ; doc =
      "two-sided market maker: seeds a bid/ask ladder around fair value and \
       re-quotes on fills"
  ; knobs =
      [ { name = "size_per_level"; doc = "shares per quote"; default = 10 }
      ; { name = "num_levels"
        ; doc = "quotes per side, one cent further out each"
        ; default = 5
        }
      ; { name = "skew_cents_per_share"
        ; doc = "cents the ladder shifts per share of inventory"
        ; default = 1
        }
      ; tick_ms ~default:1000
      ]
  ; make =
      (fun ~participant ~symbols ~knobs ~rng_seed ->
        Ok
          (Bot_spec.T
             { bot = (module Market_maker_bot)
             ; config =
                 Market_maker_bot.create_config
                   ()
                   ~size_per_level:(knob knobs "size_per_level")
                   ~num_levels:(knob knobs "num_levels")
                   ~inventory_skew_cents_per_share:
                     (knob knobs "skew_cents_per_share")
                   ~symbols
             ; participant
             ; symbols
             ; rng_seed
             ; tick_interval = tick_interval knobs
             ; is_marketdata_consumer = true
             }))
  }
;;

(* Defaults from calm-day's noise trader (calm_day.ml). *)
let noise_trader : Bot_menu.Entry.t =
  { kind = "noise"
  ; doc =
      "uninformed random flow: each tick maybe fires one random order \
       priced off the BBO"
  ; knobs =
      [ { name = "avg_size"; doc = "mean order size in shares"; default = 6 }
      ; { name = "tick_pct"
        ; doc = "percent of ticks that send any order"
        ; default = 50
        }
      ; { name = "aggressiveness_pct"
        ; doc = "percent of orders that are marketable"
        ; default = 45
        }
      ; { name = "ioc_pct"
        ; doc = "percent of orders sent IOC rather than Day"
        ; default = 30
        }
      ; tick_ms ~default:400
      ]
  ; make =
      (fun ~participant ~symbols ~knobs ~rng_seed ->
        Ok
          (Bot_spec.T
             { bot = (module Noise_trader)
             ; config =
                 Noise_trader.create_config
                   ~symbols
                   ~avg_size:(knob knobs "avg_size")
                   ~tick_chance:(Float.of_int (knob knobs "tick_pct") /. 100.)
                   ~aggressiveness_pct:(knob knobs "aggressiveness_pct")
                   ~ioc_pct:(knob knobs "ioc_pct")
             ; participant
             ; symbols
             ; rng_seed
             ; tick_interval = tick_interval knobs
             ; is_marketdata_consumer = true
             }))
  }
;;

(* Defaults from momentum-day's momentum trader (momentum_day.ml). *)
let momentum_trader : Bot_menu.Entry.t =
  { kind = "momentum"
  ; doc =
      "trend follower on ONE symbol: chases sustained moves in the public \
       trade tape"
  ; knobs =
      [ { name = "window"
        ; doc = "trade prices the signal spans (>= 2)"
        ; default = 5
        }
      ; { name = "threshold_cents"
        ; doc = "minimum absolute signal before trading"
        ; default = 15
        }
      ; { name = "max_order_size"
        ; doc = "cap in shares on any single order"
        ; default = 25
        }
      ; { name = "max_position"
        ; doc = "cap in shares on the absolute position"
        ; default = 200
        }
      ; { name = "cooldown_ticks"
        ; doc = "ticks skipped after a submission"
        ; default = 1
        }
      ; { name = "aggression_offset_cents"
        ; doc = "cents past the newest trade to price entries"
        ; default = 1
        }
      ; tick_ms ~default:500
      ]
  ; make =
      (fun ~participant ~symbols ~knobs ~rng_seed ->
        match symbols with
        | [ symbol ] ->
          (* [create_exn] raises on out-of-range parameters (window < 2,
             non-positive caps); surface that as the spawn error. *)
          Or_error.try_with (fun () ->
            Bot_spec.T
              { bot = (module Momentum_trader)
              ; config =
                  Momentum_trader.Config.create_exn
                    ~symbol
                    ~window_capacity:(knob knobs "window")
                    ~threshold_cents:(knob knobs "threshold_cents")
                    ~max_order_size:(knob knobs "max_order_size")
                    ~max_position:(knob knobs "max_position")
                    ~cooldown_ticks:(knob knobs "cooldown_ticks")
                    ~aggression_offset_cents:
                      (knob knobs "aggression_offset_cents")
                    ()
              ; participant
              ; symbols
              ; rng_seed
              ; tick_interval = tick_interval knobs
              ; is_marketdata_consumer = true
              })
        | [] | _ :: _ :: _ ->
          Or_error.error_s
            [%message
              "momentum trades exactly one symbol — name one on the spawn \
               line"
                ~got:(List.length symbols : int)])
  }
;;

(* A time-in-force distribution: [day_pct]% resting [Day] orders, the balance
   [Ioc] — same shape spam-storm builds (spam_storm.ml). *)
let day_ioc_mix ~day_pct =
  [ Time_in_force.Day, Percent.of_percentage day_pct
  ; Ioc, Percent.of_percentage (100. -. day_pct)
  ]
;;

(* Defaults from spam-storm's fan-out archetype (spam_storm.ml) — every order
   marketable and IOC, the noisiest events-per-order shape. *)
let spammer : Bot_menu.Entry.t =
  { kind = "spammer"
  ; doc =
      "pathological flood: fires a burst of random orders every tick \
       (fan-out-storm defaults)"
  ; knobs =
      [ { name = "orders_per_burst"
        ; doc = "orders fired per tick"
        ; default = 60
        }
      ; { name = "buy_pct"
        ; doc = "percent of orders that buy"
        ; default = 50
        }
      ; { name = "marketable_pct"
        ; doc = "percent priced to cross rather than rest"
        ; default = 100
        }
      ; { name = "day_pct"
        ; doc = "percent sent Day (resting); the rest are IOC"
        ; default = 0
        }
      ; { name = "mean_size"
        ; doc = "center of the per-order size distribution"
        ; default = 3
        }
      ; { name = "price_jitter_cents"
        ; doc = "half-width of the price band around fair value"
        ; default = 5
        }
      ; tick_ms ~default:10
      ]
  ; make =
      (fun ~participant ~symbols ~knobs ~rng_seed ->
        let behavior : Spammer.Config.behavior =
          Resource_exhaustion
            { orders_per_burst = knob knobs "orders_per_burst"
            ; buy_chance =
                Percent.of_percentage (Float.of_int (knob knobs "buy_pct"))
            ; marketable_chance =
                Percent.of_percentage
                  (Float.of_int (knob knobs "marketable_pct"))
            ; time_in_force_distribution =
                day_ioc_mix ~day_pct:(Float.of_int (knob knobs "day_pct"))
            ; mean_size = knob knobs "mean_size"
            ; price_jitter_cents = knob knobs "price_jitter_cents"
            }
        in
        Ok
          (Bot_spec.T
             { bot = (module Spammer)
             ; config = Spammer.Config.create ~symbols ~behavior
             ; participant
             ; symbols
             ; rng_seed
             ; tick_interval = tick_interval knobs
             ; is_marketdata_consumer = true
             }))
  }
;;

(* Defaults from the cancel-storm scenario (cancel_storm.ml). *)
let cancel_storm : Bot_menu.Entry.t =
  { kind = "cancel-storm"
  ; doc =
      "pathological churn: submits and immediately cancels in bursts, \
       hammering the cancel path"
  ; knobs =
      [ { name = "cycles_per_tick"
        ; doc = "submit->cancel cycles per tick"
        ; default = 50
        }
      ; { name = "size"; doc = "shares per order"; default = 50 }
      ; { name = "pct_marketable"
        ; doc = "percent priced to cross the spread"
        ; default = 20
        }
      ; { name = "price_offset_cents"
        ; doc = "cents past the fundamental to price each order"
        ; default = 100
        }
      ; tick_ms ~default:100
      ]
  ; make =
      (fun ~participant ~symbols ~knobs ~rng_seed ->
        Ok
          (Bot_spec.T
             { bot = (module Cancel_storm)
             ; config =
                 Cancel_storm.create_config
                   ~symbols
                   ~cycles_per_tick:(knob knobs "cycles_per_tick")
                   ~size:(knob knobs "size")
                   ~pct_marketable:(knob knobs "pct_marketable")
                   ~price_offset_cents:(knob knobs "price_offset_cents")
             ; participant
             ; symbols
             ; rng_seed
             ; tick_interval = tick_interval knobs
             ; (* Pure order/cancel churn never reads market data — same
                  opt-out the cancel-storm scenario uses. *)
               is_marketdata_consumer = false
             }))
  }
;;

let all =
  [ market_maker; noise_trader; momentum_trader; spammer; cancel_storm ]
;;
