open! Core
open Jsip_types

(** A monomorphized cousin of {!Aug_table}: keys are [Price.t] and the cached
    measure is hardcoded to the largest key present ([combine = Price.max],
    [identity = Price.zero]). There is no first-class [Arg] module and
    nothing is stored as a closure, so the key comparison and the measure
    combine are the statically-known [Price.compare]/[Price.max].

    It exists to isolate one cost: how much {!Aug_table}'s generic,
    closure-based ordering and monoid add on the write path. The node layout
    is identical to {!Aug_table}'s (the same six fields), so a speed
    difference between the two is the price of genericity alone, with node
    size held fixed. (Because [Price.t] is [int] cents, keys stay unboxed;
    only [Price.compare]/[Price.max] — [Comparable.Make]-generated direct
    calls rather than [int] primitives — separate this from an [int]-keyed
    version.)

    Prices are assumed non-negative, so [Price.zero] is a valid max-monoid
    identity. For this particular measure {!max_key} is really the rightmost
    node, so a plain map's [max_elt] would get it in O(log n) without
    caching; the point here is the monomorphization, not the measure. *)

type 'data t

val empty : 'data t
val is_empty : _ t -> bool

(** Number of entries. O(1). *)
val length : _ t -> int

(** The largest key present, or [Price.zero] when empty. O(1) — the cached
    root measure. *)
val max_key : _ t -> Price.t

(** The entry with the smallest key, or [None] if empty. O(log n) — a
    left-spine walk. *)
val min_elt : 'data t -> (Price.t * 'data) option

(** The entry with the largest key, or [None] if empty. O(log n) — a
    right-spine walk. Prefer {!max_key} (O(1)) when you only need the key;
    use this when you also need the data resting at that key. *)
val max_elt : 'data t -> (Price.t * 'data) option

(** [set t ~key ~data] adds [key -> data], replacing any existing binding.
    O(log n). *)
val set : 'data t -> key:Price.t -> data:'data -> 'data t

(** [remove t key] drops [key] if present. O(log n). *)
val remove : 'data t -> Price.t -> 'data t

(** [find t key] is the data bound to [key], or [None]. O(log n). *)
val find : 'data t -> Price.t -> 'data option

val mem : _ t -> Price.t -> bool

(** Fold over entries in increasing key order. O(n). *)
val fold
  :  'data t
  -> init:'acc
  -> f:(key:Price.t -> data:'data -> 'acc -> 'acc)
  -> 'acc

val to_alist : 'data t -> (Price.t * 'data) list
