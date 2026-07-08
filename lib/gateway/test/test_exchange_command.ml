open! Core
open! Jsip_types
open! Jsip_order_book
open! Jsip_gateway

(* Ex4 phase 1: symbols cross the wire as ints, so a command's symbol field
   is now a [Symbol_id.t] typed as a bare integer (e.g. [BUY 1 0 100 150.25]
   buys 100 of symbol id 0). The parser rejects a non-numeric or negative
   symbol at this edge, client-side, before anything reaches the server. *)

let print_parse line =
  match Exchange_command.parse line with
  | Error msg -> print_s [%sexp (msg : Error.t)]
  | Ok command -> print_endline [%string "%{command#Exchange_command}"]
;;

let print_parse_default line default =
  match
    Exchange_command.parse
      line
      ~default_participant:(Participant.of_string default)
  with
  | Error msg -> print_s [%sexp (msg : Error.t)]
  | Ok command -> print_endline [%string "%{command#Exchange_command}"]
;;

(* --- Successful parsing --- *)

let%expect_test "parse: basic buy" =
  print_parse "BUY 1 0 100 150.25";
  [%expect {| Order 1: BUY 0 100@$150.25 DAY as anonymous |}]
;;

let%expect_test "parse: basic sell" =
  print_parse "SELL 1 1 50 200.00";
  [%expect {| Order 1: SELL 1 50@$200.00 DAY as anonymous |}]
;;

let%expect_test "parse: case insensitive side" =
  print_parse "buy 1 0\n   100\n 150.00";
  print_parse "Buy 1 0 100 150.00";
  [%expect
    {|
    Order 1: BUY 0 100@$150.00 DAY as anonymous
    Order 1: BUY 0 100@$150.00 DAY as anonymous
    |}]
;;

let%expect_test "parse: with IOC time-in-force" =
  print_parse "BUY\n 1\n  0\n\n 100 150.00 IOC";
  [%expect {| Order 1: BUY 0 100@$150.00 IOC as anonymous |}]
;;

let%expect_test "parse: with explicit DAY" =
  print_parse "SELL 1 0\n   200\n\n 151.00 DAY";
  [%expect {| Order 1: SELL 0 200@$151.00 DAY as anonymous |}]
;;

let%expect_test "parse: with participant" =
  print_parse "BUY 1 0 100\n\n\n   150.00";
  [%expect {| Order 1: BUY 0 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: with TIF and participant" =
  print_parse "SELL\n\n  1 2\n 75 2800.50 IOC";
  [%expect {| Order 1: SELL 2 75@$2800.50 IOC as anonymous |}]
;;

let%expect_test "parse: extra whitespace is ignored" =
  print_parse "\n   BUY\n\n 1 0 100 150.00 ";
  [%expect {| Order 1: BUY 0 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: price with dollar sign" =
  print_parse "BUY\n 1  0\n\n 100 $150.25";
  [%expect {| Order 1: BUY 0 100@$150.25 DAY as anonymous |}]
;;

(* --- Parse errors --- *)

let%expect_test "parse error: empty string" =
  print_parse "";
  print_parse " ";
  [%expect {|
    "empty command"
    "empty command"
              |}]
;;

let%expect_test "parse error: unknown command" =
  print_parse "HOLD\n   0\n\n 100 150.00";
  [%expect
    {| "unknown command HOLD (expected Buy, Sell, Book, Subscribe, Cancel)" |}]
;;

(* I changed this because it does not make sense to allow orders that are
   missing fields *)
let%expect_test "parse error: missing fields" =
  print_parse "BUY 0";
  print_parse "BUY";
  [%expect
    {|
    "expected: BUY|SELL <client order id> <symbol> <size> <price> [DAY or IOC]"
    "expected: BUY|SELL <client order id> <symbol> <size> <price> [DAY or IOC]"
    |}]
;;

let%expect_test "parse error: invalid size" =
  print_parse "BUY 1 0\n   abc\n\n 150.00";
  print_parse "BUY 1 0 0 150.00";
  print_parse "BUY 1 0\n   -5\n\n 150.00";
  [%expect
    {|
    "invalid size: abc"
    "size must be positive"
    "size must be positive" |}]
;;

let%expect_test "parse error: invalid price" =
  print_parse "BUY 1 0\n   100\n\n xyz";
  [%expect
    {|
     "invalid price: xyz\
    \nexception: (Invalid_argument \"Float.of_string xyz\")"
    |}]
;;

(* A non-numeric symbol is rejected at parse time, client-side: [Symbol_id]'s
   [of_string] is [Int.of_string], which raises on a ticker like "AAPL". This
   is the parser-edge half of "don't trust the client"; the engine still does
   its own out-of-range check on ids that *do* parse (see
   test_matching_engine's unknown-symbol test). *)
let%expect_test "parse error: non-numeric symbol" =
  print_parse "BUY 1 AAPL 100 150.00";
  [%expect
    {|
     "invalid symbol: AAPL\
    \nexception: (Failure \"Int.of_string: \\\"AAPL\\\"\")"
    |}]
;;

(* A negative symbol id parses as an int but [Symbol_id.of_int] rejects it,
   so the client can't smuggle one past the edge either. *)
let%expect_test "parse error: negative symbol" =
  print_parse "BUY 1 -3 100 150.00";
  [%expect
    {|
     "invalid symbol: -3\
    \nexception: (\"Symbol_id.of_int: id must be non-negative\" (n -3))"
    |}]
;;

let%expect_test "parse error: unknown time-in-force" =
  print_parse "BUY\n\n 1 0 100 150.00 QQQ";
  [%expect {| "unknown time-in-force: QQQ (expected DAY or IOC)" |}]
;;

let%expect_test "parse error: invalid client_order_id" =
  print_parse "BUY\n\n hello 0 100 150.00 QQQ";
  [%expect
    {|
     "invalid client_id: hello\
    \nexception: (Failure int_of_string)"
    |}]
;;

let%expect_test "checking book" =
  print_parse "BOOK 0";
  [%expect {| BOOK 0 |}]
;;

let%expect_test "checking subscribe" =
  print_parse "SUBSCRIBE 2";
  [%expect {| SUBSCRIBE 2 |}]
;;

let%expect_test "default participant: used when none specified" =
  let _ = print_parse_default "BUY 1 0 100 150.00" "Default" in
  (* print_endline [%string "participant=%{req.participant#Participant}"]; *)
  [%expect {| Order 1: BUY 0 100@$150.00 DAY as Default |}]
;;
