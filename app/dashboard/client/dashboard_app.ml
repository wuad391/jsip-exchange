open! Core
module Vdom = Virtual_dom.Vdom
module Display = Jsip_dashboard.Dashboard_state.Display

(* The thin render layer — the analog of [app/monitor]'s [Term_app]. Every
   number is already computed in [Dashboard_state.display]; each [render_*]
   helper just maps one pane of that [Display.t] onto Vdom nodes. Styling is
   inline (no ppx_css dependency): [attr "style" ...] on plain nodes. *)

let attr = Vdom.Attr.create
let style s = attr "style" s

(* Palette — a dark console, tuned so the four latency lines stay legible on
   the same axis. *)
let bg = "#0d1117"
let panel_bg = "#161b22"
let border = "#30363d"
let fg = "#c9d1d9"
let muted = "#8b949e"
let color_live = "#3fb950"
let color_heap = "#58a6ff"
let color_p50 = "#8b949e"
let color_p90 = "#d29922"
let color_p99 = "#f85149"
let color_max = "#bc8cff"
let color_occupancy = "#58a6ff"
let color_loop = "#d29922"

let text ?(color = fg) ?(size = "13px") ?(weight = "400") s =
  Vdom.Node.create
    "span"
    ~attrs:
      [ style
          [%string "color:%{color};font-size:%{size};font-weight:%{weight}"]
      ]
    [ Vdom.Node.text s ]
;;

let d1 x = Float.to_string_hum x ~decimals:1 ~strip_zero:false

let fmt_mb mb = [%string "%{d1 mb} MB"]

let fmt_us us =
  if Float.(us >= 1000.)
  then [%string "%{d1 (us /. 1000.)} ms"]
  else [%string "%{Float.iround_nearest_exn us#Int} µs"]
;;

let panel ~title children =
  Vdom.Node.div
    ~attrs:
      [ style
          [%string
            "background:%{panel_bg};border:1px solid %{border};border-radius:8px;padding:12px;display:flex;flex-direction:column;gap:8px"]
      ]
    (text ~size:"14px" ~weight:"600" title :: children)
;;

let tile ~label ~value =
  Vdom.Node.div
    ~attrs:[ style "display:flex;flex-direction:column;gap:2px" ]
    [ text ~color:muted ~size:"11px" label
    ; text ~size:"16px" ~weight:"600" value
    ]
;;

let tiles cells =
  Vdom.Node.div
    ~attrs:[ style "display:flex;gap:16px;flex-wrap:wrap" ]
    cells
;;

let render_memory (d : Display.t) =
  panel
    ~title:"Process memory"
    [ Svg_chart.line_chart
        [ color_live, d.live_mb_series; color_heap, d.heap_mb_series ]
    ; tiles
        [ tile ~label:"live" ~value:(fmt_mb d.live_mb)
        ; tile ~label:"heap" ~value:(fmt_mb d.heap_mb)
        ; tile ~label:"peak" ~value:(fmt_mb d.peak_mb)
        ; tile ~label:"minor GC/s" ~value:(Int.to_string d.gc_minor_per_sec)
        ; tile ~label:"major GC/s" ~value:(Int.to_string d.gc_major_per_sec)
        ]
    ]
;;

let render_latency ~title (l : Display.latency) =
  panel
    ~title
    [ Svg_chart.line_chart
        [ color_p50, l.p50_series
        ; color_p90, l.p90_series
        ; color_p99, l.p99_series
        ; color_max, l.max_series
        ]
    ; tiles
        [ tile ~label:"p50" ~value:(fmt_us l.p50_us)
        ; tile ~label:"p90" ~value:(fmt_us l.p90_us)
        ; tile ~label:"p99" ~value:(fmt_us l.p99_us)
        ; tile ~label:"max" ~value:(fmt_us l.max_us)
        ; tile ~label:"per sec" ~value:(Int.to_string l.per_sec)
        ]
    ]
;;

let render_participants (rows : Display.participant_row list) =
  let columns = "display:grid;grid-template-columns:1fr auto auto;gap:12px" in
  let header =
    Vdom.Node.div
      ~attrs:[ style columns ]
      [ text ~color:muted ~size:"11px" "participant"
      ; text ~color:muted ~size:"11px" "orders/s"
      ; text ~color:muted ~size:"11px" "resting"
      ]
  in
  let row (r : Display.participant_row) =
    Vdom.Node.div
      ~attrs:[ style columns ]
      [ text r.name
      ; text (Int.to_string r.orders_per_sec)
      ; text (Int.to_string r.resting_orders)
      ]
  in
  panel
    ~title:"Per-participant order rate"
    (match rows with
     | [] -> [ text ~color:muted "(no participants yet)" ]
     | _ -> header :: List.map rows ~f:row)
;;

let render_occupancy (rows : Display.occupancy_row list) =
  let row (r : Display.occupancy_row) =
    Vdom.Node.div
      ~attrs:[ style "display:flex;flex-direction:column;gap:4px" ]
      [ Vdom.Node.div
          ~attrs:[ style "display:flex;justify-content:space-between;gap:8px" ]
          [ text r.label
          ; text
              ~color:muted
              ~size:"11px"
              [%string
                "max %{r.max_depth#Int} · total %{r.total_depth#Int} · \
                 %{r.num_pipes#Int} pipes"]
          ]
      ; Svg_chart.line_chart ~height:28 [ color_occupancy, r.max_depth_series ]
      ]
  in
  panel ~title:"Pipe occupancy" (List.map rows ~f:row)
;;

let render_loop (d : Display.t) =
  panel
    ~title:"Matching-loop busy"
    [ Svg_chart.line_chart [ color_loop, d.loop_busy_series ]
    ; tiles
        [ tile ~label:"current" ~value:(fmt_us d.loop_busy_us)
        ; tile ~label:"sample #" ~value:(Int.to_string d.seq)
        ]
    ]
;;

let grid children =
  Vdom.Node.div
    ~attrs:
      [ style
          "display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px"
      ]
    children
;;

let view (display : Display.t option) =
  let body =
    match display with
    | None ->
      [ text ~color:muted "Connecting to the dashboard server…" ]
    | Some d ->
      [ grid
          [ render_memory d
          ; render_latency ~title:"Submit latency (enqueue → matched)" d.submit
          ; render_latency ~title:"Cancel latency" d.cancel
          ; render_participants d.participants
          ; render_occupancy d.occupancy
          ; render_loop d
          ]
      ]
  in
  Vdom.Node.div
    ~attrs:
      [ style
          [%string
            "background:%{bg};color:%{fg};min-height:100vh;padding:16px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;display:flex;flex-direction:column;gap:12px"]
      ]
    (text ~size:"18px" ~weight:"700" "JSIP exchange — live monitor" :: body)
;;
