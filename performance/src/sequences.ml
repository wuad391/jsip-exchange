open! Core

module List_seq = struct
  (* [List] has no O(1) length, so we cache it alongside the backing list. *)
  type t =
    { mutable items : int list
    ; mutable length : int
    }

  let create () = { items = []; length = 0 }

  let set t ~key ~data =
    if key = t.length
    then (
      t.items <- t.items @ [ data ];
      t.length <- t.length + 1)
    else if key >= 0 && key < t.length
    then
      t.items
      <- List.mapi t.items ~f:(fun i x -> if i = key then data else x)
    else raise_s [%message "index out of range" (key : int) (t.length : int)]
  ;;

  let get t key = List.nth t.items key
end

module Dynarray_seq = struct
  type t = int Dynarray.t

  let create () = Dynarray.create ()

  let set t ~key ~data =
    if key = Dynarray.length t
    then Dynarray.add_last t data
    else Dynarray.set t key data
  ;;

  let get t key =
    if key >= 0 && key < Dynarray.length t
    then Some (Dynarray.get t key)
    else None
  ;;
end
