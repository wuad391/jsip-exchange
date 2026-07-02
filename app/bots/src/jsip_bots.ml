(** Student-written trading bots.

    Each bot is a {!Jsip_bot_runtime.Bot_runtime.Bot}; scenarios pull them in
    via {!Jsip_scenario_runner.Bot_spec}. *)

module Cancel_storm = Cancel_storm
module Noise_trader = Noise_trader
