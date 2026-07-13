open! Core

module type Arg = sig
  type key

  val compare_key : key -> key -> int
  val identity : key
  val combine : key -> key -> key
end

(* A weight-balanced binary search tree, exactly like {!Aug_table}, with one
   simplification: the measure is a monoid over the {e keys} themselves, so
   the cached [measure] has the same type as [key] and a single entry's
   measure is just its key. That removes the separate ['measure] type and the
   [measure_of_entry] closure that {!Aug_table} carries — this module exists
   to measure what those two cost.

   Each [Node] still caches [size] (for rebalancing and O(1) [length]) and
   [measure] ([combine] folded over every key in the subtree, in key order),
   both maintained in the one place they are built: [create]. *)
type ('key, 'data) node =
  | Empty
  | Node of
      { left : ('key, 'data) node
      ; key : 'key
      ; data : 'data
      ; right : ('key, 'data) node
      ; size : int
      ; measure : 'key
      }

(* As in {!Aug_table}, the ordering and the monoid are plain closures pulled
   out of [Arg] once in [empty]; there is simply no [measure_of_entry] to
   carry, so the record is one field smaller. *)
type ('key, 'data) t =
  { root : ('key, 'data) node
  ; compare_key : 'key -> 'key -> int
  ; identity : 'key
  ; combine : 'key -> 'key -> 'key
  }

let size : _ node -> int = function Empty -> 0 | Node { size; _ } -> size

let measure_of_node ~identity : _ node -> _ = function
  | Empty -> identity
  | Node { measure; _ } -> measure
;;

(* The single point where augmentation is maintained. The only line that
   differs from {!Aug_table.create} is the middle term of [measure]: a node's
   own contribution is its [key] directly, where {!Aug_table} would evaluate
   [measure_of_entry ~key ~data]. Combine in left-to-right key order, since
   [combine] need not be commutative. *)
let create
  ~(combine : 'key -> 'key -> 'key)
  ~(identity : 'key)
  (left : ('key, 'data) node)
  (key : 'key)
  (data : 'data)
  (right : ('key, 'data) node)
  : ('key, 'data) node
  =
  let size = size left + 1 + size right in
  let measure =
    combine
      (combine (measure_of_node ~identity left) key)
      (measure_of_node ~identity right)
  in
  Node { left; key; data; right; size; measure }
;;

(* The four rotations, each rebuilding through [create] so the cached fields
   are recomputed. Identical to {!Aug_table}: they never mention the measure. *)

let single_left ~create l k v r =
  match r with
  | Empty -> assert false
  | Node { left = rl; key = rk; data = rd; right = rr; _ } ->
    create (create l k v rl) rk rd rr
;;

let single_right ~create l k v r =
  match l with
  | Empty -> assert false
  | Node { left = ll; key = lk; data = ld; right = lr; _ } ->
    create ll lk ld (create lr k v r)
;;

let double_left ~create l k v r =
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

let double_right ~create l k v r =
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

let balance ~create left key data right =
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
      then single_left ~create left key data right
      else double_left ~create left key data right)
  else if sl > balance_delta * sr
  then (
    match left with
    | Empty -> assert false
    | Node { left = ll; right = lr; _ } ->
      if size lr < balance_ratio * size ll
      then single_right ~create left key data right
      else double_right ~create left key data right)
  else create left key data right
;;

(* Only [key] is fixed by [Arg]; ['data] stays free (an empty tree holds no
   data), so like {!Core.Map.empty} the result is polymorphic in data. *)
let empty (type key) (arg : (module Arg with type key = key)) : (key, _) t =
  let (module A) = arg in
  { root = Empty
  ; compare_key = A.compare_key
  ; identity = A.identity
  ; combine = A.combine
  }
;;

let is_empty t = match t.root with Empty -> true | Node _ -> false
let length t = size t.root
let measure t = measure_of_node ~identity:t.identity t.root

let set t ~key ~data =
  let create = create ~combine:t.combine ~identity:t.identity in
  let rec go = function
    | Empty -> create Empty key data Empty
    | Node { left; key = k; data = d; right; _ } ->
      (match Ordering.of_int (t.compare_key key k) with
       | Less -> balance ~create (go left) k d right
       | Greater -> balance ~create left k d (go right)
       | Equal -> create left key data right)
  in
  { t with root = go t.root }
;;

let remove t key =
  let create = create ~combine:t.combine ~identity:t.identity in
  let balance = balance ~create in
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
      (match Ordering.of_int (t.compare_key key k) with
       | Less -> balance (go left) k d right
       | Greater -> balance left k d (go right)
       | Equal -> glue left right)
  in
  { t with root = go t.root }
;;

let find t key =
  let rec go = function
    | Empty -> None
    | Node { left; key = k; data; right; _ } ->
      (match Ordering.of_int (t.compare_key key k) with
       | Less -> go left
       | Greater -> go right
       | Equal -> Some data)
  in
  go t.root
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
  go init t.root
;;

let to_alist t =
  fold t ~init:[] ~f:(fun ~key ~data acc -> (key, data) :: acc) |> List.rev
;;
