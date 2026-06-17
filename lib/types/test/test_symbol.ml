open! Core
open Jsip_types
open Expect_test_helpers_core

let%expect_test "of_string: empty string raises" =
  require_does_raise (fun () -> Symbol.of_string "");
  [%expect {| "Symbol.of_string: symbol must be non-empty" |}]
;;

let%expect_test "of_string: special character raises" =
  require_does_raise (fun () -> Symbol.of_string "😃🐧");
  [%expect {| "Symbol.of_string: contains invalid characters" |}];
  require_does_raise (fun () -> Symbol.of_string "@*#&469&3$*(#&$(*#&$()))");
  [%expect {| "Symbol.of_string: contains invalid characters" |}]
;;

let%expect_test "of_string: automatically uppercases" =
  print_s [%message (Symbol.of_string "aapl" : Symbol.t)];
  [%expect {| ("Symbol.of_string \"aapl\"" AAPL) |}]
;;
