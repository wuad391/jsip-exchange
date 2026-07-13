open! Core
open! Async
open Jsip_types

(** A pathological exchange participant used to stress-test the exchange. Its
    misbehavior is data-driven via {!Config.behavior}, so new pathologies are
    added as new variants. Two exist:

    - [Resource_exhaustion]: each tick fires a tight burst of orders, loading
      the request queue, the dispatcher fan-out, and the subscriber pipes. No
      trading strategy.
    - [Pump_and_dump]: a stateful two-phase manipulation on one symbol —
      marketable buys walk the price up ([Accumulate]), then it dumps its
      inventory into whoever chased the move ([Distribute]). It decides when
      to dump from observed prices, never the oracle. *)
module Config : sig
  (** Parameters for the [Resource_exhaustion] behavior. *)
  type resource_exhaustion_params =
    { orders_per_burst : int
    (** Orders fired per tick — the core stress lever. *)
    ; buy_chance : Percent.t (** Probability an order is a buy. *)
    ; marketable_chance : Percent.t
    (** Probability an order crosses the spread rather than resting. *)
    ; time_in_force_distribution : Time_in_force.t Bot_random.distribution
    (** Distribution the time-in-force is drawn from. *)
    ; mean_size : int (** Center of the per-order size distribution. *)
    ; price_jitter_cents : int
    (** Half-width of the price band, to spread the burst across levels. *)
    }

  (** Phases of the [Pump_and_dump] behavior. Advances
      [Accumulate -> Distribute -> Done] and never moves backward. *)
  type pump_and_dump_phase =
    | Accumulate
    | Distribute
    | Done
  [@@deriving sexp_of]

  (** Parameters and live state for the [Pump_and_dump] behavior. The first
      group are set-once knobs; the [mutable] fields are running state,
      exposed so tests can observe a run. Build one with
      {!pump_and_dump_params}. *)
  type pump_and_dump_params =
    { target_symbol : Symbol_id.t (** The single symbol to manipulate. *)
    ; pump_target_pct : Percent.t
    (** Flip to [Distribute] once the mid has risen this far above the
        anchor. *)
    ; clip_size : int (** Shares taken per tick — the push-rate lever. *)
    ; max_inventory : int (** Cap on the accumulated long. *)
    ; give_up_ticks : int
    (** Flip to [Distribute] anyway after this many ticks if the target isn't
        hit. *)
    ; aggression_offset_cents : int
    (** Cents past the opposite touch each clip is priced, so it crosses. *)
    ; entry_time_in_force : Time_in_force.t
    (** Time-in-force of every clip. *)
    ; mutable phase : pump_and_dump_phase (** Current phase. *)
    ; mutable position : int (** Signed shares held. *)
    ; mutable cost_cents : int (** Running notional paid while buying. *)
    ; mutable proceeds_cents : int
    (** Running notional taken while selling. *)
    ; mutable anchor_cents : int option
    (** Reference mid from the first two-sided BBO; [None] until seen. *)
    ; mutable ticks_in_phase : int (** Ticks spent in the current phase. *)
    }

  (** Build a params record with its mutable state seeded to a fresh run
      ([Accumulate], flat position, no anchor). *)
  val pump_and_dump_params
    :  target_symbol:Symbol_id.t
    -> pump_target_pct:Percent.t
    -> clip_size:int
    -> max_inventory:int
    -> give_up_ticks:int
    -> aggression_offset_cents:int
    -> entry_time_in_force:Time_in_force.t
    -> pump_and_dump_params

  (** How the spammer misbehaves. [Resource_exhaustion] is a strategy-free
      flood; [Pump_and_dump] is a stateful two-phase price manipulation. *)
  type behavior =
    | Resource_exhaustion of resource_exhaustion_params
    | Pump_and_dump of pump_and_dump_params

  type t

  val create : symbols:Symbol_id.t list -> behavior:behavior -> t
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
