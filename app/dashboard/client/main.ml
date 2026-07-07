open! Core
open Bonsai_web
module Dashboard_state = Jsip_dashboard.Dashboard_state

(* The dashboard's browser half. It polls the native server's window RPCs
   once a second, reconstructs the render state from the polled windows, and
   draws the panes. All the numeric work lives in [Dashboard_state.display];
   this file is just the Bonsai glue. It mirrors [app/monitor]'s split (pure
   state + thin UI layer) — including the [let%map.Bonsai] idiom — diverging
   only where it must: it polls [Polling_state_rpc]s rather than draining
   Pipe_rpcs, because the browser's [Rpc_effect] has no Pipe_rpc support. The
   polls are diff-based, so only newly-arrived data crosses the wire each
   second.

   A second poll ([feed_rpc]) drives the live event feed, and a bit of
   [Bonsai.state] holds which symbol tab is selected — the feed's events are
   filtered against it in [Feed_pane], so switching tabs needs no re-fetch. *)

let poll_interval = Time_ns.Span.of_sec 1.

let poll rpc (local_ graph) =
  Rpc_effect.Polling_state_rpc.poll
    rpc
    ~equal_query:[%equal: unit]
    ~every:(Bonsai.return poll_interval)
    ~output_type:Rpc_effect.Poll_result.Output_type.Last_ok_response
    (Bonsai.return ())
    graph
;;

let app (local_ graph) =
  let window = poll Jsip_dashboard_protocol.stats_rpc graph in
  let feed = poll Jsip_dashboard_protocol.feed_rpc graph in
  let selected, set_selected =
    Bonsai.state
      Feed_pane.Selection.All
      ~sexp_of_model:[%sexp_of: Feed_pane.Selection.t]
      ~equal:[%equal: Feed_pane.Selection.t]
      graph
  in
  let%map.Bonsai window and feed and selected and set_selected in
  let display =
    Option.map window ~f:(fun snapshots ->
      Dashboard_state.display (Dashboard_state.of_snapshots snapshots))
  in
  let feed =
    Feed_pane.view
      ~events:(Option.value feed ~default:[])
      ~selected
      ~on_select:set_selected
  in
  Dashboard_app.view ~feed display
;;

let () = Bonsai_web.Start.start app
