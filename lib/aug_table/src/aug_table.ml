open! Core

module type Arg = sig
  type key
  type data
  type measure

  val compare_key : key -> key -> int
  val identity : measure
  val combine : measure -> measure -> measure
  val measure_of_entry : key:key -> data:data -> measure
end

(* A weight-balanced binary search tree. Every [Node] caches two aggregates
   over its whole subtree:

   - [size]: the number of entries. It drives rebalancing (this is a
     {e weight}-balanced tree) and makes [length] O(1).
   - [measure]: [Arg.combine] folded over every entry's measure in key order.
     The root's [measure] is thus the measure of the entire table, which is
     what makes [measure] O(1).

   Both are computed in exactly one place — [create] — so every operation
   that builds nodes through it inherits correct augmentation for free. *)
type ('key, 'data, 'measure) node =
  | Empty
  | Node of
      { left : ('key, 'data, 'measure) node
      ; key : 'key
      ; data : 'data
      ; right : ('key, 'data, 'measure) node
      ; size : int
      ; measure : 'measure
      }

(* We keep the ordering and the measure monoid as plain closures, pulled out
   of the [Arg] module once in [empty]. This mirrors Core's own
   [Comparator.t] (also a record of functions) and sidesteps the fact that
   OCaml cannot unpack a first-class module whose type still has free
   variables. *)
type ('key, 'data, 'measure) t =
  { root : ('key, 'data, 'measure) node
  ; compare_key : 'key -> 'key -> int
  ; identity : 'measure
  ; combine : 'measure -> 'measure -> 'measure
  ; measure_of_entry : key:'key -> data:'data -> 'measure
  }

let size : _ node -> int = function Empty -> 0 | Node { size; _ } -> size

(* The measure of a subtree: [identity] for an empty one, else its cached
   value. Used both by the public [measure] and by [create]. *)
let measure_of_node ~identity : _ node -> _ = function
  | Empty -> identity
  | Node { measure; _ } -> measure
;;

(* [create left key data right] assembles one node from two subtrees that are
   already balanced with respect to each other, computing its cached [size]
   and [measure]. It does NOT rebalance — that is [balance]'s job.

   This is the single point where augmentation is maintained: every other
   operation (rotations, [set], [remove]) builds nodes through here, so
   getting the cached values right here keeps them right everywhere. *)
let create
  ~(measure_of_entry : key:'key -> data:'data -> 'measure)
  ~(combine : 'measure -> 'measure -> 'measure)
  ~(identity : 'measure)
  (left : ('key, 'data, 'measure) node)
  (key : 'key)
  (data : 'data)
  (right : ('key, 'data, 'measure) node)
  : ('key, 'data, 'measure) node
  =
  let size = size left + 1 + size right in
  (* [measure] mirrors [size]: a node's cached value is a function of its
     children's cached values plus its own entry. Combine in left-to-right
     key order — left subtree, this entry, right subtree — because [combine]
     need not be commutative. *)
  let measure =
    combine
      (combine
         (measure_of_node ~identity left)
         (measure_of_entry ~key ~data))
      (measure_of_node ~identity right)
  in
  Node { left; key; data; right; size; measure }
;;

(* The four rotations, each rebuilding through [create] so the cached fields
   are recomputed. The [assert false] arms are shapes the caller guarantees
   cannot occur (the heavy side always has the child being rotated up). *)

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

(* Weight-balance constants (Nievergelt–Reingold / Adams), the same pair used
   by Haskell's [Data.Map]: a subtree may be at most [balance_delta] times
   heavier than its sibling, and [balance_ratio] decides single vs. double
   rotation. These are load-bearing — don't retune them by guesswork. *)
let balance_delta = 3
let balance_ratio = 2

(* [balance] is [create] plus a repair step: if one child ended up more than
   [balance_delta] times heavier than the other (as happens after a single
   insert or delete), rotate to restore the weight invariant. *)
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

let empty
  (type key data measure)
  (arg :
    (module Arg
       with type key = key
        and type data = data
        and type measure = measure))
  : (key, data, measure) t
  =
  let (module A) = arg in
  { root = Empty
  ; compare_key = A.compare_key
  ; identity = A.identity
  ; combine = A.combine
  ; measure_of_entry = A.measure_of_entry
  }
;;

let is_empty t = match t.root with Empty -> true | Node _ -> false
let length t = size t.root
let measure t = measure_of_node ~identity:t.identity t.root

let set t ~key ~data =
  let create =
    create
      ~measure_of_entry:t.measure_of_entry
      ~combine:t.combine
      ~identity:t.identity
  in
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
  let create =
    create
      ~measure_of_entry:t.measure_of_entry
      ~combine:t.combine
      ~identity:t.identity
  in
  let balance = balance ~create in
  (* Detach the leftmost entry of a non-empty subtree. *)
  let rec remove_min = function
    | Empty -> assert false
    | Node { left = Empty; key = k; data = d; right; _ } -> k, d, right
    | Node { left; key = k; data = d; right; _ } ->
      let min_key, min_data, left = remove_min left in
      min_key, min_data, balance left k d right
  in
  (* Merge two subtrees whose keys straddle a just-removed key. *)
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
