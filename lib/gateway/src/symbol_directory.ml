open! Core
open Jsip_types

(* [id_to_name] is indexed by the raw id (dense, [0 .. n-1]), so id->name is
   a bounds check and an array index — no hashing, mirroring how the engine
   indexes its books. [name_to_id] is the reverse map for parse-time lookup,
   where the key is a string and a hash is unavoidable (but parsing runs at
   human-typing speed, so it never matters). *)
type t =
  { id_to_name : Symbol.t array
  ; name_to_id : Symbol_id.t Symbol.Map.t
  }

(* The ordered name list already determines both fields, so the sexp is just
   that list — [id_to_name] with the id being each name's position. *)
let sexp_of_t t : Sexp.t =
  [%sexp (Array.to_list t.id_to_name : Symbol.t list)]
;;

let of_names names =
  let id_to_name = Array.of_list names in
  let name_to_id =
    List.mapi names ~f:(fun i name -> name, Symbol_id.of_int i)
    |> Symbol.Map.of_alist_exn
  in
  { id_to_name; name_to_id }
;;

let num_symbols t = Array.length t.id_to_name

let name t id =
  let i = Symbol_id.to_int id in
  if i >= 0 && i < Array.length t.id_to_name
  then Some t.id_to_name.(i)
  else None
;;

let id t name = Map.find t.name_to_id name

let to_alist t =
  Array.to_list t.id_to_name
  |> List.mapi ~f:(fun i name -> Symbol_id.of_int i, name)
;;

let of_alist pairs =
  pairs
  |> List.sort ~compare:(fun (a, _) (b, _) -> Symbol_id.compare a b)
  |> List.map ~f:snd
  |> of_names
;;
