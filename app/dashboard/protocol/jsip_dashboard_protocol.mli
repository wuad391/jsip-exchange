open! Core
open Jsip_exchange_stats

(** Wire protocol between the dashboard's native server and the browser.

    The server serves this one [Polling_state_rpc] over a websocket, and the
    browser polls it once per second. The response is the rolling window of
    per-second exchange snapshots, oldest first (see
    {!Jsip_dashboard.Window}), but only the snapshots a client is missing are
    sent on each poll — the diff-based transport keeps the wire small as
    snapshots grow. *)
val stats_rpc : (unit, Exchange_stats.t list) Polling_state_rpc.t
