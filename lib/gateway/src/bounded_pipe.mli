(** A bounded outbound pipe: an {!Async.Pipe} writer paired with a cap on how
    many events may sit unread and a policy for what to do once that cap is
    hit.

    The exchange fans one event stream out to many subscriber pipes — the
    public market-data feed and audit firehose in {!Dispatcher}, and each
    logged-in client's {!Session}. Every one of those writes used
    [Pipe.write_without_pushback_if_open], which never blocks and never
    drops: a subscriber that reads slower than the matching engine produces
    lets its buffer grow without bound, so a single slow (or malicious)
    client can exhaust the server's memory. This module is the shared
    throttle applied at each such write site. It generalizes the
    drop-when-full guard already used for the stats feed in {!Metrics}.

    {2 Why not just [Pipe.write]?}

    [Pipe.write] gives backpressure for free — its result stays undetermined
    until the reader drains, so [let%bind]-ing on it makes the producer wait.
    But the producer here is the single matching-engine loop writing the same
    event to every subscriber at once (a fan-out). Waiting on one slow reader
    would stall every other client. So rather than slow the shared producer,
    we bound each consumer's buffer independently and make the slow one bear
    the cost. *)

open! Core
open! Async

module Policy : sig
  (** What {!push} does when the buffer already holds [max_length] events.

      [Drop_oldest] is deliberately absent. The writer half of an
      {!Async.Pipe} can append and measure [Pipe.length] but cannot pop the
      front — dropping the oldest is the reader's privilege, and the reader
      has been handed to the client. "Keep the latest N" would need a second
      buffer the dispatcher owns and pumps; that is out of scope for this
      exercise. *)
  type t =
    | Drop_newest
    (** Discard the incoming event. The reader keeps what it has already
        buffered and misses the newest events until it drains. Cheapest;
        matches the stats-feed behavior in {!Metrics}. *)
    | Disconnect
    (** Close the pipe. The slow reader gets EOF and must reconnect; for
        market-data and audit subscribers the pipe's own [Pipe.closed]
        cleanup then unregisters it. Honest about the failure rather than
        silently lossy. *)
  [@@deriving sexp_of]
end

module Limit : sig
  (** A per-pipe cap together with the policy applied once it's reached. *)
  type t =
    { max_length : int
    (** Most events allowed to sit unread before [policy] kicks in. Must be
        [>= 1]. *)
    ; policy : Policy.t
    }
  [@@deriving sexp_of]
end

(** [push writer ~limit event] appends [event] to [writer] while fewer than
    [limit.max_length] events are buffered; otherwise it applies
    [limit.policy]. Never blocks, and is a no-op if [writer] is already
    closed.

    {[
      (* keep at most 2 unread; drop anything beyond that *)
      Bounded_pipe.push
        writer
        ~limit:{ max_length = 2; policy = Drop_newest }
        event
    ]} *)
val push : 'a Pipe.Writer.t -> limit:Limit.t -> 'a -> unit
