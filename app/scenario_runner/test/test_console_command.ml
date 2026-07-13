open! Core
open Jsip_types
open Jsip_scenario_runner
open Jsip_symbol_directory

(* Grammar tests for the interactive console, modeled on
   [lib/gateway/test/test_exchange_command.ml]: parse a line, print the sexp.
   Menu validation (is "mm" a real kind? is "tick_ms" one of its knobs?) is
   deliberately NOT here — the parser only owns the string shape. *)

let directory =
  Symbol_directory.of_names
    (List.map [ "AAPL"; "GOOG"; "MSFT" ] ~f:Symbol.of_string)
;;

let parse ?directory line =
  print_s
    [%sexp
      (Console_command.parse ?directory line : Console_command.t Or_error.t)]
;;

let%expect_test "spawn: kind alone, with defaults everywhere" =
  parse ~directory "spawn mm";
  [%expect {| (Ok (Spawn (kind mm) (name ()) (symbols ()) (knobs ()))) |}]
;;

let%expect_test "spawn: name, symbols, and knobs all together" =
  parse ~directory "spawn noise noisy AAPL MSFT tick_pct=90 avg_size=3";
  [%expect
    {|
    (Ok
     (Spawn (kind noise) (name (noisy)) (symbols (0 2))
      (knobs ((tick_pct 90) (avg_size 3)))))
    |}]
;;

let%expect_test "spawn: symbols without a name" =
  parse ~directory "spawn mm AAPL GOOG";
  [%expect {| (Ok (Spawn (kind mm) (name ()) (symbols (0 1)) (knobs ()))) |}]
;;

let%expect_test "spawn: without a directory, symbols are raw ids" =
  parse "spawn mm noisy 0 2";
  [%expect
    {| (Ok (Spawn (kind mm) (name (noisy)) (symbols (0 2)) (knobs ()))) |}]
;;

let%expect_test "verbs are case-insensitive; kind is kept verbatim" =
  parse ~directory "SPAWN MM";
  [%expect {| (Ok (Spawn (kind MM) (name ()) (symbols ()) (knobs ()))) |}];
  parse ~directory "LIST";
  [%expect {| (Ok List_bots) |}]
;;

let%expect_test "spawn: bad knob values and misplaced knobs are rejected" =
  parse ~directory "spawn mm half_spread=abc";
  [%expect
    {| (Error "knob half_spread needs an integer value, got \"abc\"") |}];
  parse ~directory "spawn mm tick_ms=100 AAPL";
  [%expect
    {|
    (Error
     "AAPL comes after a key=value knob \226\128\148 knobs must be the last tokens on the line")
    |}]
;;

let%expect_test "spawn: a second unresolvable bare token is a symbol error" =
  (* First bare token that isn't a symbol = the name; the next one must be a
     real symbol, so its resolution error surfaces with the known list. *)
  parse ~directory "spawn mm noisy TSLA";
  [%expect {| (Error "unknown symbol TSLA (known: AAPL, GOOG, MSFT)") |}]
;;

let%expect_test "spawn: a misspelled ticker in first bare position reads as \
                 a name"
  =
  (* Documented quirk of the grammar: nothing distinguishes a name from a
     typo'd symbol in the name slot. *)
  parse ~directory "spawn mm APPL";
  [%expect
    {| (Ok (Spawn (kind mm) (name (APPL)) (symbols ()) (knobs ()))) |}]
;;

let%expect_test "spawn: no kind" =
  parse ~directory "spawn";
  [%expect
    {| (Error "expected: SPAWN <kind> [<name>] [<SYMBOL>...] [key=value ...]") |}]
;;

let%expect_test "kill and crash take the rest of the line as the name" =
  parse ~directory "kill Market Maker";
  [%expect {| (Ok (Kill "Market Maker")) |}];
  parse ~directory "crash noise-1";
  [%expect {| (Ok (Crash noise-1)) |}];
  parse ~directory "kill";
  [%expect {| (Error "expected: KILL <bot name>") |}]
;;

let%expect_test "bare verbs" =
  parse ~directory "kinds";
  [%expect {| (Ok Kinds) |}];
  parse ~directory "help";
  [%expect {| (Ok Help) |}];
  parse ~directory "quit";
  [%expect {| (Ok Quit) |}]
;;

let%expect_test "junk is rejected with the verb list" =
  parse ~directory "";
  [%expect {| (Error "empty command") |}];
  parse ~directory "explode everything";
  [%expect
    {|
    (Error
     "unknown command explode (expected Spawn, Kill, Crash, List, Kinds, Help, Quit)")
    |}]
;;
