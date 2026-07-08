open! Core
module Scenario = Scenario

(* Ex4 phase 1: every scenario implementation traded in Symbol.t names, which
   phase 1 removes from the live path entirely. Restoring them is phase 2
   work, once the symbol directory lets names come back. Until then the
   registry is empty rather than broken. *)
let all : (module Scenario.S) list = []

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
