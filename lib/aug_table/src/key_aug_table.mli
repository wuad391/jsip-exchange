open! Core

(** A monomorphized cousin of {!Aug_table}: keys are [int] and the cached
    measure is hardcoded to the largest key present ([combine = Int.max],
    [identity = 0]). There is no first-class [Arg] module and nothing is
    stored as a closure, so the key comparison and the measure combine
    inline.

    It exists to isolate one cost: how much {!Aug_table}'s generic,
    closure-based ordering and monoid add on the write path. The node layout
    is identical to {!Aug_table}'s (the same six fields), so a speed
    difference between the two is the price of genericity alone, with node
    size held fixed.

    (For this particular measure, {!max_key} is really the rightmost node, so
    a plain map's [max_elt] would get it in O(log n) without caching. The
    point here is the monomorphization, not the measure.) *)

type 'data t

val empty : 'data t
val is_empty : _ t -> bool

(** Number of entries. O(1). *)
val length : _ t -> int

(** The largest key present, or 0 when empty. O(1) — the cached root measure. *)
val max_key : _ t -> int

(** [set t ~key ~data] adds [key -> data], replacing any existing binding.
    O(log n). *)
val set : 'data t -> key:int -> data:'data -> 'data t

(** [remove t key] drops [key] if present. O(log n). *)
val remove : 'data t -> int -> 'data t

(** [find t key] is the data bound to [key], or [None]. O(log n). *)
val find : 'data t -> int -> 'data option

val mem : _ t -> int -> bool

(** Fold over entries in increasing key order. O(n). *)
val fold
  :  'data t
  -> init:'acc
  -> f:(key:int -> data:'data -> 'acc -> 'acc)
  -> 'acc

val to_alist : 'data t -> (int * 'data) list
