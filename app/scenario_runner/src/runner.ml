open! Core
open! Async

(* Ex4 phase 1 removes Symbol.t from the live path entirely, which breaks
   every scenario's bot/oracle plumbing (Fundamental_oracle, Bot_runtime,
   Jsip_bots, and Jsip_market_maker are all still Symbol.t-keyed) — and there
   is currently no scenario that could reach this code anyway, since
   Jsip_scenarios.all is empty until phase 2 restores it (see the "clear the
   decks" commit). The full implementation ([start_bot] plus [run]'s real
   body) is intact in git history and restorable once those libraries speak
   Symbol_id.t and names can flow again. See
   /home/ubuntu/.claude/plans/eventual-juggling-marshmallow.md. *)
let run (_ : Scenario_config.t) ~port:_ ~seed:_ =
  failwith
    "Runner.run is not yet updated for Ex4 phase 1 -- see the phase 1 plan"
;;
