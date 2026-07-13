open! Core
open Jsip_types

module Latency_summary = struct
  type t =
    { p50_us : float
    ; p90_us : float
    ; p99_us : float
    ; max_us : float
    ; count : int
    }
  [@@deriving sexp, bin_io]

  let zero =
    { p50_us = 0.; p90_us = 0.; p99_us = 0.; max_us = 0.; count = 0 }
  ;;

  (* [fraction] in [0, 1]; [sorted] is ascending. We index by nearest rank
     rather than interpolating. The sampling cadence (now 2 Hz) doesn't
     change this: the approximation's coarseness depends on how many samples
     land in a window, and a shorter 0.5 s window simply holds fewer, so
     nearest-rank is marginally coarser but still plenty for a monitoring
     dashboard — these are indicative tails, not exact SLA percentiles. *)
  let percentile (sorted : float array) fraction =
    let n = Array.length sorted in
    if n = 0
    then 0.
    else (
      let idx =
        Float.iround_nearest_exn (fraction *. Float.of_int (n - 1))
      in
      sorted.(Int.clamp_exn idx ~min:0 ~max:(n - 1)))
  ;;

  (* [count] and [max_us] are passed separately from [samples] because the
     caller keeps only the first N samples of a window as the percentile
     input (to bound memory): [count] is the true number of requests handled
     and [max_us] the true window maximum, both tracked outside the capped
     buffer. Percentiles come from [samples] and can under-represent a
     late-window spike once the cap is hit — [max_us] never does. *)
  let of_samples samples ~count ~max_us =
    if Array.is_empty samples
    then { zero with count; max_us }
    else (
      let sorted = Array.copy samples in
      Array.sort sorted ~compare:Float.compare;
      { p50_us = percentile sorted 0.50
      ; p90_us = percentile sorted 0.90
      ; p99_us = percentile sorted 0.99
      ; max_us
      ; count
      })
  ;;
end

module Pipe_group = struct
  type t =
    { total_depth : int
    ; max_depth : int
    ; num_pipes : int
    }
  [@@deriving sexp, bin_io]

  let zero = { total_depth = 0; max_depth = 0; num_pipes = 0 }

  let of_lengths lengths =
    match lengths with
    | [] -> zero
    | _ :: _ ->
      { total_depth = List.fold lengths ~init:0 ~f:( + )
      ; max_depth = List.reduce_exn lengths ~f:Int.max
      ; num_pipes = List.length lengths
      }
  ;;
end

module Participant_stats = struct
  (* [order_count] is the raw number of orders this participant submitted
     during the sample window; the dashboard divides it by the snapshot's
     [sample_period_sec] to show a per-second rate, so the rate is honest
     whatever the sample interval is. [pnl_cents] is cumulative net P&L
     (realized + unrealized), in cents — a running total, not per-window. *)
  type t =
    { participant : Participant.t
    ; order_count : int
    ; resting_orders : int
    ; pnl_cents : int
    }
  [@@deriving sexp, bin_io]
end

module Gc_snapshot = struct
  type t =
    { live_words : int
    ; heap_words : int
    ; top_heap_words : int
    ; minor_collections : int
    ; major_collections : int
    }
  [@@deriving sexp, bin_io]

  let of_stat (s : Core.Gc.Stat.t) =
    { live_words = s.live_words
    ; heap_words = s.heap_words
    ; top_heap_words = s.top_heap_words
    ; minor_collections = s.minor_collections
    ; major_collections = s.major_collections
    }
  ;;
end

module Top_of_book = struct
  type t =
    { symbol : Symbol_id.t
    ; bbo : Bbo.t
    }
  [@@deriving sexp, bin_io]
end

type t =
  { seq : int
  ; (* Wall-clock seconds this window accumulated over (the server's sample
       interval). The dashboard divides window counters by it to derive
       per-second rates, so they stay correct at any sample rate. *)
    sample_period_sec : float
  ; gc : Gc_snapshot.t
  ; submit_latency : Latency_summary.t
  ; cancel_latency : Latency_summary.t
  ; audit_pipe : Pipe_group.t
  ; market_data_pipe : Pipe_group.t
  ; session_pipe : Pipe_group.t
  ; request_queue_depth : int
  ; matching_loop_busy_us : float
  ; per_participant : Participant_stats.t list
  ; top_of_book : Top_of_book.t list
  }
[@@deriving sexp, bin_io]
