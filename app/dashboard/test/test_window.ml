open! Core
open Jsip_exchange_stats
open Jsip_dashboard

(* [Window] is the diffable poll response: a diff carries only the snapshots
   newer than the client already holds, and [update] must reconstruct the
   server's window exactly. These pin that round-trip — both while the window
   is still filling and once it is full and slides, dropping the oldest. *)

let snap seq : Exchange_stats.t =
  { seq
  ; gc =
      { Exchange_stats.Gc_snapshot.live_words = seq
      ; heap_words = 0
      ; top_heap_words = 0
      ; minor_collections = 0
      ; major_collections = 0
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

let window seqs = List.map seqs ~f:snap
let seqs w = List.map w ~f:(fun (s : Exchange_stats.t) -> s.seq)

let%expect_test "still filling: diff is the new snapshots, update appends \
                 them"
  =
  let from = window [ 3; 4; 5 ] in
  let to_ = window [ 3; 4; 5; 6; 7 ] in
  let diff = Window.diffs ~from ~to_ in
  print_s [%sexp (seqs diff : int list)];
  [%expect {| (6 7) |}];
  print_s [%sexp (seqs (Window.update from diff) : int list)];
  [%expect {| (3 4 5 6 7) |}]
;;

let%expect_test "full window slides: update drops the oldest to match to_" =
  (* A full 60-window that advanced by two seconds: seq 1,2 age out, 61,62
     arrive. The diff still carries only 61,62; [update] re-caps to 60. *)
  let from = window (List.range 1 61) in
  let to_ = window (List.range 3 63) in
  let diff = Window.diffs ~from ~to_ in
  print_s [%message "" ~appended:(seqs diff : int list)];
  [%expect {| (appended (61 62)) |}];
  let reconstructed = seqs (Window.update from diff) in
  print_s
    [%message
      ""
        ~count:(List.length reconstructed : int)
        ~first:(List.hd_exn reconstructed : int)
        ~last:(List.last_exn reconstructed : int)];
  [%expect {| ((count 60) (first 3) (last 62)) |}]
;;
