open! Core
open Jsip_exchange_stats
open Jsip_dashboard

(* Build a snapshot carrying only the fields these tests exercise; everything
   else is zeroed. *)
let snap ~seq ~minor ~major : Exchange_stats.t =
  { seq
  ; gc =
      { Exchange_stats.Gc_snapshot.live_words = seq * 1000
      ; heap_words = 0
      ; top_heap_words = 0
      ; minor_collections = minor
      ; major_collections = major
      }
  ; submit_latency = Exchange_stats.Latency_summary.zero
  ; cancel_latency = Exchange_stats.Latency_summary.zero
  ; audit_pipe = Exchange_stats.Pipe_group.zero
  ; market_data_pipe = Exchange_stats.Pipe_group.zero
  ; session_pipe = Exchange_stats.Pipe_group.zero
  ; request_queue_depth = 0
  ; matching_loop_busy_us = 0.
  ; per_participant = []
  }
;;

let%expect_test "add bounds the window to max_window, keeping the newest" =
  let t =
    List.fold (List.range 1 66) ~init:Dashboard_state.empty ~f:(fun t seq ->
      Dashboard_state.add t (snap ~seq ~minor:0 ~major:0))
  in
  let seqs =
    List.map (Dashboard_state.snapshots t) ~f:(fun (s : Exchange_stats.t) ->
      s.seq)
  in
  print_s
    [%message
      ""
        ~count:(List.length seqs : int)
        ~first:(List.hd_exn seqs : int)
        ~last:(List.last_exn seqs : int)];
  [%expect {| ((count 60) (first 6) (last 65)) |}]
;;

let%expect_test "gc_rate is the per-second delta of the two latest snapshots"
  =
  let show t =
    print_s [%sexp (Dashboard_state.gc_rate t : Dashboard_state.Gc_rate.t)]
  in
  (* Fewer than two snapshots → zero. *)
  show Dashboard_state.empty;
  [%expect {| ((minor_per_sec 0) (major_per_sec 0)) |}];
  let t =
    Dashboard_state.add
      Dashboard_state.empty
      (snap ~seq:1 ~minor:10 ~major:2)
  in
  show t;
  [%expect {| ((minor_per_sec 0) (major_per_sec 0)) |}];
  let t = Dashboard_state.add t (snap ~seq:2 ~minor:15 ~major:3) in
  show t;
  [%expect {| ((minor_per_sec 5) (major_per_sec 1)) |}]
;;

(* The pane math the Bonsai layer relies on: words → megabytes, GC-rate
   delta, the current second's latency readouts, busiest-sender-first
   ranking, and per-category occupancy. [prev] carries only the GC counters
   the rate needs; [curr] is the fully-populated newest snapshot the readouts
   come from. *)
let%expect_test "display projects the window into render-ready pane data" =
  let curr : Exchange_stats.t =
    { seq = 2
    ; gc =
        { Exchange_stats.Gc_snapshot.live_words = 500_000
        ; heap_words = 1_000_000
        ; top_heap_words = 1_500_000
        ; minor_collections = 40
        ; major_collections = 5
        }
    ; submit_latency =
        { Exchange_stats.Latency_summary.p50_us = 10.
        ; p90_us = 90.
        ; p99_us = 120.
        ; max_us = 200.
        ; count = 300
        }
    ; cancel_latency = Exchange_stats.Latency_summary.zero
    ; audit_pipe = Exchange_stats.Pipe_group.zero
    ; market_data_pipe =
        { Exchange_stats.Pipe_group.total_depth = 12
        ; max_depth = 7
        ; num_pipes = 4
        }
    ; session_pipe = Exchange_stats.Pipe_group.zero
    ; request_queue_depth = 5
    ; matching_loop_busy_us = 42.
    ; per_participant =
        [ { Exchange_stats.Participant_stats.participant =
              Jsip_types.Participant.of_string "alice"
          ; orders_per_sec = 3
          ; resting_orders = 1
          }
        ; { Exchange_stats.Participant_stats.participant =
              Jsip_types.Participant.of_string "zoe"
          ; orders_per_sec = 9
          ; resting_orders = 0
          }
        ]
    }
  in
  let t =
    Dashboard_state.of_snapshots [ snap ~seq:1 ~minor:38 ~major:4; curr ]
  in
  let d = Dashboard_state.display t in
  print_s
    [%message
      ""
        ~live_mb:(d.live_mb : float)
        ~heap_mb:(d.heap_mb : float)
        ~peak_mb:(d.peak_mb : float)
        ~minor_per_sec:(d.gc_minor_per_sec : int)
        ~major_per_sec:(d.gc_major_per_sec : int)
        ~submit_p99_us:(d.submit.p99_us : float)
        ~submit_max_us:(d.submit.max_us : float)
        ~submit_per_sec:(d.submit.per_sec : int)
        ~participants:
          (d.participants : Dashboard_state.Display.participant_row list)
        ~market_data:
          (List.nth_exn d.occupancy 1
           : Dashboard_state.Display.occupancy_row)];
  [%expect
    {|
    ((live_mb 4) (heap_mb 8) (peak_mb 12) (minor_per_sec 2) (major_per_sec 1)
     (submit_p99_us 120) (submit_max_us 200) (submit_per_sec 300)
     (participants
      (((name zoe) (orders_per_sec 9) (resting_orders 0))
       ((name alice) (orders_per_sec 3) (resting_orders 1))))
     (market_data
      ((label "market data") (max_depth 7) (total_depth 12) (num_pipes 4)
       (max_depth_series (0 7)))))
    |}]
;;
