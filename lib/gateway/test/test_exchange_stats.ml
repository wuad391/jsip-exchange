open! Core
open Jsip_gateway

(* Pure aggregation logic behind the dashboard panes. These pin the tricky
   bits: nearest-rank percentiles, the empty-window case, and the fact that
   [count] (throughput) and [max_us] (window max) are tracked outside the
   first-N sample cap that feeds the percentiles. *)

let%expect_test "Latency_summary.of_samples" =
  let show ?count ~max_us samples =
    let samples = Array.of_list samples in
    let count = Option.value count ~default:(Array.length samples) in
    print_s
      [%sexp
        (Exchange_stats.Latency_summary.of_samples samples ~count ~max_us
         : Exchange_stats.Latency_summary.t)]
  in
  (* Empty window: zeroed percentiles; count and max preserved. *)
  show ~max_us:0. [];
  [%expect {| ((p50_us 0) (p90_us 0) (p99_us 0) (max_us 0) (count 0)) |}];
  (* One sample: every percentile is that sample. *)
  show ~max_us:42. [ 42. ];
  [%expect {| ((p50_us 42) (p90_us 42) (p99_us 42) (max_us 42) (count 1)) |}];
  (* 1..100: median in the middle, tail near the top, max exact. *)
  show ~max_us:100. (List.range 1 101 |> List.map ~f:Float.of_int);
  [%expect
    {| ((p50_us 51) (p90_us 90) (p99_us 99) (max_us 100) (count 100)) |}];
  (* Cap hit: percentiles come from the first-N samples ([1;2;3]), but
     [count] and [max_us] are tracked outside the cap — so a late spike (max
     8000 over 9999 requests) still reports honestly. *)
  show ~count:9999 ~max_us:8000. [ 1.; 2.; 3. ];
  [%expect
    {| ((p50_us 2) (p90_us 3) (p99_us 3) (max_us 8000) (count 9999)) |}]
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
