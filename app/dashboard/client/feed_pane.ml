open! Core
open Jsip_types
module Vdom = Virtual_dom.Vdom
module Event_feed = Jsip_dashboard.Event_feed

(* The live event feed pane: a tab row (["All"] plus every symbol currently
   in the buffer) over a scrolling, newest-first list of colored event lines.
   The server ships events for all symbols; this pane filters by the selected
   tab locally, so switching symbols is instant. Kept in its own module so
   the edit to [Dashboard_app.view] stays a one-liner. Colors and surface
   tokens are redefined here (matching [dashboard_app.ml]) rather than
   shared, so this pane and the charts pane can evolve without colliding. *)

let attr = Vdom.Attr.create
let style s = attr "style" s

(* Surface + text tokens, matching [dashboard_app.ml]'s dark palette. *)
let page_bg = "#0b0f17"
let panel_bg = "#121826"
let border = "#243044"
let muted = "#93a4bd"
let accent = "#58a6ff"

module Selection = struct
  (* Which symbol's events the feed shows. [All] shows every event, including
     the (symbol-less) cancel rejects. *)
  type t =
    | All
    | Symbol of Symbol.t
  [@@deriving equal, sexp_of]

  let label = function
    | All -> "All"
    | Symbol symbol -> Symbol.to_string symbol
  ;;

  (* Does an event with this [row_symbol] belong under the current tab? *)
  let shows t (row_symbol : Symbol.t option) =
    match t, row_symbol with
    | All, _ -> true
    | Symbol _, None -> false
    | Symbol selected, Some symbol -> Symbol.equal selected symbol
  ;;
end

(* The distinct symbols present in the buffer, ascending — one tab each. *)
let symbols_present events =
  List.filter_map events ~f:(fun (_id, event) ->
    Event_feed.symbol_of_event event)
  |> Symbol.Set.of_list
  |> Set.to_list
;;

let tab ~selected ~on_select selection =
  let base =
    "cursor:pointer;font-size:12px;padding:2px \
     10px;border-radius:6px;user-select:none"
  in
  let skin =
    if Selection.equal selected selection
    then
      [%string
        "background:%{accent};color:%{page_bg};border:1px solid %{accent}"]
    else
      [%string
        "background:transparent;color:%{muted};border:1px solid %{border}"]
  in
  Vdom.Node.create
    "span"
    ~attrs:
      [ style [%string "%{base};%{skin}"]
      ; Vdom.Attr.on_click (fun _ev -> on_select selection)
      ]
    [ Vdom.Node.text (Selection.label selection) ]
;;

let tab_row ~selected ~on_select events =
  let tabs =
    tab ~selected ~on_select Selection.All
    :: List.map (symbols_present events) ~f:(fun symbol ->
      tab ~selected ~on_select (Selection.Symbol symbol))
  in
  Vdom.Node.div
    ~attrs:[ style "display:flex;gap:6px;flex-wrap:wrap;align-items:center" ]
    tabs
;;

let event_row (row : Event_feed.feed_row) =
  Vdom.Node.div
    ~attrs:
      [ style
          [%string
            "white-space:pre;font-size:12px;line-height:1.5;color:%{row.color}"]
      ]
    [ Vdom.Node.text row.text ]
;;

let event_list ~selected events =
  let rows =
    (* Newest first. The buffer is oldest-first, so reverse. *)
    List.rev events
    |> List.filter_map ~f:(fun (_id, event) ->
      if Selection.shows selected (Event_feed.symbol_of_event event)
      then Some (event_row (Event_feed.format event))
      else None)
  in
  Vdom.Node.div
    ~attrs:
      [ (* [scrollbar-width:none] hides the scrollbar while keeping the pane
           scrollable (supported by modern Chrome). *)
        style
          "flex:1;min-height:0;overflow:auto;scrollbar-width:none;display:flex;flex-direction:column;gap:1px"
      ]
    (match rows with
     | [] ->
       [ Vdom.Node.div
           ~attrs:[ style [%string "color:%{muted};font-size:12px"] ]
           [ Vdom.Node.text "(no events yet)" ]
       ]
     | _ :: _ -> rows)
;;

(* A small square button that collapses the feed to its rail; the [»] points
   the way the panel goes — off toward the right edge. *)
let collapse_button ~on_collapse =
  Vdom.Node.create
    "button"
    ~attrs:
      [ style
          [%string
            "margin-left:auto;cursor:pointer;width:20px;height:20px;flex:none;padding:0;display:flex;align-items:center;justify-content:center;background:transparent;color:%{muted};border:1px \
             solid \
             %{border};border-radius:5px;font-size:11px;font-family:inherit"]
      ; Vdom.Attr.on_click (fun _ev -> on_collapse)
      ]
    [ Vdom.Node.text "»" ]
;;

(* [events] is the polled buffer (oldest first). [selected] is the active
   tab; clicking a tab runs [on_select]; [on_collapse] hides the pane. *)
let view ~events ~selected ~on_select ~on_collapse =
  Vdom.Node.div
    ~attrs:
      [ style
          [%string
            "background:%{panel_bg};border:1px solid \
             %{border};border-top:2px solid \
             %{accent};border-radius:8px;padding:10px;display:flex;flex-direction:column;gap:8px;flex:1;min-height:0;font-family:ui-monospace,SFMono-Regular,Menlo,monospace"]
      ]
    [ Vdom.Node.div
        ~attrs:
          [ style "display:flex;align-items:center;gap:12px;flex-wrap:wrap" ]
        [ Vdom.Node.create
            "span"
            ~attrs:
              [ style
                  [%string "color:%{accent};font-size:13px;font-weight:700"]
              ]
            [ Vdom.Node.text "Live events" ]
        ; tab_row ~selected ~on_select events
        ; collapse_button ~on_collapse
        ]
    ; event_list ~selected events
    ]
;;
