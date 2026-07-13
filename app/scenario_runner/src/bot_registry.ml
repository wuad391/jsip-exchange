open! Core
open Jsip_types

type t = Bot_handle.t Participant.Table.t

let create () = Participant.Table.create ()

let add t (handle : Bot_handle.t) =
  match Hashtbl.add t ~key:handle.participant ~data:handle with
  | `Ok -> Ok ()
  | `Duplicate ->
    Or_error.error_s
      [%message
        "a bot with this name is already running"
          ~name:(handle.participant : Participant.t)]
;;

let find t participant = Hashtbl.find t participant
let mem t participant = Hashtbl.mem t participant
let remove t participant = Hashtbl.find_and_remove t participant

let all t =
  Hashtbl.data t
  |> List.sort ~compare:(fun (a : Bot_handle.t) b ->
    Participant.compare a.participant b.participant)
;;
