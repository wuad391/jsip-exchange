open! Core
open! Async
open Jsip_types

(** A momentum (trend-following) trader: it bets a price that has been moving
    recently will keep moving that way. It keeps a sliding window of recent
    public [Trade_report] prices for one symbol; each tick it computes
    [signal = newest - oldest] and, once the window is full and the signal
    reaches [threshold_cents], submits a marketable entry in the signal's
    direction, sized one share per cent of signal (capped by [max_order_size]
    and by [max_position]). See [doc/exercises-part-2.md] Exercise 6.

    Signals come from [Trade_report] (broadcast to all market-data
    subscribers), not [Fill] (delivered only for this bot), so its
    {!Jsip_scenario_runner.Bot_spec.t} must set
    [is_marketdata_consumer = true]. *)
module Config : sig
  type t [@@deriving sexp_of]

  (** Build a config with fresh strategy state, so two bots never share it.
      Raises if a numeric parameter is out of range.

      - [symbol]: the symbol watched and traded.
      - [window_capacity]: recent trade prices the signal spans (>= 2);
        bigger smooths the signal but reacts slower.
      - [threshold_cents]: minimum absolute signal before trading (positive).
      - [max_order_size]: cap in shares on any single order (positive).
      - [max_position]: cap in shares on the absolute filled position
        (positive).
      - [cooldown_ticks]: ticks skipped after a submission (default [0]).
      - [entry_time_in_force]: time-in-force of every entry (default [Ioc]).
      - [aggression_offset_cents]: cents past the newest trade to price
        entries, so they cross (default [1]). *)
  val create_exn
    :  ?cooldown_ticks:int
    -> ?entry_time_in_force:Time_in_force.t
    -> ?aggression_offset_cents:int
    -> symbol:Symbol.t
    -> window_capacity:int
    -> threshold_cents:int
    -> max_order_size:int
    -> max_position:int
    -> unit
    -> t
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
