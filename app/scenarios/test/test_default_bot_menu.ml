open! Core
open Jsip_types
open Jsip_scenario_runner
module Default_bot_menu = Jsip_scenarios.Default_bot_menu

(* The menu is data, so these tests pin its contract: every kind's defaults
   actually build a spec, overrides land, and the two validation paths
   (unknown knob, momentum's one-symbol rule) produce the documented errors. *)

let one_symbol = [ Symbol_id.of_int 0 ]

let make_with (entry : Bot_menu.Entry.t) ~symbols ~overrides =
  let open Or_error.Let_syntax in
  let%bind knobs = Bot_menu.Entry.resolve_knobs entry ~overrides in
  entry.make
    ~participant:(Participant.of_string "test-bot")
    ~symbols
    ~knobs
    ~rng_seed:1
;;

let print_result result =
  match result with
  | Ok (Bot_spec.T _) -> print_endline "ok"
  | Error error -> print_s [%sexp (error : Error.t)]
;;

let%expect_test "every kind builds a spec from its defaults" =
  List.iter Default_bot_menu.all ~f:(fun (entry : Bot_menu.Entry.t) ->
    let result = make_with entry ~symbols:one_symbol ~overrides:[] in
    let status = if Or_error.is_ok result then "ok" else "ERROR" in
    print_endline [%string "%{entry.kind}: %{status}"]);
  [%expect
    {|
    mm: ok
    noise: ok
    momentum: ok
    spammer: ok
    cancel-storm: ok
    |}]
;;

let%expect_test "a knob override lands in the built spec" =
  let entry = ok_exn (Bot_menu.Entry.find Default_bot_menu.all ~kind:"mm") in
  (match
     ok_exn
       (make_with entry ~symbols:one_symbol ~overrides:[ "tick_ms", 250 ])
   with
   | Bot_spec.T spec -> print_s [%sexp (spec.tick_interval : Time_ns.Span.t)]);
  [%expect {| 250ms |}]
;;

let%expect_test "unknown knobs and momentum's symbol arity are rejected" =
  let momentum =
    ok_exn (Bot_menu.Entry.find Default_bot_menu.all ~kind:"momentum")
  in
  print_result
    (make_with momentum ~symbols:one_symbol ~overrides:[ "half_spread", 3 ]);
  print_result
    (make_with
       momentum
       ~symbols:[ Symbol_id.of_int 0; Symbol_id.of_int 1 ]
       ~overrides:[]);
  [%expect
    {|
    "momentum has no knob half_spread (knobs: window, threshold_cents, max_order_size, max_position, cooldown_ticks, aggression_offset_cents, tick_ms)"
    ("momentum trades exactly one symbol \226\128\148 name one on the spawn line"
     (got 2))
    |}]
;;

let%expect_test "find is case-insensitive and lists the menu on a miss" =
  let (entry : Bot_menu.Entry.t) =
    ok_exn (Bot_menu.Entry.find Default_bot_menu.all ~kind:"MM")
  in
  print_endline entry.kind;
  (match Bot_menu.Entry.find Default_bot_menu.all ~kind:"whale" with
   | Ok (_ : Bot_menu.Entry.t) -> print_endline "ok"
   | Error error -> print_s [%sexp (error : Error.t)]);
  [%expect
    {|
    mm
    "unknown bot kind whale (known: mm, noise, momentum, spammer, cancel-storm)"
    |}]
;;
