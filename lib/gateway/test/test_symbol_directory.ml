open! Core
open! Jsip_types
open! Jsip_gateway

(* The directory is the id<->name mapping the server owns and clients fetch
   at connect. [of_names] assigns id 0 to the first name, 1 to the second,
   and so on — the same order [app/server] uses. *)
let directory =
  Symbol_directory.of_names
    (List.map [ "AAPL"; "TSLA"; "GOOG"; "MSFT" ] ~f:Symbol.of_string)
;;

let%expect_test "id and name are inverse lookups" =
  List.iter (Symbol_directory.to_alist directory) ~f:(fun (id, name) ->
    let id' = Symbol_directory.id directory name |> Option.value_exn in
    let name' = Symbol_directory.name directory id |> Option.value_exn in
    print_endline
      [%string
        "%{id#Symbol_id} <-> %{name#Symbol} (name %{name#Symbol} -> id \
         %{id'#Symbol_id}, id %{id#Symbol_id} -> name %{name'#Symbol})"]);
  [%expect
    {|
    0 <-> AAPL (name AAPL -> id 0, id 0 -> name AAPL)
    1 <-> TSLA (name TSLA -> id 1, id 1 -> name TSLA)
    2 <-> GOOG (name GOOG -> id 2, id 2 -> name GOOG)
    3 <-> MSFT (name MSFT -> id 3, id 3 -> name MSFT)
    |}]
;;

let%expect_test "unknown lookups return None" =
  print_s
    [%sexp
      (Symbol_directory.id directory (Symbol.of_string "NFLX")
       : Symbol_id.t option)];
  print_s
    [%sexp
      (Symbol_directory.name directory (Symbol_id.of_int 99)
       : Symbol.t option)];
  [%expect {|
    ()
    ()
    |}]
;;

(* [id_exn] is for callers resolving their own declared symbols (e.g. a
   scenario building its bots' configs), where an unknown name is a bug, not
   a user error — so it resolves a known name to its id and raises on one it
   never registered. *)
let%expect_test "id_exn resolves a known name and raises on an unknown one" =
  print_s
    [%sexp
      (Symbol_directory.id_exn directory (Symbol.of_string "GOOG")
       : Symbol_id.t)];
  [%expect {| 2 |}];
  (match
     Or_error.try_with (fun () ->
       Symbol_directory.id_exn directory (Symbol.of_string "NFLX"))
   with
   | Ok id -> print_s [%sexp (id : Symbol_id.t)]
   | Error e -> print_s [%sexp (e : Error.t)]);
  [%expect {| ("Symbol_directory.id_exn: unknown symbol" (name NFLX)) |}]
;;

(* The server sends the mapping as an unordered [(id, name)] alist;
   [of_alist] must rebuild the same directory no matter what order the pairs
   arrive in, so a client that reorders them still agrees with the server. *)
let%expect_test "of_alist is order-independent" =
  let reversed = List.rev (Symbol_directory.to_alist directory) in
  let rebuilt = Symbol_directory.of_alist reversed in
  print_s [%sexp (rebuilt : Symbol_directory.t)];
  [%expect {| (AAPL TSLA GOOG MSFT) |}]
;;

(* The Ex4 phase 2 round-trip: a human types [AAPL], it crosses the wire as
   an id, and comes back rendered as [AAPL] again — the wire never carries
   the name. *)
let%expect_test "name -> id (parse) -> name (format) round-trip" =
  (match Exchange_command.parse ~directory "BUY 1 AAPL 100 150.00" with
   | Error e -> print_s [%sexp (e : Error.t)]
   | Ok (Submit request) ->
     print_endline
       [%string "on the wire: symbol id = %{request.symbol#Symbol_id}"];
     let event =
       Exchange_event.Trade_report
         { symbol = request.symbol
         ; price = request.price
         ; size = request.size
         }
     in
     print_endline [%string "rendered raw:  %{Protocol.format_event event}"];
     print_endline
       [%string "rendered named: %{Protocol.format_event ~directory event}"]
   | Ok other ->
     print_endline [%string "unexpected command: %{other#Exchange_command}"]);
  [%expect
    {|
    on the wire: symbol id = 0
    rendered raw:  TRADE 0 $150.00 x100
    rendered named: TRADE AAPL $150.00 x100
    |}]
;;
