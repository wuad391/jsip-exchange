open! Core
open Jsip_gateway

(* [Rate_limiter] takes [~now] explicitly, so these tests advance time by
   hand instead of sleeping — the behaviour is fully deterministic. *)
let t0 = Time_ns.of_int_ns_since_epoch 1_000_000_000
let after ~sec = Time_ns.add t0 (Time_ns.Span.of_sec sec)

let%expect_test "a full burst is accepted, then further attempts are \
                 rejected"
  =
  let bucket = Rate_limiter.create ~burst:3 ~refill_per_sec:0. in
  List.iter [ 1; 2; 3; 4; 5 ] ~f:(fun i ->
    let ok = Rate_limiter.try_consume bucket ~now:t0 in
    print_endline [%string "attempt %{i#Int}: %{ok#Bool}"]);
  [%expect
    {|
    attempt 1: true
    attempt 2: true
    attempt 3: true
    attempt 4: false
    attempt 5: false
    |}]
;;

let%expect_test "tokens refill over time" =
  let bucket = Rate_limiter.create ~burst:2 ~refill_per_sec:10. in
  (* Drain the bucket at t0. *)
  let d1 = Rate_limiter.try_consume bucket ~now:t0 in
  let d2 = Rate_limiter.try_consume bucket ~now:t0 in
  let d3 = Rate_limiter.try_consume bucket ~now:t0 in
  print_endline [%string "drain at t0: %{d1#Bool} %{d2#Bool} %{d3#Bool}"];
  [%expect {| drain at t0: true true false |}];
  (* At 10 tokens/sec, 0.1s buys back exactly one token. *)
  let later = after ~sec:0.1 in
  let r1 = Rate_limiter.try_consume bucket ~now:later in
  let r2 = Rate_limiter.try_consume bucket ~now:later in
  print_endline [%string "after 0.1s: %{r1#Bool} %{r2#Bool}"];
  [%expect {| after 0.1s: true false |}]
;;

let%expect_test "an idle bucket never banks more than [burst]" =
  let bucket = Rate_limiter.create ~burst:2 ~refill_per_sec:10. in
  (* 10s idle would "accrue" 100 tokens, but the cap is [burst] = 2. *)
  let later = after ~sec:10. in
  List.iter [ 1; 2; 3 ] ~f:(fun i ->
    let ok = Rate_limiter.try_consume bucket ~now:later in
    print_endline [%string "attempt %{i#Int}: %{ok#Bool}"]);
  [%expect
    {|
    attempt 1: true
    attempt 2: true
    attempt 3: false
    |}]
;;

let%expect_test "two limiters are independent" =
  let a = Rate_limiter.create ~burst:1 ~refill_per_sec:0. in
  let b = Rate_limiter.create ~burst:1 ~refill_per_sec:0. in
  (* Exhausting [a] leaves [b] untouched. *)
  let a1 = Rate_limiter.try_consume a ~now:t0 in
  let a2 = Rate_limiter.try_consume a ~now:t0 in
  let b1 = Rate_limiter.try_consume b ~now:t0 in
  print_endline [%string "a: %{a1#Bool} %{a2#Bool} | b: %{b1#Bool}"];
  [%expect {| a: true false | b: true |}]
;;

let%expect_test "a partial refill below one token does not admit an attempt" =
  let bucket = Rate_limiter.create ~burst:1 ~refill_per_sec:1. in
  (* Spend the only token at t0. *)
  let first = Rate_limiter.try_consume bucket ~now:t0 in
  (* 0.5s later only half a token has accrued — not enough. *)
  let half = Rate_limiter.try_consume bucket ~now:(after ~sec:0.5) in
  (* A full second after t0, one whole token is available again. *)
  let full = Rate_limiter.try_consume bucket ~now:(after ~sec:1.0) in
  print_endline
    [%string "t0:%{first#Bool} +0.5s:%{half#Bool} +1.0s:%{full#Bool}"];
  [%expect {| t0:true +0.5s:false +1.0s:true |}]
;;

let%expect_test "a zero-burst bucket rejects everything" =
  let bucket = Rate_limiter.create ~burst:0 ~refill_per_sec:100. in
  (* Tokens are clamped to [burst] = 0, so no elapsed time ever admits one. *)
  let now0 = Rate_limiter.try_consume bucket ~now:t0 in
  let later = Rate_limiter.try_consume bucket ~now:(after ~sec:5.) in
  print_endline [%string "t0:%{now0#Bool} +5s:%{later#Bool}"];
  [%expect {| t0:false +5s:false |}]
;;

let%expect_test "a longer idle refills multiple tokens at once" =
  let bucket = Rate_limiter.create ~burst:5 ~refill_per_sec:10. in
  (* Drain all five tokens at t0. *)
  List.iter [ 1; 2; 3; 4; 5 ] ~f:(fun _ ->
    ignore (Rate_limiter.try_consume bucket ~now:t0 : bool));
  (* 0.25s at 10 tokens/sec accrues 2.5 tokens: exactly two more succeed. *)
  let later = after ~sec:0.25 in
  List.iter [ 1; 2; 3 ] ~f:(fun i ->
    let ok = Rate_limiter.try_consume bucket ~now:later in
    print_endline [%string "attempt %{i#Int}: %{ok#Bool}"]);
  [%expect
    {|
    attempt 1: true
    attempt 2: true
    attempt 3: false
    |}]
;;
