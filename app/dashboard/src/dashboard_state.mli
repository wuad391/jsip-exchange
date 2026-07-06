(** Pure rolling-window state for the monitoring dashboard.

    Folds the per-second {!Jsip_gateway.Exchange_stats.t} snapshots the
    exchange streams into a bounded window (the last {!max_window} seconds)
    that the Bonsai layer renders. Holds no Async and no Bonsai state, so it
    is fully testable as plain data — the analog of [app/monitor]'s
    [Controller]. *)

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
