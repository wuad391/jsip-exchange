open! Core
module Scenario = Scenario

let all : (module Scenario.S) list = [ (module Calm_day) ]

let all_names =
  List.map all ~f:(fun (module S : Scenario.S) -> S.name)
  |> List.sort ~compare:String.compare
;;

let find_by_name name =
  match
    List.find all ~f:(fun (module S : Scenario.S) ->
      String.equal S.name name)
  with
  | Some s -> Ok s
  | None ->
    Or_error.error_s
      [%message
        "unknown scenario"
          ~given:(name : string)
          ~known:(all_names : string list)]
;;
