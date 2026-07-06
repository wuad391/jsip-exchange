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
