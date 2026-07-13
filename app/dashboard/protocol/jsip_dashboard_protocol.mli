open! Core
open Jsip_types
open Jsip_exchange_stats
open Async_rpc_kernel

(** Wire protocol between the dashboard's native server and the browser.

    The server serves these [Polling_state_rpc]s over a websocket, and the
    browser polls them once per second. Each response is a rolling window,
    but only the entries a client is missing are sent on each poll — the
    diff-based transport keeps the wire small as the windows grow. *)

(** The rolling window of per-second exchange snapshots, oldest first (see
    {!Jsip_dashboard.Window}). Feeds the six health-metric panes. *)
val stats_rpc : (unit, Exchange_stats.t list) Polling_state_rpc.t

(** The bounded buffer of the most recent audit events, oldest first, each
    tagged with a server-assigned monotonic id (see
    {!Jsip_dashboard.Event_window}). Feeds the live event feed pane; the
    client holds every symbol's events and filters by tab locally, so
    switching symbols is instant. *)
val feed_rpc : (unit, (int * Exchange_event.t) list) Polling_state_rpc.t

(** The exchange's symbol directory: the [(id, name)] pairs mapping each wire
    {!Jsip_types.Symbol_id.t} to its human-readable {!Jsip_types.Symbol.t}.
    Fetched once at startup (the tradable set is fixed for the server's
    lifetime), the browser mirrors it locally to render names instead of ids
    in the books pane and event feed. The dashboard server relays it straight
    from the exchange; the wire otherwise stays int-only. *)
val symbol_directory_rpc : (unit, (Symbol_id.t * Symbol.t) list) Rpc.Rpc.t
