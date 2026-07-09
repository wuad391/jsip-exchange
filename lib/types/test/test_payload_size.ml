open! Core
open Jsip_types

(* Exercise 4's payoff, made concrete. Pushing the symbol onto the wire as a
   [Symbol_id.t] (a small int) instead of a [Symbol.t] (a string) shrinks
   every message that carries a symbol. [bin_prot] sizes are a deterministic
   byte count, so the shrink is exact and testable -- and multiplied across
   every order and every streamed market-data event, it is real bandwidth.

   Each of the four wire types below carries exactly ONE symbol, so each
   shrinks by the same per-symbol saving. We measure that saving directly
   (the int vs string encoding of a single symbol), then report every
   message's actual int-symbol payload next to the string-symbol payload it
   would have had. The saving scales with the ticker's length; ["AAPL"] (four
   characters) is representative. *)

let name = Symbol.of_string "AAPL"
let symbol_id = Symbol_id.of_int 0

(* One symbol on the wire, both ways: the int id versus the string it stands
   for. This delta is the whole point of the exercise. *)
let id_bytes = Symbol_id.bin_size_t symbol_id
let name_bytes = Symbol.bin_size_t name
let saving_per_symbol = name_bytes - id_bytes

(* One representative value per wire type, each carrying a single symbol. The
   books/levels are empty so the count isolates the fixed per-message cost --
   the symbol is a per-message overhead no matter how deep the book is. *)
let request : Order.Request.t =
  { symbol = symbol_id
  ; participant = Participant.of_string "Alice"
  ; side = Buy
  ; price = Price.of_int_cents 15000
  ; size = Size.of_int 100
  ; time_in_force = Day
  ; client_order_id = Client_order_id.of_int 1
  }
;;

let fill : Fill.t =
  { fill_id = 1
  ; symbol = symbol_id
  ; price = Price.of_int_cents 15000
  ; size = Size.of_int 100
  ; aggressor_order_id = Order_id.of_string "1"
  ; aggressor_client_order_id = Client_order_id.of_int 1
  ; aggressor_participant = Participant.of_string "Alice"
  ; aggressor_side = Buy
  ; resting_order_id = Order_id.of_string "2"
  ; resting_client_order_id = Client_order_id.of_int 1
  ; resting_participant = Participant.of_string "Bob"
  }
;;

let book : Book.t =
  { symbol = symbol_id; bids = []; asks = []; bbo = Bbo.empty }
;;

let event : Exchange_event.t =
  Exchange_event.Trade_report
    { symbol = symbol_id
    ; price = Price.of_int_cents 15000
    ; size = Size.of_int 100
    }
;;

let%expect_test "one symbol on the wire: int id vs string name" =
  print_s
    [%message
      "" (id_bytes : int) (name_bytes : int) (saving_per_symbol : int)];
  [%expect {| ((id_bytes 1) (name_bytes 5) (saving_per_symbol 4)) |}]
;;

let%expect_test "per-message payload shrink (bytes)" =
  let row label int_symbol_bytes =
    (* Each message carries exactly one symbol, so its string-symbol payload
       is the measured int-symbol payload plus one symbol's worth of saving. *)
    let string_symbol_bytes = int_symbol_bytes + saving_per_symbol in
    print_endline
      [%string
        "%{label}: int-symbol=%{int_symbol_bytes#Int}  \
         string-symbol=%{string_symbol_bytes#Int}  \
         saved=%{saving_per_symbol#Int}"]
  in
  row "Order.Request.t" (Order.Request.bin_size_t request);
  row "Fill.t         " (Fill.bin_size_t fill);
  row "Book.t (empty) " (Book.bin_size_t book);
  row "Trade_report   " (Exchange_event.bin_size_t event);
  [%expect
    {|
    Order.Request.t: int-symbol=14  string-symbol=18  saved=4
    Fill.t         : int-symbol=21  string-symbol=25  saved=4
    Book.t (empty) : int-symbol=5  string-symbol=9  saved=4
    Trade_report   : int-symbol=6  string-symbol=10  saved=4
    |}]
;;
