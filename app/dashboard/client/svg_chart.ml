open! Core
module Vdom = Virtual_dom.Vdom

(* Dependency-free line chart, built as raw SVG markup and injected with
   [Vdom.Node.inner_html] so the browser parses it into real SVG shapes.

   Coordinates are emitted as INTEGERS: [Float.to_string] renders e.g. [130.]
   with a trailing dot, which the SVG [points] parser rejects ("Expected
   number") -- that malformed number, not the node-construction approach, is
   what left every chart blank. A fixed 1000x300 internal [viewBox] gives the
   integers enough resolution; [preserveAspectRatio='none'] stretches it to
   the container.

   Each series is a (stroke-color-hex, values-oldest-first) pair; all series
   share one y-scale (0 -> max across every series), mapped into a padded band
   so a flat-at-zero line stays just above the baseline. Pass [~area] to fill
   translucently under the first series.

   A subtle left gutter carries a few grey y-axis ticks (max, mid, 0) so the
   curve's height reads as a magnitude, not just a shape. The viewBox is
   stretched with [preserveAspectRatio='none'], which would distort SVG text,
   so the ticks are HTML placed in a gutter beside the SVG. The [pad] band is
   what makes their percentage positions line up with the plot: the max value
   sits at [pad/vb_h] of the height, zero at [1 - pad/vb_h], and -- because the
   band is symmetric -- the midpoint value lands dead center. *)

let vb_w = 1000.
let vb_h = 300.
let pad = 18.
let coord f = Int.to_string (Float.iround_nearest_exn f)

(* Compact, unit-agnostic tick text. Latency maxima run into the millions of
   microseconds under load, so collapse thousands/millions to [k]/[M] to keep
   the gutter narrow; the pane's own tiles carry the exact units. *)
let d1 x = Float.to_string_hum x ~decimals:1 ~strip_zero:true ~delimiter:','

let axis_label value =
  let magnitude = Float.abs value in
  if Float.(magnitude >= 1_000_000.)
  then [%string "%{d1 (value /. 1_000_000.)}M"]
  else if Float.(magnitude >= 1_000.)
  then [%string "%{d1 (value /. 1_000.)}k"]
  else d1 value
;;

(* Fraction of the height, top-down, where [pad] maps the max/zero extremes. *)
let top_frac = pad /. vb_h

(* Subtle greys: the tick text and the faint horizontal rules behind the plot. *)
let axis_ink = "#5f6e86"
let gridline_ink = "#182233"
let gutter_width_px = 38

let line_chart
  ?(height = 88)
  ?(area = false)
  (series : (string * float list) list)
  =
  let max_len =
    List.fold series ~init:0 ~f:(fun acc (_, v) -> Int.max acc (List.length v))
  in
  let max_y =
    List.concat_map series ~f:snd
    |> List.fold ~init:0. ~f:Float.max
    |> fun m -> if Float.(m <= 0.) then 1. else m
  in
  let plot = vb_h -. (2. *. pad) in
  let x_of i =
    if max_len <= 1
    then vb_w
    else Float.of_int i /. Float.of_int (max_len - 1) *. vb_w
  in
  let y_of value = vb_h -. pad -. (value /. max_y *. plot) in
  let base_y = coord (y_of 0.) in
  let right = coord vb_w in
  (* Tick positions as [(top_fraction, value)], top to bottom. A tall chart
     gets a midpoint; a short sparkline gets only max and zero so the labels do
     not collide. *)
  let ticks =
    if height >= 50
    then [ top_frac, max_y; 0.5, max_y /. 2.; 1. -. top_frac, 0. ]
    else [ top_frac, max_y; 1. -. top_frac, 0. ]
  in
  let points values =
    match values with
    | [ only ] ->
      let y = coord (y_of only) in
      [%string "0,%{y} %{right},%{y}"]
    | _ ->
      List.mapi values ~f:(fun i v ->
        let x = coord (x_of i) in
        let y = coord (y_of v) in
        [%string "%{x},%{y}"])
      |> String.concat ~sep:" "
  in
  let baseline =
    [%string
      "<line x1='0' y1='%{base_y}' x2='%{right}' y2='%{base_y}' stroke='#243044' stroke-width='1' vector-effect='non-scaling-stroke'/>"]
  in
  (* Faint rules at the non-zero ticks (zero already has the baseline), so each
     gutter label connects to a line across the plot. *)
  let gridlines =
    List.filter_map ticks ~f:(fun (_frac, value) ->
      if Float.(value <= 0.)
      then None
      else (
        let y = coord (y_of value) in
        Some
          [%string
            "<line x1='0' y1='%{y}' x2='%{right}' y2='%{y}' stroke='%{gridline_ink}' stroke-width='1' vector-effect='non-scaling-stroke'/>"]))
    |> String.concat
  in
  let area_markup =
    if not area
    then ""
    else (
      match series with
      | (color, (_ :: _ :: _ as values)) :: _ ->
        let poly =
          [%string "0,%{base_y} %{points values} %{right},%{base_y}"]
        in
        [%string
          "<polygon points='%{poly}' fill='%{color}' fill-opacity='0.14'/>"]
      | [] | (_, ([] | [ _ ])) :: _ -> "")
  in
  let lines =
    List.filter_map series ~f:(fun (color, values) ->
      match values with
      | [] -> None
      | _ :: _ ->
        Some
          [%string
            "<polyline points='%{points values}' fill='none' stroke='%{color}' stroke-width='2' stroke-linecap='round' stroke-linejoin='round' vector-effect='non-scaling-stroke'/>"])
    |> String.concat
  in
  let svg =
    [%string
      "<svg viewBox='0 0 1000 300' preserveAspectRatio='none' style='width:100%;height:%{height#Int}px;display:block;background:#0b0f17;border:1px solid #1b2334;border-radius:6px'>%{gridlines}%{baseline}%{area_markup}%{lines}</svg>"]
  in
  let chart =
    Vdom.Node.inner_html
      ~tag:"div"
      ~attrs:[ Vdom.Attr.create "style" "flex:1;min-width:0" ]
      ~this_html_is_sanitized_and_is_totally_safe_trust_me:svg
      ()
  in
  (* Grey y-axis ticks in a narrow gutter left of the plot. Each is absolutely
     positioned by its height fraction so it lines up with [gridlines]; the
     flex row stretches the gutter to the SVG's pixel height. *)
  let tick_label (frac, value) =
    let top = Float.iround_nearest_exn (frac *. 100.) in
    Vdom.Node.create
      "span"
      ~attrs:
        [ Vdom.Attr.create
            "style"
            [%string
              "position:absolute;right:4px;top:%{top#Int}%;transform:translateY(-50%);font-size:10px;line-height:1;color:%{axis_ink};font-variant-numeric:tabular-nums;white-space:nowrap;pointer-events:none"]
        ]
      [ Vdom.Node.text (axis_label value) ]
  in
  let gutter =
    Vdom.Node.div
      ~attrs:
        [ Vdom.Attr.create
            "style"
            [%string "position:relative;width:%{gutter_width_px#Int}px;flex:none"]
        ]
      (List.map ticks ~f:tick_label)
  in
  Vdom.Node.div
    ~attrs:
      [ Vdom.Attr.create "style" "display:flex;align-items:stretch;width:100%" ]
    [ gutter; chart ]
;;
