(** The interactive stdin console (the [-interactive] flag): spawn, kill, and
    crash bots against the running exchange and watch the effect on the
    monitor.

    {v
      > spawn mm                      spawned mm-1
      > spawn noise noisy AAPL tick_pct=90
      > list                          live bots, kinds, symbols, uptimes
      > kill noisy                    cancel-all, then disconnect
      > crash mm-1                    disconnect only — ghost quotes stay
      > quit                          kill every bot, shut the exchange down
    v}

    The console shares stdout with scenario prints and bot chatter, so lines
    can interleave with the prompt — cosmetic only. *)

open! Core
open! Async
open Jsip_symbol_directory

(** Run the read-parse-execute loop until [quit] or stdin EOF. [quit] kills
    every registered bot, then calls [shutdown]; EOF just detaches the
    console and leaves the exchange running. [spawn] is how new bots come up
    ({!Runner.start_bot}, partially applied by the runner); [registry] is
    shared with the scenario's own bots, so they can be killed and crashed
    too. *)
val start
  :  registry:Bot_registry.t
  -> menu:Bot_menu.Entry.t list
  -> directory:Symbol_directory.t
  -> spawn:(Bot_spec.t -> Bot_handle.t Deferred.Or_error.t)
  -> shutdown:(unit -> unit Deferred.t)
  -> unit Deferred.t
