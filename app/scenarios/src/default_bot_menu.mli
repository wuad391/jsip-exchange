(** The concrete menu of bot kinds the interactive console can spawn: [mm],
    [noise], [momentum], [spammer], [cancel-storm].

    Each kind's knob defaults are copied from the scenario it is proven in
    (calm-day, momentum-day, spam-storm, cancel-storm), so a bare
    [spawn <kind>] behaves like that scenario's instance of the bot.

    Lives here rather than in the scenario-runner library because building a
    {!Jsip_scenario_runner.Bot_spec.t} needs the bot libraries; the
    scenario-runner binary injects {!all} into the console. *)

open! Core

val all : Jsip_scenario_runner.Bot_menu.Entry.t list
