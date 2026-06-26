(** Tests for the market maker, using a real exchange server. *)

open! Core
open! Async
open Jsip_test_harness
open Jsip_market_maker
open E2e_helpers

let default_config : Market_maker.Config.t =
  { participant = Harness.market_maker
  ; symbol = Harness.aapl
  ; fair_value_cents = 15000
  ; half_spread_cents = 10
  ; size_per_level = 100
  ; num_levels = 3
  }
;;

(* ---------------------------------------------------------------- *)
(* Run tests *)
(* ---------------------------------------------------------------- *)
let%expect_test "Test basic book keeping abilities 2a" =
  with_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
    let%bind mm = connect_as ~port Harness.market_maker in
    let%bind _ =
      Clock.with_timeout
        (Core_private.of_float 100.0)
        (* (100.0 : Core_private.Span_float.t) *)
        (Market_maker.run default_config (connection mm))
    in
    Market_maker.print_books ();
    [%expect
      {|
      Validated client_order_id 2 by returning false
      Validated client_order_id 3 by returning false
      Validated client_order_id 4 by returning false
      Validated client_order_id 5 by returning false
      Validated client_order_id 6 by returning false
      Validated client_order_id 7 by returning false
      [for MarketMaker] ACCEPTED id=1 AAPL BUY 100@$149.90 DAY
      [for MarketMaker] ACCEPTED id=2 AAPL SELL 100@$150.10 DAY
      [for MarketMaker] ACCEPTED id=3 AAPL BUY 100@$149.89 DAY
      [for MarketMaker] ACCEPTED id=4 AAPL SELL 100@$150.11 DAY
      [for MarketMaker] ACCEPTED id=5 AAPL BUY 100@$149.88 DAY
      [for MarketMaker] ACCEPTED id=6 AAPL SELL 100@$150.12 DAY
      |}];
    return ())
;;

(* ---------------------------------------------------------------- *)
(* Seeding tests *)
(* ---------------------------------------------------------------- *)
let%expect_test "seed_book: places symmetric bids and asks around fair value"
  =
  with_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
    let%bind mm = connect_as ~port Harness.market_maker in
    let%bind () = Market_maker.seed_book default_config (connection mm) in
    [%expect
      {|
      Validated client_order_id 2 by returning false
      Validated client_order_id 3 by returning false
      Validated client_order_id 4 by returning false
      Validated client_order_id 5 by returning false
      Validated client_order_id 6 by returning false
      Validated client_order_id 7 by returning false
      [for MarketMaker] ACCEPTED id=1 AAPL BUY 100@$149.90 DAY
      [for MarketMaker] ACCEPTED id=2 AAPL SELL 100@$150.10 DAY
      [for MarketMaker] ACCEPTED id=3 AAPL BUY 100@$149.89 DAY
      [for MarketMaker] ACCEPTED id=4 AAPL SELL 100@$150.11 DAY
      [for MarketMaker] ACCEPTED id=5 AAPL BUY 100@$149.88 DAY
      [for MarketMaker] ACCEPTED id=6 AAPL SELL 100@$150.12 DAY
      |}];
    return ())
;;
