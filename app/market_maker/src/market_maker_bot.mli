open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime
module Context = Bot_runtime.Context

(** A dynamic, multi-symbol market maker driven entirely by events, not
    ticks: it seeds a skewed bid/ask ladder around each symbol's fundamental
    on start, and on every fill re-computes its inventory, cancels both books
    for that symbol, and re-seeds. Per-symbol inventory, resting orders, and
    cached BBO all live in the config. *)
module Config : sig
  type t
end

val name : string
val on_start : Config.t -> Context.t -> unit Deferred.t

(** Does no tick-driven quoting; only prints the internal books when the
    config's [testing] flag is set. *)
val on_tick : Config.t -> Context.t -> unit Deferred.t

val on_event : Config.t -> Context.t -> Exchange_event.t -> unit Deferred.t

(** Build a market-maker config.

    - [symbols]: symbols to quote.
    - [size_per_level]: shares per quote.
    - [num_levels]: quotes posted per side, one cent further out each.
    - [inventory_skew_cents_per_share]: cents the ladder shifts per share of
      inventory, to lean against the position.
    - [testing]: when [true], [on_tick] prints each symbol's internal book
      (default [false]). *)
val create_config
  :  ?testing:bool
  -> unit
  -> size_per_level:Int.t
  -> num_levels:Int.t
  -> inventory_skew_cents_per_share:Int.t
  -> symbols:Symbol_id.t List.t
  -> Config.t
