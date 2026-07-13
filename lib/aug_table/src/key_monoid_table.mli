open! Core

(** {!Aug_table}, specialized so the measure is a monoid over the {e keys}.

    Where {!Aug_table} lets the measure be any type computed from each entry
    via [measure_of_entry ~key ~data], here the measure {e is} a key: the
    cached value has type ['key], and a single entry's contribution is just
    its own key. Choosing [combine] then picks what the O(1) {!measure}
    reports about the key set — [Int.max] gives the largest key, [Int.min]
    the smallest, [(+)] their sum, and so on.

    Keys stay polymorphic (supplied by [Arg], as in {!Aug_table}), so
    [compare_key] and [combine] are still closures. The two things this drops
    relative to {!Aug_table} are the separate ['measure] type and the
    per-node [measure_of_entry] call — the node layout is otherwise
    identical.

    The cost of that convenience is generality: because the measure sees only
    keys, you cannot aggregate over data here (e.g. summing an [Order.t]'s
    size). Reach for {!Aug_table} when the measure depends on the data, and
    for this when it depends only on the key.

    Example — smallest key currently present, in O(1):
    {[
      module Min_key = struct
        type key = int

        let compare_key = Int.compare
        let identity = Int.max_value
        let combine = Int.min
      end

      let t = Key_monoid_table.empty (module Min_key)
      let t = Key_monoid_table.set t ~key:5 ~data:"e"
      let t = Key_monoid_table.set t ~key:2 ~data:"b"
      let smallest = Key_monoid_table.measure t (* = 2, O(1) *)
    ]} *)

(** [combine]/[identity] must form a monoid over [key] (associative, with
    [identity] a unit), exactly as in {!Aug_table.Arg}; only
    [measure_of_entry] is gone, since an entry's measure is its key. *)
module type Arg = sig
  type key

  val compare_key : key -> key -> int
  val identity : key
  val combine : key -> key -> key
end

type ('key, 'data) t

(** [empty (module Arg)] is a table with no entries. Polymorphic in ['data]
    because an empty table holds none. *)
val empty : (module Arg with type key = 'key) -> ('key, 'data) t

val is_empty : (_, _) t -> bool

(** Number of entries. O(1). *)
val length : (_, _) t -> int

(** [combine] folded over every key present (or [Arg.identity] when empty).
    O(1) — the cached root measure. *)
val measure : ('key, _) t -> 'key

(** [set t ~key ~data] adds [key -> data], replacing any existing binding.
    O(log n). *)
val set : ('key, 'data) t -> key:'key -> data:'data -> ('key, 'data) t

(** [remove t key] drops the binding for [key] if present. O(log n). *)
val remove : ('key, 'data) t -> 'key -> ('key, 'data) t

(** [find t key] is the data bound to [key], or [None]. O(log n). *)
val find : ('key, 'data) t -> 'key -> 'data option

val mem : ('key, _) t -> 'key -> bool

(** Fold over entries in increasing key order. O(n). *)
val fold
  :  ('key, 'data) t
  -> init:'acc
  -> f:(key:'key -> data:'data -> 'acc -> 'acc)
  -> 'acc

val to_alist : ('key, 'data) t -> ('key * 'data) list
