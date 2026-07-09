open! Core

(* Identical in shape to Aug_table's node, but the cached measure is the
   maximum key (so it needs no [measure_of_entry]) and nothing is a closure. *)
type 'data node =
  | Empty
  | Node of
      { left : 'data node
      ; key : int
      ; data : 'data
      ; right : 'data node
      ; size : int
      ; max_key : int
      }

(* No closures to carry, so unlike Aug_table the tree needs no wrapper record
   — [t] is the root node itself. *)
type 'data t = 'data node

let size = function Empty -> 0 | Node { size; _ } -> size
let max_key_of = function Empty -> 0 | Node { max_key; _ } -> max_key

(* Smart constructor. Because the measure is the max key, [Int.max] is
   written inline here rather than called through a closure — this is the
   whole difference from Aug_table's [create]. *)
let create left key data right =
  let size = size left + 1 + size right in
  let max_key = Int.max (Int.max (max_key_of left) key) (max_key_of right) in
  Node { left; key; data; right; size; max_key }
;;

let single_left l k v r =
  match r with
  | Empty -> assert false
  | Node { left = rl; key = rk; data = rd; right = rr; _ } ->
    create (create l k v rl) rk rd rr
;;

let single_right l k v r =
  match l with
  | Empty -> assert false
  | Node { left = ll; key = lk; data = ld; right = lr; _ } ->
    create ll lk ld (create lr k v r)
;;

let double_left l k v r =
  match r with
  | Node
      { left = Node { left = rll; key = rlk; data = rld; right = rlr; _ }
      ; key = rk
      ; data = rd
      ; right = rr
      ; _
      } ->
    create (create l k v rll) rlk rld (create rlr rk rd rr)
  | Empty | Node { left = Empty; _ } -> assert false
;;

let double_right l k v r =
  match l with
  | Node
      { left = ll
      ; key = lk
      ; data = ld
      ; right = Node { left = lrl; key = lrk; data = lrd; right = lrr; _ }
      ; _
      } ->
    create (create ll lk ld lrl) lrk lrd (create lrr k v r)
  | Empty | Node { right = Empty; _ } -> assert false
;;

let balance_delta = 3
let balance_ratio = 2

let balance left key data right =
  let sl = size left
  and sr = size right in
  if sl + sr <= 1
  then create left key data right
  else if sr > balance_delta * sl
  then (
    match right with
    | Empty -> assert false
    | Node { left = rl; right = rr; _ } ->
      if size rl < balance_ratio * size rr
      then single_left left key data right
      else double_left left key data right)
  else if sl > balance_delta * sr
  then (
    match left with
    | Empty -> assert false
    | Node { left = ll; right = lr; _ } ->
      if size lr < balance_ratio * size ll
      then single_right left key data right
      else double_right left key data right)
  else create left key data right
;;

let empty = Empty
let is_empty = function Empty -> true | Node _ -> false
let length t = size t
let max_key t = max_key_of t

let set t ~key ~data =
  let rec go = function
    | Empty -> create Empty key data Empty
    | Node { left; key = k; data = d; right; _ } ->
      (match Ordering.of_int (Int.compare key k) with
       | Less -> balance (go left) k d right
       | Greater -> balance left k d (go right)
       | Equal -> create left key data right)
  in
  go t
;;

let remove t key =
  let rec remove_min = function
    | Empty -> assert false
    | Node { left = Empty; key = k; data = d; right; _ } -> k, d, right
    | Node { left; key = k; data = d; right; _ } ->
      let min_key, min_data, left = remove_min left in
      min_key, min_data, balance left k d right
  in
  let glue left right =
    match left, right with
    | Empty, t | t, Empty -> t
    | _ ->
      let k, d, right = remove_min right in
      balance left k d right
  in
  let rec go = function
    | Empty -> Empty
    | Node { left; key = k; data = d; right; _ } ->
      (match Ordering.of_int (Int.compare key k) with
       | Less -> balance (go left) k d right
       | Greater -> balance left k d (go right)
       | Equal -> glue left right)
  in
  go t
;;

let find t key =
  let rec go = function
    | Empty -> None
    | Node { left; key = k; data; right; _ } ->
      (match Ordering.of_int (Int.compare key k) with
       | Less -> go left
       | Greater -> go right
       | Equal -> Some data)
  in
  go t
;;

let mem t key = Option.is_some (find t key)

let fold t ~init ~f =
  let rec go acc = function
    | Empty -> acc
    | Node { left; key; data; right; _ } ->
      let acc = go acc left in
      let acc = f ~key ~data acc in
      go acc right
  in
  go init t
;;

let to_alist t =
  fold t ~init:[] ~f:(fun ~key ~data acc -> (key, data) :: acc) |> List.rev
;;
