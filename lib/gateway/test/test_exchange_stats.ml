open! Core
open Jsip_gateway

(* Pure aggregation logic behind the dashboard panes. These pin the tricky
   bits: nearest-rank percentiles, the empty-window case, and the fact that
   [count] (true throughput) is tracked independently of the reservoir-capped
   sample buffer. *)

let%expect_test "Latency_summary.of_samples" =
  let show ?count samples =
    let samples = Array.of_list samples in
    let count = Option.value count ~default:(Array.length samples) in
    print_s
      [%sexp
        (Exchange_stats.Latency_summary.of_samples samples ~count
         : Exchange_stats.Latency_summary.t)]
  in
  (* Empty window: zeroed percentiles, but the count is preserved. *)
  show [];
  [%expect {| ((p50_us 0) (p90_us 0) (p99_us 0) (max_us 0) (count 0)) |}];
  (* One sample: every percentile is that sample. *)
  show [ 42. ];
  [%expect {| ((p50_us 42) (p90_us 42) (p99_us 42) (max_us 42) (count 1)) |}];
  (* 1..100: median in the middle, tail near the top, max exact. *)
  show (List.range 1 101 |> List.map ~f:Float.of_int);
  [%expect
    {| ((p50_us 51) (p90_us 90) (p99_us 99) (max_us 100) (count 100)) |}];
  (* Reservoir cap: [count] (true throughput) exceeds the samples retained. *)
  show ~count:9999 [ 1.; 2.; 3. ];
  [%expect {| ((p50_us 2) (p90_us 3) (p99_us 3) (max_us 3) (count 9999)) |}]
;;

let%expect_test "Pipe_group.of_lengths" =
  let show lengths =
    print_s
      [%sexp
        (Exchange_stats.Pipe_group.of_lengths lengths
         : Exchange_stats.Pipe_group.t)]
  in
  (* No subscribers. *)
  show [];
  [%expect {| ((total_depth 0) (max_depth 0) (num_pipes 0)) |}];
  (* Several idle pipes: counted, but nothing backed up. *)
  show [ 0; 0; 0 ];
  [%expect {| ((total_depth 0) (max_depth 0) (num_pipes 3)) |}];
  (* One slow consumer (depth 7) stands out in [max_depth]. *)
  show [ 2; 7; 1 ];
  [%expect {| ((total_depth 10) (max_depth 7) (num_pipes 3)) |}]
;;
