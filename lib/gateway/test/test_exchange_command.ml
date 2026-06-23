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
  print_parse "BUY AAPL 100 150.25";
  [%expect {| BUY AAPL 100@$150.25 DAY as anonymous |}]
;;

let%expect_test "parse: basic sell" =
  print_parse "SELL TSLA 50 200.00";
  [%expect {| SELL TSLA 50@$200.00 DAY as anonymous |}]
;;

let%expect_test "parse: case insensitive side" =
  print_parse "buy AAPL\n   100\n 150.00";
  print_parse "Buy AAPL 100 150.00";
  [%expect
    {| 
    BUY AAPL 100@$150.00 DAY as anonymous 
    BUY AAPL 100@$150.00 DAY as anonymous 
    |}]
;;

let%expect_test "parse: with IOC time-in-force" =
  print_parse "BUY\n   AAPL\n\n 100 150.00 IOC";
  [%expect {| BUY AAPL 100@$150.00 IOC as anonymous |}]
;;

let%expect_test "parse: with explicit DAY" =
  print_parse "SELL AAPL\n   200\n\n 151.00 DAY";
  [%expect {| SELL AAPL 200@$151.00 DAY as anonymous |}]
;;

let%expect_test "parse: with participant" =
  print_parse "BUY AAPL 100\n\n\n   150.00 as Alice";
  [%expect {| BUY AAPL 100@$150.00 DAY as Alice |}]
;;

let%expect_test "parse: with TIF and participant" =
  print_parse "SELL\n\n   GOOG\n 75 2800.50 IOC as Bob";
  [%expect {| SELL GOOG 75@$2800.50 IOC as Bob |}]
;;

let%expect_test "parse: symbol is uppercased" =
  print_parse "BUY aapl\n\n   100\n 150.00";
  [%expect {| BUY AAPL 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: extra whitespace is ignored" =
  print_parse "\n   BUY\n\n AAPL 100 150.00 ";
  [%expect {| BUY AAPL 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: price with dollar sign" =
  print_parse "BUY\n   AAPL\n\n 100 $150.25";
  [%expect {| BUY AAPL 100@$150.25 DAY as anonymous |}]
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
    {| "unknown command HOLD (expected Buy, Sell, Book, or
              Subscribe)" |}]
;;

(* I changed this because it does not make sense to allow orders that are
   missing fields *)
let%expect_test "parse error: missing fields" =
  print_parse "BUY AAPL";
  print_parse "BUY";
  [%expect
    {| "expected: BUY|SELL <symbol> <size> <price> [DAY|IOC] [as <name>]" 
       "expected: BUY|SELL <symbol> <size> <price> [DAY|IOC] [as <name>]" |}]
;;

let%expect_test "parse error: invalid size" =
  print_parse "BUY AAPL\n   abc\n\n 150.00";
  print_parse "BUY AAPL 0 150.00";
  print_parse "BUY AAPL\n   -5\n\n 150.00";
  [%expect
    {| 
    "invalid size: abc" 
    "size must be positive" 
    "size must be positive" |}]
;;

let%expect_test "parse error: invalid price" =
  print_parse "BUY AAPL\n   100\n\n xyz";
  [%expect
    {| "invalid price: xyz exception: (Invalid_argument "Float.of_string xyz")" |}]
;;

let%expect_test "parse error: unknown time-in-force" =
  print_parse "BUY\n\n AAPL 100 150.00 QQQ";
  [%expect {| "unknown time-in-force: QQQ (expected DAY or IOC)" |}]
;;

let%expect_test "checking book" =
  print_parse "BOOK YAY";
  [%expect {| "Book YAY" |}]
;;

let%expect_test "checking subscribe" =
  print_parse "SUBSCRIBE Yay";
  [%expect {| "Subscribe YAY" |}]
;;

let%expect_test "default participant: used when none specified" =
  let _ = print_parse_default "BUY AAPL 100 150.00" "Default" in
  (* print_endline [%string "participant=%{req.participant#Participant}"]; *)
  [%expect {| participant=DefaultTrader |}]
;;

let%expect_test "default participant: overridden by explicit 'as'" =
  let _ = print_parse_default "BUY AAPL 100 150.00 as\n\n Alice" "default" in
  (* print_endline [%string "participant=%{req.participant#Participant}"]; *)
  [%expect {| participant=Alice |}]
;;
