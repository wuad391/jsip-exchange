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
    - [requote_threshold_cents]: hysteresis band. On a BBO move the maker
      re-seeds only once its target quote has drifted at least this far from
      where its ladder is resting, so it stops chasing the sub-tick flicker
      its own re-seeds create. Defaults to a few cents; pass [0] for the old
      "re-quote on any change" behavior.
    - [testing]: when [true], [on_tick] prints each symbol's internal book
      (default [false]). *)
val create_config
  :  ?testing:bool
  -> ?requote_threshold_cents:Int.t
  -> unit
  -> size_per_level:Int.t
  -> num_levels:Int.t
  -> inventory_skew_cents_per_share:Int.t
  -> symbols:Symbol_id.t List.t
  -> Config.t

(** Pure quoting helpers, exposed so tests can pin the spread floor and the
    re-quote hysteresis without standing up a server. *)
module For_testing : sig
  (** Half the current market spread -- what the maker quotes on each side --
      floored at {!min_half_spread_cents} so mirroring the market can never
      collapse to a zero or crossed quote. *)
  val half_spread_cents : Bbo.t -> int

  (** The positive floor {!half_spread_cents} clamps to. *)
  val min_half_spread_cents : int

  (** [requote_warranted ~threshold ~current ~target] is whether the [target]
      [(skewed_fair, half_spread)] has drifted at least [threshold] cents, in
      inner bid or ask, from the resting [current] quote. *)
  val requote_warranted
    :  threshold:int
    -> current:int * int
    -> target:int * int
    -> bool
end
