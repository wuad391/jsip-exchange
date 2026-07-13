open! Core
open! Async
open Jsip_types
open Jsip_scenario_runner
open Jsip_test_harness
module Bot_runtime = Jsip_bot_runtime.Bot_runtime
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle

(* A minimal strategy for lifecycle tests: it rests one bid in [on_start],
   fills [seeded] once the submit is acknowledged, and never acts again (its
   tick interval below is a day). *)
module One_order_bot = struct
  module Config = struct
    type t = { seeded : unit Ivar.t }
  end

  let name = "one-order"

  let on_start (cfg : Config.t) ctx =
    let%map result =
      Bot_runtime.Context.submit
        ctx
        { client_order_id = Client_order_id.of_int 1
        ; symbol = Symbol_id.of_int 0
        ; participant = Bot_runtime.Context.participant ctx
        ; side = Buy
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 10
        ; time_in_force = Day
        }
    in
    (match result with
     | Ok () -> ()
     | Error error -> print_s [%sexp (error : Error.t)]);
    Ivar.fill_exn cfg.seeded ()
  ;;

  let on_tick _cfg _ctx = return ()
  let on_event _cfg _ctx _event = return ()
end

let oracle =
  Fundamental_oracle.create
    (Symbol_id.Map.of_alist_exn
       [ ( Symbol_id.of_int 0
         , { Fundamental_oracle.Config.initial_price_cents = 15000
           ; volatility_cents_per_sec = 0.0
           ; mean_reversion_strength = 0.0
           ; tick_interval = Time_ns.Span.of_sec 1.0
           } )
       ])
    ~seed:0
;;

let start_one_order_bot ~port ~name =
  let where_to_connect =
    Tcp.Where_to_connect.of_host_and_port
      { Host_and_port.host = "localhost"; port }
  in
  let seeded = Ivar.create () in
  let spec =
    Bot_spec.T
      { bot = (module One_order_bot)
      ; config = { One_order_bot.Config.seeded }
      ; participant = Participant.of_string name
      ; symbols = [ Symbol_id.of_int 0 ]
      ; rng_seed = 0
      ; tick_interval = Time_ns.Span.of_day 1.0
      ; is_marketdata_consumer = false
      }
  in
  Runner.start_bot ~where_to_connect ~oracle spec
  >>| ok_exn
  >>| fun handle -> handle, seeded
;;

(* An unrelated cancel-all rides the same ordered request queue as the bot's
   submit, so its response proves everything enqueued before it has been
   processed by the engine — after this, [rpc_book] reflects the bot's order
   deterministically. *)
let queue_barrier probe =
  match%map E2e_helpers.rpc_cancel_all probe with
  | Ok (_ : int) -> ()
  | Error error -> print_s [%sexp (error : Error.t)]
;;

let print_book probe =
  let%map book = E2e_helpers.rpc_book probe (Symbol_id.of_int 0) in
  print_endline (Option.value_exn book |> Book.to_string)
;;

let%expect_test "kill flattens the bot's book and stops its loop" =
  E2e_helpers.with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind probe =
      E2e_helpers.connect_as ~port (Participant.of_string "Probe")
    in
    let%bind handle, seeded = start_one_order_bot ~port ~name:"victim" in
    [%expect {| [scenario] starting bot victim |}];
    let%bind () = Ivar.read seeded in
    let%bind () = queue_barrier probe in
    let%bind () = print_book probe in
    [%expect
      {|
      === 0 ===
        BIDS:
          $150.00 x10
        ASKS: (empty)
        BBO: $150.00 x10 / -
      |}];
    let%bind cancelled = Bot_handle.kill handle in
    print_s [%sexp (cancelled : int Or_error.t)];
    print_endline
      [%string
        "tick loop determined: %{Deferred.is_determined \
         handle.tick_loop#Bool}"];
    let%bind () = print_book probe in
    [%expect
      {|
      (Ok 1)
      tick loop determined: true
      === 0 ===
        BIDS: (empty)
        ASKS: (empty)
        BBO: - / -
      |}];
    return ())
;;

let%expect_test "crash leaves ghost orders resting on the book" =
  E2e_helpers.with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let%bind probe =
      E2e_helpers.connect_as ~port (Participant.of_string "Probe")
    in
    let%bind handle, seeded = start_one_order_bot ~port ~name:"ghost" in
    [%expect {| [scenario] starting bot ghost |}];
    let%bind () = Ivar.read seeded in
    let%bind () = queue_barrier probe in
    let%bind () = Bot_handle.crash handle in
    print_endline
      [%string
        "tick loop determined: %{Deferred.is_determined \
         handle.tick_loop#Bool}"];
    (* Nobody cancelled the ghost's order: it is still resting, exactly the
       stale-book failure mode [kill] exists to avoid. *)
    let%bind () = print_book probe in
    [%expect
      {|
      tick loop determined: true
      === 0 ===
        BIDS:
          $150.00 x10
        ASKS: (empty)
        BBO: $150.00 x10 / -
      |}];
    return ())
;;

let%expect_test "registry: add, duplicate rejection, remove" =
  E2e_helpers.with_server ~num_symbols:1 (fun ~server:_ ~port ->
    let registry = Bot_registry.create () in
    let%bind handle, _seeded = start_one_order_bot ~port ~name:"solo" in
    [%expect {| [scenario] starting bot solo |}];
    print_s [%sexp (Bot_registry.add registry handle : unit Or_error.t)];
    print_s [%sexp (Bot_registry.add registry handle : unit Or_error.t)];
    let removed = Bot_registry.remove registry handle.participant in
    print_endline
      [%string
        "removed: %{Option.is_some removed#Bool}, still registered: \
         %{Bot_registry.mem registry handle.participant#Bool}"];
    [%expect
      {|
      (Ok ())
      (Error ("a bot with this name is already running" (name solo)))
      removed: true, still registered: false
      |}];
    let%bind (_ : int) = Bot_handle.kill handle >>| ok_exn in
    return ())
;;
