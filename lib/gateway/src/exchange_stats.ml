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
     rather than interpolating — plenty precise for a 1 Hz dashboard. *)
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

  (* [count] is passed separately from [Array.length samples] because the
     caller reservoir-caps its sample buffer: [count] is the true number of
     requests handled this window, while [samples] may be a bounded subset. *)
  let of_samples samples ~count =
    if Array.is_empty samples
    then { zero with count }
    else (
      let sorted = Array.copy samples in
      Array.sort sorted ~compare:Float.compare;
      { p50_us = percentile sorted 0.50
      ; p90_us = percentile sorted 0.90
      ; p99_us = percentile sorted 0.99
      ; max_us = sorted.(Array.length sorted - 1)
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
  type t =
    { participant : Participant.t
    ; orders_per_sec : int
    ; resting_orders : int
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

type t =
  { seq : int
  ; gc : Gc_snapshot.t
  ; submit_latency : Latency_summary.t
  ; cancel_latency : Latency_summary.t
  ; audit_pipe : Pipe_group.t
  ; market_data_pipe : Pipe_group.t
  ; session_pipe : Pipe_group.t
  ; request_queue_depth : int
  ; matching_loop_busy_us : float
  ; per_participant : Participant_stats.t list
  }
[@@deriving sexp, bin_io]
