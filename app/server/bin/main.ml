(** Exchange server.

    Runs the matching engine and listens for RPC connections from clients..

    Run with: dune exec app/server/bin/main.exe -- -port 12345

    Optionally seed the book with a market maker: dune exec
    app/server/bin/main.exe -- -port 12345 -seed-market-maker *)

open! Core
open! Async
open Jsip_gateway

(* Ex4 phase 1: symbols are ints end-to-end, so this is just a count now (id
   0 = AAPL, 1 = TSLA, 2 = GOOG, 3 = MSFT for anyone reading the source —
   nothing in the running system knows those names until phase 2's
   directory). *)
let num_symbols = 4

(* Ex4 phase 1 removes Symbol.t from the live path entirely, which breaks
   [Jsip_market_maker]/[Jsip_fundamental]/[Jsip_bot_runtime] (all still
   Symbol.t-keyed). [connect_as], [start_market_maker_bot], and
   [trade_back_and_forth] (the -trade-back-and-forth demo) depended on them
   and are deleted here rather than commented out — ocamlformat reflows
   comment text as prose, which would mangle inert code beyond recognition.
   They're fully intact in git history (see the "clear the decks" commit) and
   restorable once those libraries speak Symbol_id.t (Ex4 stage 4) and names
   can flow again (phase 2's directory). See
   /home/ubuntu/.claude/plans/eventual-juggling-marshmallow.md. *)

let start ~port ~market_maker_behavior =
  let%bind server = Exchange_server.start ~num_symbols ~port () in
  let%bind () =
    match market_maker_behavior with
    | `Trade_back_and_forth ->
      print_endline
        "-trade-back-and-forth is not yet updated for Ex4 (symbols are ints \
         end-to-end now, and the market maker/oracle libraries still speak \
         Symbol.t) — see the phase 1 plan for the restoration plan.";
      Deferred.unit
    | `Do_nothing -> Deferred.unit
  in
  print_endline
    [%string
      "JSIP Exchange server listening on port %{Exchange_server.port \
       server#Int}"];
  print_endline
    [%string
      "Trading: %{num_symbols#Int} symbols (ids 0-%{(num_symbols - 1)#Int})"];
  Exchange_server.close_finished server
;;

let () =
  Command.async
    ~summary:"JSIP Exchange server"
    (let%map_open.Command port =
       flag "-port" (required int) ~doc:"PORT port to listen on"
     and market_maker_behavior =
       choose_one
         ~if_nothing_chosen:(Default_to `Do_nothing)
         [ flag
             "-trade-back-and-forth"
             (no_arg_some `Trade_back_and_forth)
             ~doc:
               " run two market makers in a loop, generating sustained \
                traffic for the monitor (mutually exclusive with \
                -seed-market-maker)"
         ]
     and () = Log.Global.set_level_via_param () in
     fun () -> start ~port ~market_maker_behavior)
  |> Command_unix.run
;;
