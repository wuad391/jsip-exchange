open! Core
open Async_rpc_kernel
open Jsip_exchange_stats

(* The browser polls this plain RPC once per second (its [Rpc_effect] layer
   has no Pipe_rpc support, so we poll rather than stream). The response is
   the rolling window of per-second snapshots, oldest first — the same list
   [Jsip_dashboard.Dashboard_state] accumulates on the server. *)
let stats_rpc =
  Rpc.Rpc.create
    ~name:"dashboard-stats"
    ~version:1
    ~bin_query:[%bin_type_class: unit]
    ~bin_response:[%bin_type_class: Exchange_stats.t list]
    ~include_in_error_count:Rpc.How_to_recognize_errors.Only_on_exn
;;
