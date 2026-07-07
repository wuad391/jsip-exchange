(** Pure rolling-window state for the monitoring dashboard.

    Folds the per-second {!Jsip_exchange_stats.Exchange_stats.t} snapshots
    the exchange streams into a bounded window (the last {!max_window}
    seconds) and projects it into render-ready {!Display} data. Holds no
    Async and no Bonsai state, so it is fully testable as plain data — the
    analog of [app/monitor]'s [Controller]. *)

open! Core
open Jsip_exchange_stats

(** Length of the retained window, in snapshots (one per second). *)
val max_window : int

(** Per-second GC cycle rates, differenced from consecutive snapshots'
    cumulative collection counters. Rising minor/sec is what ties an
    allocation-heavy bot to the latency tail. *)
module Gc_rate : sig
  type t =
    { minor_per_sec : int
    ; major_per_sec : int
    }
  [@@deriving sexp, equal]
end

type t

val empty : t

(** Fold a new snapshot in, dropping the oldest once the window is full. *)
val add : t -> Exchange_stats.t -> t

(** The retained snapshots, oldest first — ready to map into chart series. *)
val snapshots : t -> Exchange_stats.t list

(** The most recent snapshot, or [None] before any arrive. *)
val latest : t -> Exchange_stats.t option

(** GC rates between the two most recent snapshots; all-zero with fewer than
    two snapshots. *)
val gc_rate : t -> Gc_rate.t

(** Rebuild a window from snapshots oldest-first — the inverse of
    {!snapshots}. The browser uses this to reconstruct render state from a
    polled window before calling {!display}. *)
val of_snapshots : Exchange_stats.t list -> t

(** The render-ready projection the Bonsai layer draws: chart series (oldest
    first) and current-second readouts for every pane. Decoupled from any
    Bonsai/Vdom type so the pane math — words to megabytes, percentile
    series, busiest-sender ranking, pipe occupancy — is testable as plain
    data, the analog of [Controller.Display]. *)
module Display : sig
  (** One RPC class's latency: a line per percentile over the window plus the
      current second's readouts, with [per_sec] the throughput that second. *)
  type latency =
    { p50_series : float list
    ; p90_series : float list
    ; p99_series : float list
    ; max_series : float list
    ; p50_us : float
    ; p90_us : float
    ; p99_us : float
    ; max_us : float
    ; per_sec : int
    }
  [@@deriving sexp_of, equal]

  (** A row of the per-participant table, one participant's current-second
      send rate and resting-order count. *)
  type participant_row =
    { name : string
    ; orders_per_sec : int
    ; resting_orders : int
    }
  [@@deriving sexp_of, equal]

  (** One pipe category's occupancy: current depths plus a line of the max
      single-pipe depth over the window (the smoking gun for a slow
      consumer). *)
  type occupancy_row =
    { label : string
    ; max_depth : int
    ; total_depth : int
    ; num_pipes : int
    ; max_depth_series : float list
    }
  [@@deriving sexp_of, equal]

  type t =
    { seq : int
    ; live_mb_series : float list
    ; heap_mb_series : float list
    ; live_mb : float
    ; heap_mb : float
    ; peak_mb : float
    ; gc_minor_per_sec : int
    ; gc_major_per_sec : int
    ; submit : latency
    ; cancel : latency
    ; participants : participant_row list
    ; occupancy : occupancy_row list
    ; loop_busy_series : float list
    ; loop_busy_us : float
    }
  [@@deriving sexp_of, equal]
end

(** Project the current window into render-ready pane data. *)
val display : t -> Display.t
