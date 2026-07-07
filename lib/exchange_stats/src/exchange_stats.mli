(** A once-per-second snapshot of the exchange's resource health.

    This is infrastructure telemetry — memory, latency, queue occupancy — and
    is deliberately {b not} an {!Jsip_types.Exchange_event.t}. The audit log
    records what the matching engine {e did} (accepts, fills, cancels); this
    record describes how the {e process} is holding up under load. They
    travel on separate RPCs ({!Rpc_protocol.exchange_stats_rpc} vs
    {!Rpc_protocol.audit_log_rpc}) so the two concerns stay unmixed.

    Produced by {!Metrics} on the server and rendered by the [app/dashboard]
    monitoring UI. The record is a value type with [bin_io] so it can cross
    the wire, and [sexp_of] so tests and logs can print it. *)

open! Core
open Jsip_types

(** Latency of one RPC class over a one-second window, as percentiles. Under
    load the interesting signal is the tail: [p50] can look healthy while
    [p99] and [max] blow up. [count] (throughput) and [max_us] (window
    maximum) are tracked outside the capped percentile buffer, so they stay
    exact even under a storm; the percentiles themselves can under-represent
    a late-window spike once the cap is hit. *)
module Latency_summary : sig
  type t =
    { p50_us : float
    ; p90_us : float
    ; p99_us : float
    ; max_us : float
    ; count : int
    }
  [@@deriving sexp, bin_io]

  val zero : t

  (** [of_samples samples ~count ~max_us] reads p50/p90/p99 off [samples]
      (microseconds), and tags the result with the true window [count] and
      [max_us]. The caller keeps only the first N samples per window to bound
      memory, so [count] and [max_us] are tracked outside that capped buffer. *)
  val of_samples : float array -> count:int -> max_us:float -> t
end

(** Aggregate occupancy of one category of subscriber pipes (audit,
    per-symbol market data, or per-session). [max_depth] is the smoking gun
    for a single slow consumer; [total_depth] and [num_pipes] give the shape
    of the category. *)
module Pipe_group : sig
  type t =
    { total_depth : int
    ; max_depth : int
    ; num_pipes : int
    }
  [@@deriving sexp, bin_io]

  val zero : t

  (** Aggregate a list of individual pipe queue-lengths. *)
  val of_lengths : int list -> t
end

(** Per-participant activity for one window. [orders_per_sec] counts all
    order requests (submits and cancels) that arrived from the participant
    this window — high values pick out a flooding bot. [resting_orders] is
    the live order count across all symbols right now. *)
module Participant_stats : sig
  type t =
    { participant : Participant.t
    ; orders_per_sec : int
    ; resting_orders : int
    }
  [@@deriving sexp, bin_io]
end

(** The subset of [Gc.stat ()] the dashboard plots. [live_words] is the
    headline (OCaml memory reachable now); [heap_words] is the total heap
    (live + free), so [heap_words - live_words] is retained/fragmented space;
    [top_heap_words] is the high-water mark. The collection counters are
    cumulative — the dashboard derives per-second GC rates from consecutive
    snapshots. *)
module Gc_snapshot : sig
  type t =
    { live_words : int
    ; heap_words : int
    ; top_heap_words : int
    ; minor_collections : int
    ; major_collections : int
    }
  [@@deriving sexp, bin_io]

  val of_stat : Core.Gc.Stat.t -> t
end

type t =
  { seq : int (** Monotonic snapshot index; the dashboard orders by it. *)
  ; gc : Gc_snapshot.t
  ; submit_latency : Latency_summary.t
  ; cancel_latency : Latency_summary.t
  ; audit_pipe : Pipe_group.t
  ; market_data_pipe : Pipe_group.t
  ; session_pipe : Pipe_group.t
  ; request_queue_depth : int
  (** Orders waiting in the matching engine's inbound queue at snapshot time
      — a direct read of the backlog. *)
  ; matching_loop_busy_us : float
  (** Wall-clock time of the single most expensive matching-loop iteration
      (match + dispatch) this window. Grows when individual operations get
      costlier, e.g. matching against a bloated book. *)
  ; per_participant : Participant_stats.t list
  }
[@@deriving sexp, bin_io]
