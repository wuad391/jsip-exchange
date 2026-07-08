open! Core
open Jsip_types
open Jsip_exchange_stats

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
