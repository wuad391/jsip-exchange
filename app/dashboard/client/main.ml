open! Core
open Bonsai_web
open Bonsai.Let_syntax
module Dashboard_state = Jsip_dashboard.Dashboard_state
module Exchange_stats = Jsip_exchange_stats.Exchange_stats

(* The dashboard's browser half. It polls the native server's window RPCs on a
   short interval, reconstructs the render state from the polled windows, and
   draws the panes. All the numeric work lives in [Dashboard_state.display];
   this file is just the Bonsai glue. It mirrors [app/monitor]'s split (pure
   state + thin UI layer) — including the [let%map.Bonsai] idiom — diverging
   only where it must: it polls [Polling_state_rpc]s rather than draining
   Pipe_rpcs, because the browser's [Rpc_effect] has no Pipe_rpc support. The
   polls are diff-based, so only newly-arrived data crosses the wire each
   poll.

   A second poll ([feed_rpc]) drives the live event feed, and a bit of
   [Bonsai.state] holds which symbol tab is selected — the feed's events are
   filtered against it in [Feed_pane], so switching tabs needs no re-fetch.
   That feed poll is gated on [feed_visible]: collapsing the pane drops the
   poll out of the graph, so a hidden feed costs no polling at all — only the
   always-on stats poll keeps running. *)

let poll_interval = Time_ns.Span.of_sec 0.5

(* The monitor's *observed* refresh latency, shown in the header: the wall-clock
   gap between snapshots actually landing from the server. Unlike a static poll
   interval it moves — it sits near the sample interval when healthy and climbs
   when the monitor falls behind. Fed one [now] per snapshot arrival in [app]. *)
module Refresh_latency = struct
  type t =
    { last_arrival : Time_ns.t option
    ; ms : float
    }
  [@@deriving sexp_of, equal]

  let default = { last_arrival = None; ms = 0. }

  let observe (t : t) ~(now : Time_ns.t) =
    match t.last_arrival with
    | None -> { t with last_arrival = Some now }
    | Some previous ->
      let gap = Time_ns.Span.to_ms (Time_ns.diff now previous) in
      (* Light EMA so the readout is steady rather than flickering with jitter. *)
      let ms =
        if Float.(t.ms <= 0.) then gap else (0.6 *. t.ms) +. (0.4 *. gap)
      in
      { last_arrival = Some now; ms }
  ;;
end

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
  (* Feed one [now] into [Refresh_latency] each time a fresh snapshot lands
     ([seq] bumps), so the header shows the live refresh latency. *)
  let refresh, observe_arrival =
    Bonsai.state_machine
      ~sexp_of_model:[%sexp_of: Refresh_latency.t]
      ~sexp_of_action:[%sexp_of: Time_ns.t]
      ~default_model:Refresh_latency.default
      ~apply_action:(fun _ctx model now -> Refresh_latency.observe model ~now)
      graph
  in
  let latest_seq =
    let%arr window in
    match window with
    | None | Some [] -> -1
    | Some snapshots -> (List.last_exn snapshots).Exchange_stats.seq
  in
  Bonsai.Edge.on_change
    ~equal:[%equal: int]
    latest_seq
    ~callback:
      (let%arr observe_arrival
       and get_now = Bonsai.Clock.get_current_time graph in
       fun (_seq : int) ->
         let%bind.Effect now = get_now in
         observe_arrival now)
    graph;
  (* The feed poll lives inside the [feed_visible] branch, so collapsing the
     pane tears the poll down entirely — no feed traffic while hidden. *)
  let feed_visible, set_feed_visible = Bonsai.state' true graph in
  let feed =
    match%sub feed_visible with
    | true -> poll Jsip_dashboard_protocol.feed_rpc graph
    | false -> Bonsai.return None
  in
  let selected, set_selected =
    Bonsai.state
      Feed_pane.Selection.All
      ~sexp_of_model:[%sexp_of: Feed_pane.Selection.t]
      ~equal:[%equal: Feed_pane.Selection.t]
      graph
  in
  let%map.Bonsai window
  and feed
  and feed_visible
  and set_feed_visible
  and selected
  and set_selected
  and refresh in
  let display =
    Option.map window ~f:(fun snapshots ->
      Dashboard_state.display (Dashboard_state.of_snapshots snapshots))
  in
  let monitor_latency_ms =
    Float.iround_nearest_exn refresh.Refresh_latency.ms
  in
  let on_toggle_feed = set_feed_visible not in
  let feed_view =
    Feed_pane.view
      ~events:(Option.value feed ~default:[])
      ~selected
      ~on_select:set_selected
      ~on_collapse:on_toggle_feed
  in
  Dashboard_app.view
    ~feed:feed_view
    ~feed_visible
    ~on_toggle_feed
    ~monitor_latency_ms
    display
;;

let () = Bonsai_web.Start.start app
