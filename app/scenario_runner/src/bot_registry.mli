(** The roster of live bots, keyed by participant name.

    Scenario-booted bots and console-spawned bots register alike, so the
    interactive console can [kill market-maker] on a bot the scenario brought
    up. Removal is how a caller takes ownership of a handle for teardown:
    {!remove} hands it back and the registry forgets it. *)

open! Core
open Jsip_types

type t

val create : unit -> t

(** Register a live bot. Errors (naming the offender) if a bot with the same
    participant is already registered. *)
val add : t -> Bot_handle.t -> unit Or_error.t

val find : t -> Participant.t -> Bot_handle.t option
val mem : t -> Participant.t -> bool

(** Hand back the handle (for teardown) and forget it. *)
val remove : t -> Participant.t -> Bot_handle.t option

(** Every live handle, sorted by participant for stable [list] output. *)
val all : t -> Bot_handle.t list
