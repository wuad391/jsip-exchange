open! Core
module Vdom = Virtual_dom.Vdom

(* A dependency-free line chart drawn as inline SVG. Each series is a
   (stroke-color, values-oldest-first) pair; all series share one y-scale
   (0 -> the max value across every series). Values map into a padded band so a
   flat-at-zero line rests just above the baseline rather than being clipped on
   the bottom edge -- the bug that made idle panes look like black rectangles.
   Pass [~area] to fill translucently under the first series.
   [preserveAspectRatio="none"] stretches the [viewBox] to the container;
   [vector-effect] keeps strokes crisp despite that stretch. *)

let attr = Vdom.Attr.create
let svg = Vdom.Node.create_svg
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
  let line_points values =
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
    svg
      "line"
      ~attrs:
        [ attr "x1" "0"
        ; attr "y1" [%string "%{base_y#Float}"]
        ; attr "x2" [%string "%{w#Float}"]
        ; attr "y2" [%string "%{base_y#Float}"]
        ; attr "stroke" "#243044"
        ; attr "stroke-width" "1"
        ; attr "vector-effect" "non-scaling-stroke"
        ]
      []
  in
  let area_node =
    if not area
    then None
    else (
      match series with
      | (color, values) :: _ when List.length values >= 2 ->
        let poly =
          [%string "0,%{base_y#Float} "]
          ^ line_points values
          ^ [%string " %{w#Float},%{base_y#Float}"]
        in
        Some
          (svg
             "polygon"
             ~attrs:
               [ attr "points" poly
               ; attr "fill" color
               ; attr "fill-opacity" "0.14"
               ; attr "stroke" "none"
               ]
             [])
      | [] | (_, _) :: _ -> None)
  in
  let polyline (color, values) =
    match values with
    | [] -> None
    | _ :: _ ->
      Some
        (svg
           "polyline"
           ~attrs:
             [ attr "points" (line_points values)
             ; attr "fill" "none"
             ; attr "stroke" color
             ; attr "stroke-width" "2"
             ; attr "stroke-linejoin" "round"
             ; attr "stroke-linecap" "round"
             ; attr "vector-effect" "non-scaling-stroke"
             ]
           [])
  in
  svg
    "svg"
    ~attrs:
      [ attr "viewBox" [%string "0 0 %{width#Int} %{height#Int}"]
      ; attr "preserveAspectRatio" "none"
      ; attr
          "style"
          [%string
            "width:100%;height:%{height#Int}px;display:block;background:#0b0f17;border:1px solid #1b2334;border-radius:6px"]
      ]
    (baseline :: (Option.to_list area_node @ List.filter_map series ~f:polyline))
;;
