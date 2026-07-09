open! Core
open Jsip_exchange_stats
open Jsip_dashboard

(* Build a snapshot carrying only the fields these tests exercise; everything
   else is zeroed. *)
let snap ~seq ~minor ~major : Exchange_stats.t =
  { seq
  ; sample_period_sec = 1.0
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
  ; top_of_book = []
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

let%expect_test "rates divide by the sample period (per-second, not \
                 per-window)"
  =
  (* Two snapshots 0.5 s apart: 5 minor / 2 major collections in that window
     is 10 / 4 per second. *)
  let t =
    Dashboard_state.of_snapshots
      [ { (snap ~seq:1 ~minor:10 ~major:2) with sample_period_sec = 0.5 }
      ; { (snap ~seq:2 ~minor:15 ~major:4) with sample_period_sec = 0.5 }
      ]
  in
  print_s [%sexp (Dashboard_state.gc_rate t : Dashboard_state.Gc_rate.t)];
  [%expect {| ((minor_per_sec 10) (major_per_sec 4)) |}]
;;

(* The pane math the Bonsai layer relies on: words → megabytes, GC-rate
   delta, the current second's latency readouts, busiest-sender-first
   ranking, and per-category occupancy. [prev] carries only the GC counters
   the rate needs; [curr] is the fully-populated newest snapshot the readouts
   come from. *)
let%expect_test "display projects the window into render-ready pane data" =
  let curr : Exchange_stats.t =
    { seq = 2
    ; sample_period_sec = 1.0
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
          ; order_count = 3
          ; resting_orders = 1
          }
        ; { Exchange_stats.Participant_stats.participant =
              Jsip_types.Participant.of_string "zoe"
          ; order_count = 9
          ; resting_orders = 0
          }
        ]
    ; top_of_book = []
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

(* The top-of-book projection: prices become dollar strings paired with their
   sizes, the spread is present only when both sides are, and an empty side
   projects to [None]. Built off [snap] with a record-update so only
   [top_of_book] varies from the zeroed baseline. *)
let%expect_test "top-of-book projects bid/ask/spread per symbol" =
  let level cents size : Jsip_types.Level.t =
    { price = Jsip_types.Price.of_int_cents cents
    ; size = Jsip_types.Size.of_int size
    }
  in
  let book symbol_id (bbo : Jsip_types.Bbo.t) : Exchange_stats.Top_of_book.t =
    { symbol = Jsip_types.Symbol_id.of_int symbol_id; bbo }
  in
  let two_sided =
    book 0 { bid = Some (level 14990 10); ask = Some (level 15010 8) }
  in
  let bid_only = book 1 { bid = Some (level 25000 4); ask = None } in
  let curr =
    { (snap ~seq:1 ~minor:0 ~major:0) with
      top_of_book = [ two_sided; bid_only ]
    }
  in
  let d = Dashboard_state.display (Dashboard_state.of_snapshots [ curr ]) in
  print_s [%sexp (d.books : Dashboard_state.Display.book_row list)];
  [%expect
    {|
    (((symbol 0) (bid ($149.90)) (bid_size (10)) (ask ($150.10)) (ask_size (8))
      (spread ($0.20)))
     ((symbol 1) (bid ($250.00)) (bid_size (4)) (ask ()) (ask_size ())
      (spread ())))
    |}]
;;

(* The same projection, but with a directory: each book's [symbol] renders as
   its name rather than the raw id. *)
let%expect_test "top-of-book renders symbol names when given a directory" =
  let level cents size : Jsip_types.Level.t =
    { price = Jsip_types.Price.of_int_cents cents
    ; size = Jsip_types.Size.of_int size
    }
  in
  let book symbol_id (bbo : Jsip_types.Bbo.t) : Exchange_stats.Top_of_book.t =
    { symbol = Jsip_types.Symbol_id.of_int symbol_id; bbo }
  in
  let curr =
    { (snap ~seq:1 ~minor:0 ~major:0) with
      top_of_book =
        [ book 0 { bid = Some (level 14990 10); ask = None }
        ; book 1 { bid = None; ask = Some (level 25000 4) }
        ]
    }
  in
  let directory =
    Jsip_symbol_directory.Symbol_directory.of_names
      [ Jsip_types.Symbol.of_string "AAPL"
      ; Jsip_types.Symbol.of_string "TSLA"
      ]
  in
  let d =
    Dashboard_state.display
      ~directory
      (Dashboard_state.of_snapshots [ curr ])
  in
  print_s [%sexp (d.books : Dashboard_state.Display.book_row list)];
  [%expect
    {|
    (((symbol AAPL) (bid ($149.90)) (bid_size (10)) (ask ()) (ask_size ())
      (spread ()))
     ((symbol TSLA) (bid ()) (bid_size ()) (ask ($250.00)) (ask_size (4))
      (spread ())))
    |}]
;;
