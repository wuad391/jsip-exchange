open! Core
open Jsip_types
open Jsip_exchange_stats
open Async_rpc_kernel

(* The browser polls this [Polling_state_rpc] once a second. It carries the
   rolling window of per-second snapshots, but between polls only the
   snapshots the client is missing cross the wire (see
   [Jsip_dashboard.Window]), so the transport scales to larger snapshots
   without re-sending the whole window each time. Bonsai's [Rpc_effect] can
   poll this directly. *)
let stats_rpc =
  Polling_state_rpc.create
    ~name:"dashboard-stats"
    ~version:1
    ~query_equal:[%equal: unit]
    ~bin_query:[%bin_type_class: unit]
    (module Jsip_dashboard.Window : Polling_state_rpc.Response
      with type t = Exchange_stats.t list)
;;

(* The second poll, on the same websocket: the bounded buffer of recent audit
   events for the live feed. Same diff-based transport as [stats_rpc], so
   only events newer than the client's cross the wire; the client holds all
   symbols' events and filters by tab locally (see
   [Jsip_dashboard.Event_window]). *)
let feed_rpc =
  Polling_state_rpc.create
    ~name:"dashboard-feed"
    ~version:1
    ~query_equal:[%equal: unit]
    ~bin_query:[%bin_type_class: unit]
    (module Jsip_dashboard.Event_window : Polling_state_rpc.Response
      with type t = (int * Exchange_event.t) list)
;;

(* Fetched once by the browser at startup — a one-shot [Rpc.Rpc], not a poll:
   the tradable set is fixed for the server's lifetime. The dashboard server
   relays the exchange's own [(id, name)] directory straight through, and the
   browser mirrors it to resolve ids to names ([AAPL] instead of [0]) in the
   books pane and event feed, exactly as the native client and terminal
   monitor do. The wire everywhere else stays int-only. *)
let symbol_directory_rpc =
  Rpc.Rpc.create
    ~name:"dashboard-symbol-directory"
    ~version:1
    ~bin_query:Unit.bin_t
    ~bin_response:[%bin_type_class: (Symbol_id.t * Symbol.t) list]
    ~include_in_error_count:Rpc.How_to_recognize_errors.Only_on_exn
;;
