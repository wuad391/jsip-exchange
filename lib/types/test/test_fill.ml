open! Core
open Jsip_types

let%expect_test "notional_cents: price * size" =
  let fill =
    ({ fill_id = 1
     ; symbol = Symbol_id.of_int 0
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

(* The per-viewer "You bought/sold" rendering that used to live here (as
   [Fill.to_participant_view]) moved to [Jsip_gateway.Protocol.format_event],
   which owns the symbol directory needed to name the symbol. Its coverage
   lives in the gateway's tests now (see [test_protocol.ml]). *)
