(** A cancel storm: a pathological bot that submits an order and immediately
    cancels it, over and over, to hammer the exchange's cancel path. Each
    tick fires a burst of [cycles_per_tick] submit->cancel cycles, each under
    a fresh [client_order_id], so the exchange sees a relentless stream of
    submit / accept / cancel (and, for the marketable fraction, fill /
    cancel-reject) events. Keeps no resting book and reacts to no events.

    Implements {!Jsip_bot_runtime.Bot_runtime.Bot}; see
    [doc/exercises-part-3.md] Section 1. *)

open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime
module Context = Bot_runtime.Context

module Config : sig
  (** Storm knobs plus the per-cycle order-id counter. Build one with
      {!create_config}, which seeds the counter. *)
  type t =
    { symbols : Symbol.t list
    (** Symbols to storm; each cycle picks one at random. *)
    ; cycles_per_tick : int
    (** Submit->cancel cycles per tick — the intensity knob. *)
    ; size : int (** Shares per order. *)
    ; pct_marketable : int
    (** Percent (0-100) of orders priced to cross the spread (and maybe fill)
        rather than rest. *)
    ; price_offset_cents : int
    (** Cents past the fundamental to price each order; exceed a market
        maker's half-spread to make marketable orders cross. *)
    ; client_order_id_ref : int ref
    (** Mutable per-cycle order-id counter (ids can't repeat);
        {!create_config} seeds it to [0]. *)
    }
  [@@deriving sexp_of]
end

val name : string

(** No startup work: the storm keeps no resting ladder and begins churning on
    the first tick. *)
val on_start : Config.t -> Context.t -> unit Deferred.t

(** Fire a burst of [cycles_per_tick] submit->cancel cycles; the pressure per
    unit time is [cycles_per_tick / tick_interval]. *)
val on_tick : Config.t -> Context.t -> unit Deferred.t

(** Ignored. The cancel storm tracks no book and reacts to no fills, cancels,
    or rejects -- it only submits and cancels. *)
val on_event : Config.t -> Context.t -> Exchange_event.t -> unit Deferred.t

(** Build a config, seeding the order-id counter to [0]. See the field docs
    on {!Config.t} for what each knob controls. *)
val create_config
  :  symbols:Symbol.t list
  -> cycles_per_tick:int
  -> size:int
  -> pct_marketable:int
  -> price_offset_cents:int
  -> Config.t
