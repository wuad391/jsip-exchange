open! Core
open! Jsip_types
open! Jsip_order_book
open! Jsip_gateway

(* TODO: learn spacemacs *)
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
  print_parse "BUY 1 AAPL 100 150.25";
  [%expect {| Order 1: BUY AAPL 100@$150.25 DAY as anonymous |}]
;;

let%expect_test "parse: basic sell" =
  print_parse "SELL 1 TSLA 50 200.00";
  [%expect {| Order 1: SELL TSLA 50@$200.00 DAY as anonymous |}]
;;

let%expect_test "parse: case insensitive side" =
  print_parse "buy 1 AAPL\n   100\n 150.00";
  print_parse "Buy 1 AAPL 100 150.00";
  [%expect
    {|
    Order 1: BUY AAPL 100@$150.00 DAY as anonymous
    Order 1: BUY AAPL 100@$150.00 DAY as anonymous
    |}]
;;

let%expect_test "parse: with IOC time-in-force" =
  print_parse "BUY\n 1\n  AAPL\n\n 100 150.00 IOC";
  [%expect {| Order 1: BUY AAPL 100@$150.00 IOC as anonymous |}]
;;

let%expect_test "parse: with explicit DAY" =
  print_parse "SELL 1 AAPL\n   200\n\n 151.00 DAY";
  [%expect {| Order 1: SELL AAPL 200@$151.00 DAY as anonymous |}]
;;

let%expect_test "parse: with participant" =
  print_parse "BUY 1 AAPL 100\n\n\n   150.00 as Alice";
  [%expect {| Order 1: BUY AAPL 100@$150.00 DAY as Alice |}]
;;

let%expect_test "parse: with TIF and participant" =
  print_parse "SELL\n\n  1 GOOG\n 75 2800.50 IOC as Bob";
  [%expect {| Order 1: SELL GOOG 75@$2800.50 IOC as Bob |}]
;;

let%expect_test "parse: symbol is uppercased" =
  print_parse "BUY 1 aapl\n\n   100\n 150.00";
  [%expect {| Order 1: BUY AAPL 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: extra whitespace is ignored" =
  print_parse "\n   BUY\n\n 1 AAPL 100 150.00 ";
  [%expect {| Order 1: BUY AAPL 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: price with dollar sign" =
  print_parse "BUY\n 1  AAPL\n\n 100 $150.25";
  [%expect {| Order 1: BUY AAPL 100@$150.25 DAY as anonymous |}]
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
  print_parse "HOLD\n   AAPL\n\n 100 150.00";
  [%expect
    {| "unknown command HOLD (expected Buy, Sell, Book, Subscribe, Cancel)" |}]
;;

(* I changed this because it does not make sense to allow orders that are
   missing fields *)
let%expect_test "parse error: missing fields" =
  print_parse "BUY AAPL";
  print_parse "BUY";
  [%expect
    {|
    "expected: BUY|SELL <client order id> <symbol> <size> <price> [DAY or IOC] [as <name>]"
    "expected: BUY|SELL <client order id> <symbol> <size> <price> [DAY or IOC] [as <name>]"
    |}]
;;

let%expect_test "parse error: invalid size" =
  print_parse "BUY 1 AAPL\n   abc\n\n 150.00";
  print_parse "BUY 1 AAPL 0 150.00";
  print_parse "BUY 1 AAPL\n   -5\n\n 150.00";
  [%expect
    {| 
    "invalid size: abc" 
    "size must be positive" 
    "size must be positive" |}]
;;

let%expect_test "parse error: invalid price" =
  print_parse "BUY 1 AAPL\n   100\n\n xyz";
  [%expect
    {|
     "invalid price: xyz\
    \nexception: (Invalid_argument \"Float.of_string xyz\")"
    |}]
;;

let%expect_test "parse error: unknown time-in-force" =
  print_parse "BUY\n\n 1 AAPL 100 150.00 QQQ";
  [%expect {| "unknown time-in-force: QQQ (expected DAY or IOC)" |}]
;;

let%expect_test "parse error: invalid client_order_id" =
  print_parse "BUY\n\n hello AAPL 100 150.00 QQQ";
  [%expect {|
     "invalid client_id: hello\
    \nexception: (Failure int_of_string)"
    |}]
;;

let%expect_test "checking book" =
  print_parse "BOOK YAY";
  [%expect {| BOOK YAY |}]
;;

let%expect_test "checking subscribe" =
  print_parse "SUBSCRIBE Yay";
  [%expect {| SUBSCRIBE YAY |}]
;;

let%expect_test "default participant: used when none specified" =
  let _ = print_parse_default "BUY 1 AAPL 100 150.00" "Default" in
  (* print_endline [%string "participant=%{req.participant#Participant}"]; *)
  [%expect {| Order 1: BUY AAPL 100@$150.00 DAY as Default |}]
;;

let%expect_test "default participant: overridden by explicit 'as'" =
  let _ =
    print_parse_default "BUY 1 AAPL 100 150.00 as\n\n Alice" "default"
  in
  (* print_endline [%string "participant=%{req.participant#Participant}"]; *)
  [%expect {| Order 1: BUY AAPL 100@$150.00 DAY as Alice |}]
;;
