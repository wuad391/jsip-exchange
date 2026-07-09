(** Glue that boots a scenario into a running exchange + ecosystem of bots. *)

open! Core
open! Async

(** Boot the exchange on [port], spin up the oracle/news/bots described by
    [config], and return a deferred that resolves only when the server is
    closed. The deferred for each bot's tick loop is leaked via
    [don't_wait_for].

    When [count_orders] is [true] (wired to the [-count-orders] flag), the
    runner tallies how many times bots call [submit] and [cancel] over the
    whole run and prints the totals at shutdown — the empirical "how often"
    to pair with the order-book benchmarks' "how expensive". *)
val run
  :  ?count_orders:bool
  -> Scenario_config.t
  -> port:int
  -> seed:int
  -> unit Deferred.t
