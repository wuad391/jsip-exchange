open! Core
open Jsip_gateway
open Jsip_types

(* [Metrics] folds order arrivals and per-request results into a one-second
   window. We drive it synchronously via [For_testing] (no 1 Hz timer), and
   avoid printing the nondeterministic GC fields. *)

let%expect_test "window folds counts / per-participant / busy, then resets" =
  let dispatcher =
    Dispatcher.create
      (Dispatcher.Config.uniform
         { max_length = 8; policy = Bounded_pipe.Policy.Drop_newest })
  in
  let engine = Jsip_order_book.Matching_engine.create 1 in
  let metrics =
    Metrics.create
      ~dispatcher
      ~matching_engine:engine
      ~num_symbols:1
      ~request_queue_length:(fun () -> 7)
  in
  let alice = Participant.of_string "alice" in
  let bob = Participant.of_string "bob" in
  (* alice sends two requests, bob one. *)
  List.iter [ alice; alice; bob ] ~f:(fun participant ->
    Metrics.record_arrival metrics ~participant);
  let us x = Time_ns.Span.of_us x in
  Metrics.record_processed
    metrics
    ~kind:`Submit
    ~latency:(us 10.)
    ~busy:(us 3.);
  Metrics.record_processed
    metrics
    ~kind:`Submit
    ~latency:(us 30.)
    ~busy:(us 8.);
  Metrics.record_processed
    metrics
    ~kind:`Cancel
    ~latency:(us 50.)
    ~busy:(us 2.);
  let print_window label (s : Exchange_stats.t) =
    print_s
      [%message
        label
          ~submit_count:(s.submit_latency.count : int)
          ~submit_max_us:(s.submit_latency.max_us : float)
          ~cancel_count:(s.cancel_latency.count : int)
          ~busy_us:(s.matching_loop_busy_us : float)
          ~queue_depth:(s.request_queue_depth : int)
          ~per_participant:
            (s.per_participant : Exchange_stats.Participant_stats.t list)]
  in
  (* [busy_us] is the max of the three (8); [queue_depth] is the live read. *)
  print_window "populated" (Metrics.For_testing.snapshot metrics);
  [%expect
    {|
    (populated (submit_count 2) (submit_max_us 30) (cancel_count 1) (busy_us 8)
     (queue_depth 7)
     (per_participant
      (((participant alice) (order_count 2) (resting_orders 0))
       ((participant bob) (order_count 1) (resting_orders 0)))))
    |}];
  (* After reset the window is empty; [queue_depth] still reads live (7). *)
  Metrics.For_testing.reset metrics;
  print_window "after-reset" (Metrics.For_testing.snapshot metrics);
  [%expect
    {|
    (after-reset (submit_count 0) (submit_max_us 0) (cancel_count 0) (busy_us 0)
     (queue_depth 7) (per_participant ()))
    |}]
;;
