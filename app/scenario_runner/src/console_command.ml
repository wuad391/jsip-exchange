open! Core
open Jsip_types
open Jsip_symbol_directory

module Verb = struct
  type t =
    | Spawn
    | Kill
    | Crash
    | List
    | Kinds
    | Help
    | Quit
  [@@deriving string ~case_insensitive, enumerate]

  let all_str = String.concat (List.map all ~f:to_string) ~sep:", "
end

type t =
  | Spawn of
      { kind : string
      ; name : string option
      ; symbols : Symbol_id.t list
      ; knobs : (string * int) list
      }
  | Kill of string
  | Crash of string
  | List_bots
  | Kinds
  | Help
  | Quit
[@@deriving sexp_of]

let spawn_usage =
  "expected: SPAWN <kind> [<name>] [<SYMBOL>...] [key=value ...]"
;;

(* Mirrors [Exchange_command.parse]'s symbol handling: with a [directory] the
   token is a human name resolved to its id; without one it is the raw id. *)
let resolve_symbol ~directory symbol_str =
  match directory with
  | None ->
    (match Int.of_string_opt symbol_str with
     | Some id when id >= 0 -> Ok (Symbol_id.of_int id)
     | Some _ | None ->
       Or_error.error_string [%string "invalid symbol: %{symbol_str}"])
  | Some directory ->
    (match Or_error.try_with (fun () -> Symbol.of_string symbol_str) with
     | Error _ ->
       Or_error.error_string [%string "invalid symbol: %{symbol_str}"]
     | Ok name ->
       (match Symbol_directory.id directory name with
        | Some id -> Ok id
        | None ->
          let known =
            Symbol_directory.names directory
            |> List.map ~f:Symbol.to_string
            |> String.concat ~sep:", "
          in
          Or_error.error_string
            [%string "unknown symbol %{symbol_str} (known: %{known})"]))
;;

let parse_knob token =
  match String.lsplit2 token ~on:'=' with
  | None -> None
  | Some (key, value_str) ->
    let knob =
      if String.is_empty key
      then Or_error.error_string [%string "knob with no name: %{token}"]
      else (
        match Int.of_string_opt value_str with
        | Some value -> Ok (key, value)
        | None ->
          Or_error.error_string
            [%string
              "knob %{key} needs an integer value, got \"%{value_str}\""])
    in
    Some knob
;;

let spawn_parse ~directory rest =
  match rest with
  | [] -> Or_error.error_string spawn_usage
  | kind :: rest ->
    let open Result.Let_syntax in
    (* Tokens are classified in order: knobs must be trailing; the first bare
       token that fails to resolve as a symbol is the name; any later bare
       token must be a symbol (so its resolution error surfaces). *)
    let rec loop ~name ~symbols_rev ~knobs_rev = function
      | [] ->
        Ok
          (Spawn
             { kind
             ; name
             ; symbols = List.rev symbols_rev
             ; knobs = List.rev knobs_rev
             })
      | token :: rest ->
        (match parse_knob token with
         | Some knob_result ->
           let%bind knob = knob_result in
           loop ~name ~symbols_rev ~knobs_rev:(knob :: knobs_rev) rest
         | None ->
           if not (List.is_empty knobs_rev)
           then
             Or_error.error_string
               [%string
                 "%{token} comes after a key=value knob — knobs must be the \
                  last tokens on the line"]
           else (
             match resolve_symbol ~directory token with
             | Ok symbol ->
               loop
                 ~name
                 ~symbols_rev:(symbol :: symbols_rev)
                 ~knobs_rev
                 rest
             | Error error ->
               (match name, symbols_rev with
                | None, [] ->
                  loop ~name:(Some token) ~symbols_rev ~knobs_rev rest
                | Some _, _ | _, _ :: _ -> Error error)))
    in
    loop ~name:None ~symbols_rev:[] ~knobs_rev:[] rest
;;

(* The target is the rest of the line (whitespace collapsed to single spaces)
   because scenario bots log in under names with spaces, e.g.
   ["Market Maker"]. *)
let target_parse rest ~verb ~make =
  match rest with
  | [] -> Or_error.error_string [%string "expected: %{verb} <bot name>"]
  | _ :: _ -> Ok (make (String.concat rest ~sep:" "))
;;

let parse ?directory line =
  let parts =
    String.split (String.strip line) ~on:' '
    |> List.map ~f:String.strip
    |> List.filter ~f:(Fn.non String.is_empty)
  in
  match parts with
  | [] -> Or_error.error_string "empty command"
  | verb :: rest ->
    (match Or_error.try_with (fun () -> Verb.of_string verb) with
     | Error _ ->
       Or_error.error_string
         [%string
           "unknown command %{verb#String} (expected %{Verb.all_str#String})"]
     | Ok Verb.Spawn -> spawn_parse ~directory rest
     | Ok Kill ->
       target_parse rest ~verb:"KILL" ~make:(fun name -> Kill name)
     | Ok Crash ->
       target_parse rest ~verb:"CRASH" ~make:(fun name -> Crash name)
     | Ok List -> Ok List_bots
     | Ok Kinds -> Ok Kinds
     | Ok Help -> Ok Help
     | Ok Quit -> Ok Quit)
;;
