(** A periodic snapshot of the exchange's resource health.

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

(** Latency of one RPC class over one sample window, as percentiles. Under
    load the interesting signal is the tail: [p50] can look healthy while
    [p99] and [max] blow up. [count] (the raw number of requests handled this
    window; the dashboard divides it by [sample_period_sec] for throughput)
    and [max_us] (window maximum) are tracked outside the capped percentile
    buffer, so they stay exact even under a storm; the percentiles themselves
    can under-represent a late-window spike once the cap is hit. *)
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

(** Per-participant activity for one window. [order_count] is the raw number
    of order requests (submits and cancels) that arrived from the participant
    this window — the dashboard divides it by [sample_period_sec] for a
    per-second rate, and high values pick out a flooding bot.
    [resting_orders] is the live order count across all symbols right now.
    [pnl_cents] is the participant's cumulative net P&L. *)
module Participant_stats : sig
  type t =
    { participant : Participant.t
    ; order_count : int
    ; resting_orders : int
    ; pnl_cents : int
    (** Cumulative net P&L (realized + unrealized) across all symbols, in
        cents. Unlike [order_count] this is a running total as of this
        snapshot, not a per-window quantity. *)
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

(** Best bid and offer for one traded symbol at snapshot time — the actual
    market state, where every other field here is process health. A side is
    [None] when that side of the book is empty; {!Jsip_types.Bbo.spread}
    gives the ask-minus-bid spread when both are present. *)
module Top_of_book : sig
  type t =
    { symbol : Symbol_id.t
    ; bbo : Bbo.t
    }
  [@@deriving sexp, bin_io]
end

type t =
  { seq : int (** Monotonic snapshot index; the dashboard orders by it. *)
  ; sample_period_sec : float
  (** Wall-clock seconds this window accumulated over (the server's sample
      interval). The dashboard divides every per-window counter
      ([order_count], latency [count], GC-collection deltas) by it to derive
      per-second rates, so they stay correct at any sample rate. *)
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
  ; top_of_book : Top_of_book.t list
  (** Best bid/ask per traded symbol at snapshot time. *)
  }
[@@deriving sexp, bin_io]
