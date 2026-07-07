open! Core
open Bonsai_web
module Dashboard_state = Jsip_dashboard.Dashboard_state

(* The dashboard's browser half. It polls the native server's window RPC once a
   second, reconstructs the render state from the polled window, and draws the
   panes. All the numeric work lives in [Dashboard_state.display]; this file is
   just the Bonsai glue. It mirrors [app/monitor]'s split (pure state + thin UI
   layer) — including the [let%map.Bonsai] idiom — diverging only where it must:
   it polls a [Polling_state_rpc] rather than draining a Pipe_rpc, because the
   browser's [Rpc_effect] has no Pipe_rpc support. The poll is diff-based, so
   only the newly-arrived snapshots cross the wire each second. *)

let poll_interval = Time_ns.Span.of_sec 1.

let app (local_ graph) =
  let window =
    Rpc_effect.Polling_state_rpc.poll
      Jsip_dashboard_protocol.stats_rpc
      ~equal_query:[%equal: unit]
      ~every:(Bonsai.return poll_interval)
      ~output_type:Rpc_effect.Poll_result.Output_type.Last_ok_response
      (Bonsai.return ())
      graph
  in
  let%map.Bonsai window = window in
  window
  |> Option.map ~f:(fun snapshots ->
    Dashboard_state.display (Dashboard_state.of_snapshots snapshots))
  |> Dashboard_app.view
;;

let () = Bonsai_web.Start.start app
