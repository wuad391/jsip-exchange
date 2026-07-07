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
   translucently under the first series. *)

let vb_w = 1000.
let vb_h = 300.
let pad = 18.
let coord f = Int.to_string (Float.iround_nearest_exn f)

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
      "<svg viewBox='0 0 1000 300' preserveAspectRatio='none' style='width:100%;height:%{height#Int}px;display:block;background:#0b0f17;border:1px solid #1b2334;border-radius:6px'>%{baseline}%{area_markup}%{lines}</svg>"]
  in
  Vdom.Node.inner_html
    ~tag:"div"
    ~attrs:[ Vdom.Attr.create "style" "width:100%" ]
    ~this_html_is_sanitized_and_is_totally_safe_trust_me:svg
    ()
;;
