open! Core
open Jsip_types

let%expect_test "notional_cents: price * size" =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol.of_string "AAPL"
     ; price = Price.of_int_cents 15025
     ; size = Size.of_int 100
     ; aggressor_order_id = Order_id.of_string "1"
     ; aggressor_participant = Participant.of_string "Alice"
     ; aggressor_side = Buy
     ; resting_order_id = Order_id.of_string "2"
     ; resting_participant = Participant.of_string "Bob"
     }
     : Fill.t)
  in
  [%test_result: int] (Fill.notional_cents fill) ~expect:1502500
;;

let%expect_test "testing to_participant" =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol.of_string "AAPL"
     ; price = Price.of_int_cents 15025
     ; size = Size.of_int 100
     ; aggressor_order_id = Order_id.of_string "1"
     ; aggressor_participant = Participant.of_string "Alice"
     ; aggressor_side = Buy
     ; resting_order_id = Order_id.of_string "2"
     ; resting_participant = Participant.of_string "Bob"
     }
     : Fill.t)
  in
  let test =
    match Fill.to_participant_view fill (Participant.of_string "Alice") with
    | Some x -> x
    | None ->
      raise_s
        [%message
          "testing to_participant returned None when should have Some _"]
  in
  print_s [%message (test : string)];
  [%expect {| (test "You bought 100 AAPL at $150.25.") |}]
;;

let%expect_test "testing to_participant" =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol.of_string "AAPL"
     ; price = Price.of_int_cents 15025
     ; size = Size.of_int 100
     ; aggressor_order_id = Order_id.of_string "1"
     ; aggressor_participant = Participant.of_string "Alice"
     ; aggressor_side = Buy
     ; resting_order_id = Order_id.of_string "2"
     ; resting_participant = Participant.of_string "Bob"
     }
     : Fill.t)
  in
  let test =
    match Fill.to_participant_view fill (Participant.of_string "Bob") with
    | Some x -> x
    | None ->
      raise_s
        [%message
          "testing to_participant returned None when should have Some _"]
  in
  print_s [%message (test : string)];
  [%expect {| (test "You sold 100 AAPL at $150.25.") |}]
;;
