open! Core
module Vdom = Virtual_dom.Vdom

(* A dependency-free line chart. We build the SVG as raw markup and inject it
   with [Vdom.Node.inner_html], so the browser's own parser creates real,
   correctly-namespaced SVG shapes. Going through [Vdom.Node.create_svg] plus
   generic string attributes does NOT paint the geometry in this virtual_dom
   (SVG geometry needs [Virtual_dom_svg]'s typed attrs) -- injecting the markup
   sidesteps that entirely and is what fixed the "black rectangle" panes.

   Each series is a (stroke-color-hex, values-oldest-first) pair; all series
   share one y-scale (0 -> max across every series). Values map into a padded
   band so a flat-at-zero line rests just above the baseline instead of being
   clipped on the bottom edge. Pass [~area] to fill under the first series. *)

let pad = 6.

let line_chart
  ?(width = 260)
  ?(height = 88)
  ?(area = false)
  (series : (string * float list) list)
  =
  let w = Float.of_int width in
  let h = Float.of_int height in
  let max_len =
    List.fold series ~init:0 ~f:(fun acc (_, v) -> Int.max acc (List.length v))
  in
  let max_y =
    List.concat_map series ~f:snd
    |> List.fold ~init:0. ~f:Float.max
    |> fun m -> if Float.(m <= 0.) then 1. else m
  in
  let plot = h -. (2. *. pad) in
  let x_of i =
    if max_len <= 1
    then w
    else Float.of_int i /. Float.of_int (max_len - 1) *. w
  in
  let y_of value = h -. pad -. (value /. max_y *. plot) in
  let base_y = y_of 0. in
  let points values =
    match values with
    | [ only ] ->
      let y = y_of only in
      [%string "0,%{y#Float} %{w#Float},%{y#Float}"]
    | _ ->
      List.mapi values ~f:(fun i v ->
        let x = x_of i in
        let y = y_of v in
        [%string "%{x#Float},%{y#Float}"])
      |> String.concat ~sep:" "
  in
  let baseline =
    [%string
      "<line x1='0' y1='%{base_y#Float}' x2='%{w#Float}' \
       y2='%{base_y#Float}' stroke='#243044' stroke-width='1' \
       vector-effect='non-scaling-stroke'/>"]
  in
  let area_markup =
    if not area
    then ""
    else (
      match series with
      | (color, (_ :: _ :: _ as values)) :: _ ->
        let poly =
          [%string
            "0,%{base_y#Float} %{points values} %{w#Float},%{base_y#Float}"]
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
            "<polyline points='%{points values}' fill='none' \
             stroke='%{color}' stroke-width='2' stroke-linecap='round' \
             stroke-linejoin='round' vector-effect='non-scaling-stroke'/>"])
    |> String.concat
  in
  let svg =
    [%string
      "<svg viewBox='0 0 %{width#Int} %{height#Int}' \
       preserveAspectRatio='none' \
       style='width:100%;height:%{height#Int}px;display:block;background:#0b0f17;border:1px \
       solid #1b2334;border-radius:6px'>%{baseline}%{area_markup}%{lines}</svg>"]
  in
  Vdom.Node.inner_html
    ~tag:"div"
    ~attrs:[ Vdom.Attr.create "style" "width:100%" ]
    ~this_html_is_sanitized_and_is_totally_safe_trust_me:svg
    ()
;;
