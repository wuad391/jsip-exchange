(** The menu of bot kinds the interactive console can spawn.

    Only the entry TYPE lives here, next to {!Bot_spec}; the concrete menu of
    real bots is [Jsip_scenarios.Default_bot_menu] and gets injected into the
    console by the binary — that keeps this library from depending on the bot
    libraries (which depend back on it for {!Bot_spec}).

    Every knob is an [int]: sizes, cents, counts, milliseconds — and
    fractional parameters surface as percents (e.g. [tick_pct=50] for a 0.5
    tick chance), so the console's [key=value] grammar stays trivial. *)

open! Core
open Jsip_types

module Knob : sig
  (** One integer tuning knob of a spawnable kind ([key=value] on the spawn
      line). *)
  type t =
    { name : string
    ; doc : string (** One-liner, units included; shown by [kinds]. *)
    ; default : int
    }
end

module Entry : sig
  type t =
    { kind : string (** Console token, e.g. ["noise"]. *)
    ; doc : string (** One-liner shown by [kinds]. *)
    ; knobs : Knob.t list
    ; make :
        participant:Participant.t
        -> symbols:Symbol_id.t list
        -> knobs:int String.Map.t
        -> rng_seed:int
        -> Bot_spec.t Or_error.t
    (** Build a spec ready for [Runner.start_bot]. [symbols] is non-empty
        (the console defaults it to the whole directory); [knobs] is fully
        resolved — every declared knob present, via {!resolve_knobs}.
        Kind-specific validation (e.g. momentum trades exactly one symbol)
        errors here. *)
    }

  (** Find an entry by console token, case-insensitively; the error lists the
      menu. *)
  val find : t list -> kind:string -> t Or_error.t

  (** Overlay user [overrides] on [entry]'s knob defaults. Unknown keys
      error, listing the entry's knobs. *)
  val resolve_knobs
    :  t
    -> overrides:(string * int) list
    -> int String.Map.t Or_error.t
end
