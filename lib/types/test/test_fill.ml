open! Core
open Jsip_types

let%expect_test "notional_cents: price * size" =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol.of_string "AAPL"
     ; price = Price.of_int_cents 15025
     ; size = Size.of_int 100
     ; aggressor_order_id = Order_id.of_string "1"
     ; aggressor_client_order_id = Client_order_id.of_int 1
     ; aggressor_participant = Participant.of_string "Alice"
     ; aggressor_side = Buy
     ; resting_order_id = Order_id.of_string "2"
     ; resting_client_order_id = Client_order_id.of_int 1
     ; resting_participant = Participant.of_string "Bob"
     }
     : Fill.t)
  in
  [%test_result: int] (Fill.notional_cents fill) ~expect:1502500
;;

(* [to_participant_view] shows the *viewer's own* client_order_id and their
   own side. The aggressor and resting ids are deliberately distinct (7 vs 9)
   so each test proves the correct side's id was selected, not just that some
   id was printed. *)
let%expect_test "to_participant_view: aggressor (buyer) sees their own order"
  =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol.of_string "AAPL"
     ; price = Price.of_int_cents 15025
     ; size = Size.of_int 100
     ; aggressor_order_id = Order_id.of_string "1"
     ; aggressor_client_order_id = Client_order_id.of_int 7
     ; aggressor_participant = Participant.of_string "Alice"
     ; aggressor_side = Buy
     ; resting_order_id = Order_id.of_string "2"
     ; resting_client_order_id = Client_order_id.of_int 9
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
  [%expect {| (test "Order 7: You bought 100 AAPL at $150.25.") |}]
;;

let%expect_test "to_participant_view: resting (seller) sees their own order" =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol.of_string "AAPL"
     ; price = Price.of_int_cents 15025
     ; size = Size.of_int 100
     ; aggressor_order_id = Order_id.of_string "1"
     ; aggressor_client_order_id = Client_order_id.of_int 7
     ; aggressor_participant = Participant.of_string "Alice"
     ; aggressor_side = Buy
     ; resting_order_id = Order_id.of_string "2"
     ; resting_client_order_id = Client_order_id.of_int 9
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
  [%expect {| (test "Order 9: You sold 100 AAPL at $150.25.") |}]
;;
