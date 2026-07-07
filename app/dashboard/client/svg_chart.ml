open! Core
module Vdom = Virtual_dom.Vdom

(* A dependency-free line chart drawn as an inline SVG. Each series is a
   (stroke-color, values-oldest-first) pair; all series share one y-scale (0 to
   the max value across every series) so their lines are directly comparable.
   The [viewBox] stretches to the container via [preserveAspectRatio="none"],
   and [vector-effect] keeps the stroke crisp despite that stretch. *)

let attr = Vdom.Attr.create

let line_chart ?(width = 260) ?(height = 64) (series : (string * float list) list)
  =
  let max_len =
    List.fold series ~init:0 ~f:(fun acc (_, values) ->
      Int.max acc (List.length values))
  in
  let max_y =
    List.concat_map series ~f:snd
    |> List.fold ~init:0. ~f:Float.max
    |> fun m -> if Float.(m <= 0.) then 1. else m
  in
  let coord i value =
    let x =
      if max_len <= 1
      then 0.
      else Float.of_int i /. Float.of_int (max_len - 1) *. Float.of_int width
    in
    (* SVG y grows downward, so a larger value sits higher (smaller y). *)
    let y = Float.of_int height -. (value /. max_y *. Float.of_int height) in
    [%string "%{x#Float},%{y#Float}"]
  in
  let polyline (color, values) =
    match values with
    | [] -> None
    | _ ->
      let points = List.mapi values ~f:coord |> String.concat ~sep:" " in
      Some
        (Vdom.Node.create_svg
           "polyline"
           ~attrs:
             [ attr "points" points
             ; attr "fill" "none"
             ; attr "stroke" color
             ; attr "stroke-width" "1.5"
             ; attr "vector-effect" "non-scaling-stroke"
             ]
           [])
  in
  Vdom.Node.create_svg
    "svg"
    ~attrs:
      [ attr "viewBox" [%string "0 0 %{width#Int} %{height#Int}"]
      ; attr "preserveAspectRatio" "none"
      ; attr
          "style"
          [%string
            "width:100%;height:%{height#Int}px;display:block;background:#0d1117;border-radius:4px"]
      ]
    (List.filter_map series ~f:polyline)
;;
