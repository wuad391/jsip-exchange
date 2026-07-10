open! Core

(* Nanosecond latencies span a huge dynamic range — a warm [submit] is tens of
   ns, a GC-pause tail is milliseconds — so power-of-two buckets give roughly
   constant *relative* resolution across that whole range while keeping the
   histogram a single small fixed array. Bucket [i] covers [2^i, 2^(i+1)) ns;
   64 buckets reach past [2^63] ns (~292 years), far beyond anything we could
   observe, so [record] never needs a bounds check. *)
let num_buckets = 64

type t =
  { buckets : int array
  ; mutable count : int
  ; mutable max_ns : int
  }

let create () =
  { buckets = Array.create ~len:num_buckets 0; count = 0; max_ns = 0 }
;;

(* Bucket index of [ns] is the position of its highest set bit, i.e.
   [floor (log2 ns)]. [Int.floor_log2] is defined for [n >= 1], which is why
   [record] clamps first. *)
let bucket_of_ns ns = Int.floor_log2 ns

let record t ~ns =
  let ns = Int.max 1 ns in
  let i = bucket_of_ns ns in
  t.buckets.(i) <- t.buckets.(i) + 1;
  t.count <- t.count + 1;
  if ns > t.max_ns then t.max_ns <- ns
;;

let count t = t.count
let max_ns t = t.max_ns

let percentile t ~fraction =
  if t.count = 0
  then 0.
  else (
    (* Nearest-rank: find the first bucket whose cumulative count reaches the
       target rank, and report that bucket's upper edge [2^(i+1)] as the
       estimate. We cap at the exact [max_ns] so a coarse top bucket can
       never report a latency larger than anything actually observed. *)
    let target =
      Int.max
        1
        (Float.to_int (Float.round_up (fraction *. Float.of_int t.count)))
    in
    let rec find i cumulative =
      if i >= num_buckets - 1
      then i
      else (
        let cumulative = cumulative + t.buckets.(i) in
        if cumulative >= target then i else find (i + 1) cumulative)
    in
    let i = find 0 0 in
    Float.min (Float.of_int t.max_ns) (2. ** Float.of_int (i + 1)))
;;

(* Render a float nanosecond count in whichever unit keeps it readable. Used
   only for the human-facing summary; the raw percentile stays in ns. *)
let format_ns ns =
  if Float.( < ) ns 1e3
  then sprintf "%.0fns" ns
  else if Float.( < ) ns 1e6
  then sprintf "%.2fus" (ns /. 1e3)
  else sprintf "%.2fms" (ns /. 1e6)
;;

let summary_line t ~label =
  let p fraction = format_ns (percentile t ~fraction) in
  sprintf
    "%-8s p50=%-9s p99=%-9s p99.9=%-9s max=%-9s (n=%d)"
    label
    (p 0.50)
    (p 0.99)
    (p 0.999)
    (format_ns (Float.of_int t.max_ns))
    t.count
;;

let%expect_test "empty histogram reads as zero" =
  let t = create () in
  printf
    "count=%d max=%d p50=%.1f\n"
    (count t)
    (max_ns t)
    (percentile t ~fraction:0.5);
  [%expect {| count=0 max=0 p50=0.0 |}]
;;

let%expect_test "a single repeated value lands in one bucket, capped at max" =
  let t = create () in
  for _ = 1 to 1000 do
    record t ~ns:100
  done;
  (* floor_log2 100 = 6, so bucket 6 ([64, 128)); every percentile caps at the
     exact max of 100ns rather than reporting the 128ns bucket edge. *)
  print_endline (summary_line t ~label:"submit");
  [%expect
    {| submit   p50=100ns     p99=100ns     p99.9=100ns     max=100ns     (n=1000) |}]
;;

let%expect_test "the tail separates from the body" =
  let t = create () in
  for _ = 1 to 990 do
    record t ~ns:100
  done;
  for _ = 1 to 10 do
    record t ~ns:1_000_000
  done;
  printf
    "p50=%s p99=%s p99.9=%s max=%s\n"
    (format_ns (percentile t ~fraction:0.5))
    (format_ns (percentile t ~fraction:0.99))
    (format_ns (percentile t ~fraction:0.999))
    (format_ns (Float.of_int (max_ns t)));
  (* p50/p99 sit in the fast body; only p99.9 reaches the 1ms samples. *)
  [%expect {| p50=128ns p99=128ns p99.9=1.00ms max=1.00ms |}]
;;
