open! Core
module Vdom = Virtual_dom.Vdom
module Display = Jsip_dashboard.Dashboard_state.Display

(* The thin render layer -- the analog of [app/monitor]'s [Term_app]. Every
   number is already computed in [Dashboard_state.display]; each [render_*]
   helper maps one pane of that [Display.t] onto Vdom nodes. Styling is inline
   ([attr "style" ...]); each pane carries its own accent color so the six
   panes read apart at a glance, and that accent tints the pane's headline
   numbers. *)

let attr = Vdom.Attr.create
let style s = attr "style" s

(* Page + surfaces. *)
let bg = "#0b0f17"
let panel_bg = "#121826"
let border = "#243044"
let fg = "#e6edf3"
let muted = "#93a4bd"

(* One accent per pane. *)
let c_memory = "#3fb950"
let c_submit = "#58a6ff"
let c_cancel = "#f0883e"
let c_parts = "#bc8cff"
let c_occupancy = "#39c5cf"
let c_loop = "#e3b341"

(* Series colors within a pane. *)
let color_live = "#3fb950"
let color_heap = "#58a6ff"
let color_p50 = "#93a4bd"
let color_p90 = "#e3b341"
let color_p99 = "#f85149"
let color_max = "#bc8cff"

let text ?(color = fg) ?(size = "13px") ?(weight = "400") s =
  Vdom.Node.create
    "span"
    ~attrs:
      [ style [%string "color:%{color};font-size:%{size};font-weight:%{weight}"]
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

(* A colored swatch + label, used as a chart legend. *)
let legend items =
  Vdom.Node.div
    ~attrs:[ style "display:flex;gap:12px;flex-wrap:wrap" ]
    (List.map items ~f:(fun (color, label) ->
       Vdom.Node.div
         ~attrs:[ style "display:flex;align-items:center;gap:4px" ]
         [ Vdom.Node.create
             "span"
             ~attrs:
               [ style
                   [%string
                     "width:8px;height:8px;border-radius:2px;background:%{color}"]
               ]
             []
         ; text ~color:muted ~size:"11px" label
         ]))
;;

let panel ~accent ~title children =
  Vdom.Node.div
    ~attrs:
      [ style
          [%string
            "background:%{panel_bg};border:1px solid %{border};border-top:2px solid %{accent};border-radius:8px;padding:12px;display:flex;flex-direction:column;gap:8px;min-height:0;overflow:auto"]
      ]
    (text ~color:accent ~size:"13px" ~weight:"700" title :: children)
;;

let tile ?(color = fg) ~label ~value () =
  Vdom.Node.div
    ~attrs:[ style "display:flex;flex-direction:column;gap:2px" ]
    [ text ~color:muted ~size:"11px" label
    ; text ~color ~size:"16px" ~weight:"700" value
    ]
;;

let tiles cells =
  Vdom.Node.div
    ~attrs:[ style "display:flex;gap:16px;flex-wrap:wrap" ]
    cells
;;

let render_memory (d : Display.t) =
  panel
    ~accent:c_memory
    ~title:"Process memory"
    [ legend [ color_live, "live"; color_heap, "heap" ]
    ; Svg_chart.line_chart
        ~area:true
        [ color_live, d.live_mb_series; color_heap, d.heap_mb_series ]
    ; tiles
        [ tile ~color:color_live ~label:"live" ~value:(fmt_mb d.live_mb) ()
        ; tile ~color:color_heap ~label:"heap" ~value:(fmt_mb d.heap_mb) ()
        ; tile ~label:"peak" ~value:(fmt_mb d.peak_mb) ()
        ; tile ~label:"minor GC/s" ~value:(Int.to_string d.gc_minor_per_sec) ()
        ; tile ~label:"major GC/s" ~value:(Int.to_string d.gc_major_per_sec) ()
        ]
    ]
;;

let render_latency ~accent ~title (l : Display.latency) =
  panel
    ~accent
    ~title
    [ legend
        [ color_p50, "p50"
        ; color_p90, "p90"
        ; color_p99, "p99"
        ; color_max, "max"
        ]
    ; Svg_chart.line_chart
        [ color_p50, l.p50_series
        ; color_p90, l.p90_series
        ; color_p99, l.p99_series
        ; color_max, l.max_series
        ]
    ; tiles
        [ tile ~color:color_p50 ~label:"p50" ~value:(fmt_us l.p50_us) ()
        ; tile ~color:color_p90 ~label:"p90" ~value:(fmt_us l.p90_us) ()
        ; tile ~color:color_p99 ~label:"p99" ~value:(fmt_us l.p99_us) ()
        ; tile ~color:color_max ~label:"max" ~value:(fmt_us l.max_us) ()
        ; tile ~label:"per sec" ~value:(Int.to_string l.per_sec) ()
        ]
    ]
;;

let render_participants (rows : Display.participant_row list) =
  let th ~align s =
    Vdom.Node.create
      "th"
      ~attrs:
        [ style
            [%string
              "text-align:%{align};color:%{muted};font-size:11px;font-weight:600;padding:3px 6px;border-bottom:1px solid %{border}"]
        ]
      [ Vdom.Node.text s ]
  in
  let td ?(color = fg) ~align s =
    Vdom.Node.create
      "td"
      ~attrs:
        [ style
            [%string
              "text-align:%{align};color:%{color};font-size:13px;padding:3px 6px;font-variant-numeric:tabular-nums"]
        ]
      [ Vdom.Node.text s ]
  in
  let header =
    Vdom.Node.create
      "tr"
      ~attrs:[]
      [ th ~align:"left" "participant"
      ; th ~align:"right" "orders/s"
      ; th ~align:"right" "resting"
      ]
  in
  let row i (r : Display.participant_row) =
    let name_color = if i = 0 then c_parts else fg in
    Vdom.Node.create
      "tr"
      ~attrs:[]
      [ td ~color:name_color ~align:"left" r.name
      ; td ~color:c_parts ~align:"right" (Int.to_string r.orders_per_sec)
      ; td ~align:"right" (Int.to_string r.resting_orders)
      ]
  in
  panel
    ~accent:c_parts
    ~title:"Per-participant order rate"
    [ (match rows with
       | [] -> text ~color:muted "(no participants yet)"
       | _ :: _ ->
         Vdom.Node.create
           "table"
           ~attrs:[ style "width:100%;border-collapse:collapse" ]
           [ Vdom.Node.create "thead" ~attrs:[] [ header ]
           ; Vdom.Node.create "tbody" ~attrs:[] (List.mapi rows ~f:row)
           ])
    ]
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
      ; Svg_chart.line_chart ~height:28 [ c_occupancy, r.max_depth_series ]
      ]
  in
  panel
    ~accent:c_occupancy
    ~title:"Pipe occupancy"
    (match rows with
     | [] -> [ text ~color:muted "(no pipes yet)" ]
     | _ :: _ -> List.map rows ~f:row)
;;

let render_loop (d : Display.t) =
  panel
    ~accent:c_loop
    ~title:"Matching-loop busy"
    [ Svg_chart.line_chart ~area:true [ c_loop, d.loop_busy_series ]
    ; tiles
        [ tile ~color:c_loop ~label:"current" ~value:(fmt_us d.loop_busy_us) ()
        ; tile ~label:"sample #" ~value:(Int.to_string d.seq) ()
        ]
    ]
;;

let grid children =
  Vdom.Node.div
    ~attrs:
      [ style
          "display:grid;grid-template-columns:repeat(3,1fr);grid-template-rows:repeat(2,1fr);gap:12px;flex:1;min-height:0"
      ]
    children
;;

let view (display : Display.t option) =
  let header =
    Vdom.Node.div
      ~attrs:[ style "display:flex;align-items:center;gap:8px" ]
      [ Vdom.Node.create
          "span"
          ~attrs:
            [ style
                [%string
                  "width:10px;height:10px;border-radius:50%;background:%{c_memory}"]
            ]
          []
      ; text ~size:"18px" ~weight:"800" "JSIP exchange — live monitor"
      ]
  in
  let body =
    match display with
    | None -> [ text ~color:muted "Connecting to the dashboard server…" ]
    | Some d ->
      [ grid
          [ render_memory d
          ; render_latency
              ~accent:c_submit
              ~title:"Submit latency (enqueue → matched)"
              d.submit
          ; render_latency ~accent:c_cancel ~title:"Cancel latency" d.cancel
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
            "background:%{bg};color:%{fg};height:100vh;box-sizing:border-box;padding:16px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;display:flex;flex-direction:column;gap:12px"]
      ]
    (header :: body)
;;
