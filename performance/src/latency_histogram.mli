(** A fixed-bucket latency histogram for estimating percentiles over millions
    of samples without allocating per sample.

    The replay driver ({!Replay}) times every [submit]/[cancel] call and
    needs p50/p99/p99.9/max out the other end. Buffering millions of raw
    samples in a growing array would both allocate heavily and distort the
    very measurement we're taking — the central concern of Part 4. Instead
    each latency is dropped into a power-of-two nanosecond bucket (bucket [i]
    covers [\[2^i, 2^(i+1))] ns), which is [O(1)] and allocation-free.

    Percentiles are therefore *approximate*: a reported percentile is the
    upper edge of the bucket the true value falls in (capped at the exact
    maximum, so it never overstates). [max_ns] is tracked exactly. For
    latency work, where the tail spans orders of magnitude, this constant
    relative resolution is exactly what you want. *)

open! Core

type t

(** A fresh, empty histogram. *)
val create : unit -> t

(** Record one latency. [ns] is clamped to [>= 1] before bucketing, so a
    zero-or-negative span (which [Time_ns.diff] can yield for a sub-tick
    call) lands in bucket 0 rather than raising. *)
val record : t -> ns:int -> unit

(** Total number of samples recorded. *)
val count : t -> int

(** The largest [ns] ever recorded — exact, not bucketed — or [0] if empty. *)
val max_ns : t -> int

(** Estimate the [fraction] quantile in nanoseconds (e.g. [~fraction:0.999]
    for p99.9), as the upper edge of the containing bucket, capped at
    {!max_ns}. Returns [0.] for an empty histogram. [fraction] should be in
    [[0, 1]]. *)
val percentile : t -> fraction:float -> float

(** A one-line [p50=.. p99=.. p99.9=.. max=.. (n=..)] summary with
    human-friendly units (ns/us/ms), [label] as the row prefix — e.g.
    [summary_line submits ~label:"submit"] for {!Replay}'s report. *)
val summary_line : t -> label:string -> string
