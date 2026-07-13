open! Core
open Jsip_types

module Knob = struct
  type t =
    { name : string
    ; doc : string
    ; default : int
    }
end

module Entry = struct
  type t =
    { kind : string
    ; doc : string
    ; knobs : Knob.t list
    ; make :
        participant:Participant.t
        -> symbols:Symbol_id.t list
        -> knobs:int String.Map.t
        -> rng_seed:int
        -> Bot_spec.t Or_error.t
    }

  let find entries ~kind =
    match
      List.find entries ~f:(fun entry ->
        String.Caseless.equal entry.kind kind)
    with
    | Some entry -> Ok entry
    | None ->
      let known =
        List.map entries ~f:(fun entry -> entry.kind)
        |> String.concat ~sep:", "
      in
      Or_error.error_string
        [%string "unknown bot kind %{kind} (known: %{known})"]
  ;;

  let resolve_knobs entry ~overrides =
    let defaults =
      List.map entry.knobs ~f:(fun { Knob.name; default; doc = _ } ->
        name, default)
      |> String.Map.of_alist_exn
    in
    List.fold_result overrides ~init:defaults ~f:(fun acc (key, value) ->
      if Map.mem acc key
      then Ok (Map.set acc ~key ~data:value)
      else (
        let known =
          List.map entry.knobs ~f:(fun (knob : Knob.t) -> knob.name)
          |> String.concat ~sep:", "
        in
        Or_error.error_string
          [%string "%{entry.kind} has no knob %{key} (knobs: %{known})"]))
  ;;
end
