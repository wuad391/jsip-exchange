open! Core
open Jsip_types
open Jsip_pnl
open Jsip_test_harness

(* Build a fill from the two participants' perspectives. [aggressor] trades
   on [aggressor_side]; the [resting] participant takes the opposite side.
   Order ids are derived from [id] since P&L never inspects them. *)
let fill ~id ~aggressor ~aggressor_side ~resting ~price_cents ~size : Fill.t =
  { fill_id = id
  ; symbol = Harness.aapl
  ; price = Price.of_int_cents price_cents
  ; size = Size.of_int size
  ; aggressor_order_id = Order_id.of_string (Int.to_string id)
  ; aggressor_client_order_id = Client_order_id.of_int id
  ; aggressor_participant = aggressor
  ; aggressor_side
  ; resting_order_id = Order_id.of_string (Int.to_string (id + 1000))
  ; resting_client_order_id = Client_order_id.of_int id
  ; resting_participant = resting
  }
;;

let trade_report ~price_cents : Exchange_event.t =
  Trade_report
    { symbol = Harness.aapl
    ; price = Price.of_int_cents price_cents
    ; size = Size.of_int 1
    }
;;

let print_summary pnl participant =
  print_string (Pnl.Summary.to_string_hum (Pnl.summary pnl participant))
;;

(* Alice buys 100 @ $150, buys 100 more @ $152 (average $151), then sells 100
   @ $155 — realizing 100 * ($155 - $151) = $400 and leaving a 100-share
   long. A $154 trade print marks the remaining shares to 100 * ($154 - $151)
   = $300 unrealized. Bob is on the other side of every fill, so his P&L is
   the exact mirror. *)
let%expect_test "scale in, partial close, then mark" =
  let pnl =
    Pnl.empty
    |> Fn.flip
         Pnl.apply_fill
         (fill
            ~id:1
            ~aggressor:Harness.alice
            ~aggressor_side:Buy
            ~resting:Harness.bob
            ~price_cents:15000
            ~size:100)
    |> Fn.flip
         Pnl.apply_fill
         (fill
            ~id:2
            ~aggressor:Harness.alice
            ~aggressor_side:Buy
            ~resting:Harness.bob
            ~price_cents:15200
            ~size:100)
    |> Fn.flip
         Pnl.apply_fill
         (fill
            ~id:3
            ~aggressor:Harness.alice
            ~aggressor_side:Sell
            ~resting:Harness.bob
            ~price_cents:15500
            ~size:100)
    |> Fn.flip Pnl.apply_trade_report (trade_report ~price_cents:15400)
  in
  print_summary pnl Harness.alice;
  [%expect
    {|
    0: inv=100 avg=$151.00 ref=$154.00 realized=$400.00 unrealized=$300.00
    TOTAL: realized=$400.00 unrealized=$300.00 pnl=$700.00
    |}];
  print_summary pnl Harness.bob;
  [%expect
    {|
    0: inv=-100 avg=$151.00 ref=$154.00 realized=-$400.00 unrealized=-$300.00
    TOTAL: realized=-$400.00 unrealized=-$300.00 pnl=-$700.00
    |}]
;;

(* Charlie is long 50 @ $100, then sells 80 @ $110. That closes the 50-share
   long for 50 * ($110 - $100) = $500 realized and flips him to short 30 at a
   fresh $110 entry. A $112 print marks the short to -30 * ($112 - $110) =
   -$60 unrealized. *)
let%expect_test "position flip: long to short in one fill" =
  let pnl =
    Pnl.empty
    |> Fn.flip
         Pnl.apply_fill
         (fill
            ~id:1
            ~aggressor:Harness.charlie
            ~aggressor_side:Buy
            ~resting:Harness.market_maker
            ~price_cents:10000
            ~size:50)
    |> Fn.flip
         Pnl.apply_fill
         (fill
            ~id:2
            ~aggressor:Harness.charlie
            ~aggressor_side:Sell
            ~resting:Harness.market_maker
            ~price_cents:11000
            ~size:80)
    |> Fn.flip Pnl.apply_trade_report (trade_report ~price_cents:11200)
  in
  print_summary pnl Harness.charlie;
  [%expect
    {|
    0: inv=-30 avg=$110.00 ref=$112.00 realized=$500.00 unrealized=-$60.00
    TOTAL: realized=$500.00 unrealized=-$60.00 pnl=$440.00
    |}]
;;

(* Before any trade print arrives there is no reference price, so an open
   position has no mark. This pins down the missing-reference-price decision. *)
let%expect_test "open position with no reference price yet" =
  let pnl =
    Pnl.empty
    |> Fn.flip
         Pnl.apply_fill
         (fill
            ~id:1
            ~aggressor:Harness.alice
            ~aggressor_side:Buy
            ~resting:Harness.bob
            ~price_cents:10000
            ~size:10)
  in
  print_summary pnl Harness.alice;
  [%expect
    {|
    0: inv=10 avg=$100.00 ref=n/a realized=$0.00 unrealized=$0.00
    TOTAL: realized=$0.00 unrealized=$0.00 pnl=$0.00
    |}]
;;
