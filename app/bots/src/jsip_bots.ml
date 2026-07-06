(** Student-written trading bots.

    Each bot is a {!Jsip_bot_runtime.Bot_runtime.Bot}; scenarios pull them in
    via {!Jsip_scenario_runner.Bot_spec}. *)

module Book_filler_sadat = Book_filler_sadat
module Bot_random = Bot_random
module Cancel_storm = Cancel_storm
module Momentum_trader_hansel = Momentum_trader_hansel
module Noise_trader = Noise_trader
module Slow_consumer = Slow_consumer
module Spammer = Spammer
