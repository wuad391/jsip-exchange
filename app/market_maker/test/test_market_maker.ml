(** Tests for the market maker, using a real exchange server. *)

open! Core
open! Async
open Jsip_test_harness
open Jsip_market_maker
open E2e_helpers

(* All market maker tests have been moved to test_bots because i gave up on
   how to test with the hanging thing *)

let default_config : Market_maker.Config.t =
  { participant = Harness.market_maker
  ; symbol = Harness.aapl
  ; fair_value_cents = 15000
  ; half_spread_cents = 10
  ; size_per_level = 100
  ; num_levels = 3
  ; inventory_skew_cents_per_share = 2
  }
;;

(* let%expect_test "Test basic book keeping abilities 2a" = with_server
   ~symbols:[ Harness.aapl ] (fun ~server:_ ~port -> let%bind mm = connect_as
   ~port Harness.market_maker in let%bind () = Market_maker.seed_book
   default_config (connection mm) in
   [%expect {| [for MarketMaker] ACCEPTED id=1 AAPL BUY 100@$149.90 DAY [for MarketMaker] ACCEPTED id=2 AAPL SELL 100@$150.10 DAY [for MarketMaker] ACCEPTED id=3 AAPL BUY 100@$149.89 DAY [for MarketMaker] ACCEPTED id=4 AAPL SELL 100@$150.11 DAY [for MarketMaker] ACCEPTED id=5 AAPL BUY 100@$149.88 DAY [for MarketMaker] ACCEPTED id=6 AAPL SELL 100@$150.12 DAY |}];
   let%bind () = Market_maker.run default_config (connection mm)
   ~testing:true in
   [%expect {| START ==================== Inventory: 1  BIDS: 8, ASKS: END ==================== START ==================== Inventory: 2  BIDS: 8, ASKS: 9, END ==================== START ==================== Inventory: 3  BIDS: 8, 10, ASKS: 9, END ==================== START ==================== Inventory: 4  BIDS: 8, 10, ASKS: 11, 9, END ==================== START ==================== Inventory: 5  BIDS: 12, 10, 8, ASKS: 11, 9, END ==================== START ==================== Inventory: 6  BIDS: 12, 10, 8, ASKS: 11, 13, 9, END ==================== |}];
   return ()) ;; *)

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
      [for MarketMaker] ACCEPTED id=1 AAPL BUY 100@$149.90 DAY
      [for MarketMaker] ACCEPTED id=2 AAPL SELL 100@$150.10 DAY
      [for MarketMaker] ACCEPTED id=3 AAPL BUY 100@$149.89 DAY
      [for MarketMaker] ACCEPTED id=4 AAPL SELL 100@$150.11 DAY
      [for MarketMaker] ACCEPTED id=5 AAPL BUY 100@$149.88 DAY
      [for MarketMaker] ACCEPTED id=6 AAPL SELL 100@$150.12 DAY
      |}];
    return ())
;;
