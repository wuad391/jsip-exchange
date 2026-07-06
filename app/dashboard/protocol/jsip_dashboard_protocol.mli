open! Core
open Async_rpc_kernel
open Jsip_exchange_stats

(** Wire protocol between the dashboard's native server and the browser.

    The server serves this one plain RPC over a websocket, and the browser
    polls it once per second. The response is the rolling window of
    per-second exchange snapshots, oldest first — the same list
    {!Jsip_dashboard.Dashboard_state} accumulates. It is a plain RPC rather
    than a {!Async_rpc_kernel.Rpc.Pipe_rpc} because the browser's
    [Rpc_effect] layer polls rather than streams. *)
val stats_rpc : (unit, Exchange_stats.t list) Rpc.Rpc.t
