(** A logged-in client's outbound event channel.

    One [Session.t] is created per logged-in connection. It holds the
    participant identity established at login plus a pipe that the
    [Dispatcher] writes to whenever a matching-engine event involving this
    participant is produced ([Order_accept], [Order_cancel], [Order_reject],
    [Fill] as aggressor or resting party).

    The reader half is handed back to the client via [session_feed_rpc]; the
    client drains it asynchronously. *)

open! Core
open! Async
open Jsip_types

(** Per-participant rate-limit capacities, passed to {!create}. Exposed so
    tests can construct sessions with tight, deterministic limits. *)
module Limits : sig
  type t =
    { submit_burst : int (** submit token-bucket size *)
    ; submit_refill_per_sec : float
    (** submit tokens replenished per second *)
    ; cancel_burst : int (** cancel token-bucket size *)
    ; cancel_refill_per_sec : float
    (** cancel tokens replenished per second *)
    }

  (** Production defaults, sized so honest traffic — including the seed
      market maker's bursty reseeds — is never throttled but pathological
      bots are. See the implementation for the calibration rationale. *)
  val default : t
end

type t

(** [create ?limits participant] creates a session whose per-participant
    submit and cancel rate limiters are configured by [limits] (default
    {!Limits.default}). *)
val create : ?limits:Limits.t -> Participant.t -> t

(** The participant this session belongs to. *)
val participant : t -> Participant.t

(** Hand the reader to the client (via [session_feed_rpc]). Returns the same
    reader every time it's called — there is only one outbound stream per
    session. *)
val reader : t -> Exchange_event.t Pipe.Reader.t

(** The submit-side rate limiter for this session. The gateway consults it
    before enqueuing an order submit; an over-budget submit is rejected with
    an [Order_reject] rather than reaching the matching engine. See
    {!Rate_limiter}. *)
val submit_limiter : t -> Rate_limiter.t

(** The cancel-side rate limiter for this session. Independent of
    {!submit_limiter}, so a burst of submits can never exhaust a client's
    ability to cancel. *)
val cancel_limiter : t -> Rate_limiter.t

(** Push an event onto the session's outbound pipe. *)
val push : t -> Exchange_event.t -> unit

(** Close the outbound pipe. Subsequent reads on [reader t] will drain any
    remaining buffered events and then EOF. *)
val close : t -> unit

(** [true] iff [close] has been called. *)
val is_closed : t -> bool

(** Number of events currently buffered in the session's outbound pipe — i.e.
    produced for this participant but not yet read by the client. A growing
    value flags a slow or stuck session consumer. *)
val queue_length : t -> int
