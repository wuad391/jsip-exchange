(** A deliberately pathological market-data subscriber: it takes [read_delay]
    to handle every event. Because the runner won't pull the next event until
    [on_event] resolves, a slow [on_event] stalls the drain, and events pile
    up without bound in the exchange-side pipe (written with
    [Pipe.write_without_pushback_if_open]) — the memory-growth pathology this
    bot demonstrates. It never trades; it only subscribes and lags. *)

open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime

module Config : sig
  type t

  (** [create ~read_delay] builds a consumer that waits [read_delay] before
      finishing with each event. Larger delays make it fall behind faster. *)
  val create : read_delay:Time_ns.Span.t -> t
end

val name : string
val on_start : Config.t -> Bot_runtime.Context.t -> unit Deferred.t
val on_tick : Config.t -> Bot_runtime.Context.t -> unit Deferred.t

val on_event
  :  Config.t
  -> Bot_runtime.Context.t
  -> Exchange_event.t
  -> unit Deferred.t
