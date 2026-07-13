(** A token-bucket rate limiter.

    Each accepted attempt costs one token; the bucket refills at a steady
    [refill_per_sec] up to a maximum of [burst] tokens. A client that has
    been quiet banks up to [burst] tokens and may then spend them in a single
    burst — this tolerates the seed market maker's cancel-all/reseed bursts
    while still capping the sustained rate a spammer can achieve.

    The gateway hangs one limiter per action (submit, cancel) on each
    {!Session.t}, so limits are per-participant and independent across
    actions: a submit flood cannot exhaust a client's ability to cancel.

    Time is supplied by the caller (see {!try_consume}) rather than read from
    the clock internally, so behavior is deterministic under test — the same
    convention {!Metrics.record_processed} follows for latency spans.

    {[
      let bucket = Rate_limiter.create ~burst:20 ~refill_per_sec:30. in
      Rate_limiter.try_consume bucket ~now:(Time_ns.now ())
      (* = true *)
    ]} *)

open! Core

type t

(** [create ~burst ~refill_per_sec] is a full bucket holding [burst] tokens
    that refills at [refill_per_sec] tokens per second, capped at [burst]. *)
val create : burst:int -> refill_per_sec:float -> t

(** [try_consume t ~now] refills the bucket for the time elapsed since the
    previous call, then, if at least one token is available, consumes one and
    returns [true] (accept). Otherwise it consumes nothing and returns
    [false] (reject). [now] should be monotonically non-decreasing across
    calls. *)
val try_consume : t -> now:Time_ns.t -> bool
