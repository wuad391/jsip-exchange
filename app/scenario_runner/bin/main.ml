open! Core
open! Async
open Jsip_scenario_runner
open Jsip_scenarios

let scenario_arg =
  Command.Arg_type.of_alist_exn
    ~list_values_in_help:true
    (List.map all ~f:(fun (module S : Scenario.S) ->
       S.name, (module S : Scenario.S)))
;;

let command =
  Command.async
    ~summary:
      "Run a JSIP scenario: boots an exchange and a configured ecosystem of \
       bots."
    (let%map_open.Command scenario =
       flag
         "-scenario"
         (optional scenario_arg)
         ~doc:"NAME scenario to run (with -interactive, defaults to sandbox)"
     and interactive =
       flag
         "-interactive"
         no_arg
         ~doc:" console on stdin to spawn/kill/crash bots as the run goes"
     and port =
       flag
         "-port"
         (optional_with_default 12345 int)
         ~doc:"PORT TCP port to listen on (default 12345)"
     and seed =
       flag
         "-seed"
         (optional_with_default 0 int)
         ~doc:"INT random seed for reproducible scenarios (default 0)"
     and count_orders =
       flag
         "-count-orders"
         no_arg
         ~doc:" report total submit/cancel counts at shutdown"
     in
     fun () ->
       let (module S : Scenario.S) =
         match scenario, interactive with
         | Some scenario, _ -> scenario
         | None, true ->
           (* The empty playground: -interactive with no scenario means "give
              me an exchange and let me drive". *)
           ok_exn (find_by_name "sandbox")
         | None, false ->
           failwith
             "-scenario is required (or pass -interactive to get the \
              sandbox)"
       in
       let config = S.configure () in
       Runner.run
         ~count_orders
         ?interactive:
           (Option.some_if interactive Jsip_scenarios.Default_bot_menu.all)
         config
         ~port
         ~seed)
    ~behave_nicely_in_pipeline:false
;;

let () = Command_unix.run command
