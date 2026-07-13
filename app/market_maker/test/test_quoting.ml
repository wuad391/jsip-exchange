(** Unit tests for the market maker's pure quoting helpers: the spread floor
    that keeps a mirrored quote from collapsing to zero or crossing, and the
    re-quote hysteresis that keeps the maker from chasing every BBO flicker.
    These are synchronous (no server), so this file deliberately does not
    open [Async] -- doing so would make every expect test here async. *)

open! Core
open Jsip_types
open Jsip_market_maker
module Mm = Market_maker_bot.For_testing

let mk_level cents : Level.t =
  { price = Price.of_int_cents cents; size = Size.of_int 100 }
;;

let mk_bbo ~bid ~ask : Bbo.t =
  { bid = Some (mk_level bid); ask = Some (mk_level ask) }
;;

let%expect_test "half_spread_cents floors a collapsing or crossed spread" =
  let show bbo = printf "%d\n" (Mm.half_spread_cents bbo) in
  (* A healthy 40-cent spread mirrors to 20 on each side. *)
  show (mk_bbo ~bid:14980 ~ask:15020);
  [%expect {| 20 |}];
  (* A locked book (bid = ask) would mirror to a zero half-spread -- floored. *)
  show (mk_bbo ~bid:15000 ~ask:15000);
  [%expect {| 5 |}];
  (* A crossed book (bid > ask) mirrors to a negative half-spread, which
     would quote bid above ask -- floored, never negative. *)
  show (mk_bbo ~bid:15010 ~ask:14990);
  [%expect {| 5 |}];
  (* With no opposite side to mirror, fall back to the default half-spread. *)
  show { bid = Some (mk_level 15000); ask = None };
  [%expect {| 50 |}]
;;

let%expect_test "requote_warranted respects the hysteresis threshold" =
  let show ~current ~target =
    printf "%b\n" (Mm.requote_warranted ~threshold:5 ~current ~target)
  in
  (* Identical target: no re-quote. *)
  show ~current:(15000, 10) ~target:(15000, 10);
  [%expect {| false |}];
  (* Fair drifts 3 cents (< threshold): inner quotes move 3 -> no re-quote. *)
  show ~current:(15000, 10) ~target:(15003, 10);
  [%expect {| false |}];
  (* Fair drifts 5 cents (>= threshold): inner quotes move 5 -> re-quote. *)
  show ~current:(15000, 10) ~target:(15005, 10);
  [%expect {| true |}];
  (* Spread widens 6 (>= threshold): inner quotes move 6 -> re-quote. *)
  show ~current:(15000, 10) ~target:(15000, 16);
  [%expect {| true |}]
;;
