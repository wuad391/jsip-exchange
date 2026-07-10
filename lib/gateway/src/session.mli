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

type t

(** [create participant ~limit] makes a session whose outbound pipe is
    bounded by [limit]: once [limit.max_length] events are buffered, [push]
    applies [limit.policy] (see {!Bounded_pipe}) rather than growing without
    bound. *)
val create : Participant.t -> limit:Bounded_pipe.Limit.t -> t

(** The participant this session belongs to. *)
val participant : t -> Participant.t

(** Hand the reader to the client (via [session_feed_rpc]). Returns the same
    reader every time it's called — there is only one outbound stream per
    session. *)
val reader : t -> Exchange_event.t Pipe.Reader.t

(** Push an event onto the session's outbound pipe, honoring the [limit] the
    session was created with. At capacity the configured policy decides
    whether the event is dropped or the session is disconnected; it never
    blocks the caller (the shared matching-engine loop). *)
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
