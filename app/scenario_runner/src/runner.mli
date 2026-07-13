(** Glue that boots a scenario into a running exchange + ecosystem of bots. *)

open! Core
open! Async

(** Whole-run tally of how many times bots call [submit] and [cancel] (wired
    to the [-count-orders] flag) — the empirical "how often" to pair with the
    order-book benchmarks' "how expensive". *)
module Call_counts : sig
  type t

  val create : unit -> t
end

(** Bring up one bot against an already-running exchange: a fresh RPC
    connection, login, session-feed (and, per the spec, market-data)
    subscriptions, the event pump, and the tick loop. Returns the live
    {!Bot_handle.t} retaining all of it — or, if the exchange rejected the
    login (e.g. the name already has a session), closes the connection and
    returns the error. [counts], when given, tallies the bot's submit/cancel
    calls.

    The tick loop and event pump are additionally [don't_wait_for]'d so an
    escaping exception is routed to the enclosing monitor rather than
    silently parked in the handle. *)
val start_bot
  :  ?counts:Call_counts.t
  -> where_to_connect:Tcp.Where_to_connect.inet
  -> oracle:Jsip_fundamental.Fundamental_oracle.t
  -> Bot_spec.t
  -> Bot_handle.t Deferred.Or_error.t

(** Boot the exchange on [port], spin up the oracle/news/bots described by
    [config], and return a deferred that resolves only when the server is
    closed. Each scenario bot comes up via {!start_bot} and registers in a
    {!Bot_registry.t}, so the interactive console (the [-interactive] flag)
    can kill or crash scenario bots as well as ones it spawned.

    When [count_orders] is [true] (wired to the [-count-orders] flag), the
    runner tallies how many times bots call [submit] and [cancel] over the
    whole run and prints the totals at shutdown.

    When [interactive] is given (the [-interactive] flag), a {!Console} on
    stdin can spawn bots from that menu and kill or crash any running bot —
    including the scenario's own. The console's [quit] closes the server,
    which resolves the returned deferred. *)
val run
  :  ?count_orders:bool
  -> ?interactive:Bot_menu.Entry.t list
  -> Scenario_config.t
  -> port:int
  -> seed:int
  -> unit Deferred.t
