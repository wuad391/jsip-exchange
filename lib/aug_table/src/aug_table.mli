open! Core

(** A persistent ordered map that also maintains, in O(1), a running
    "measure" over all of its entries.

    This is the OCaml analogue of SML's augmented ordered table from 15-210
    ^-^. Internally it is a weight-balanced binary search tree in which every
    node caches the combined measure of its whole subtree. Because measures
    are combined by an associative operation with a unit (a monoid), the root
    node always holds the measure of the entire table — so {!measure} is O(1)
    instead of the O(n) you would pay to fold {!Core.Map}. (SML calls this
    [reduceVal].)

    The trade you are making: ordinary map operations ({!set}, {!remove},
    {!find}) stay O(log n), and each node costs one extra {!Arg.combine} when
    it is built plus one extra word of memory. You pay a constant on the
    write path to make the whole-table reduction free on the read path.

    Like {!Core.Map}, tables are persistent: every operation returns a new
    table that shares structure with the old one, so keeping an old version
    around is cheap.

    Example — a book of resting orders keyed by price, whose measure is the
    total resting size, so [measure book] is the O(1) total depth:
    {[
      module By_size = struct
        type key = Price.t
        type data = Order.t
        type measure = Size.t

        let compare_key = Price.compare
        let identity = Size.zero
        let combine = Size.( + )
        let measure_of_entry ~key:_ ~data:(order : Order.t) = order.size
      end

      let book = Aug_table.empty (module By_size)
      let book = Aug_table.set book ~key:price ~data:order
      let total_depth = Aug_table.measure book (* O(1) *)
    ]} *)

(** Describes how to order keys and how to measure and combine entries.

    [measure] must form a {e monoid} under [combine] and [identity]:
    - [combine] is associative:
      [combine (combine a b) c = combine a (combine b c)]
    - [identity] is a unit: [combine identity a = a = combine a identity]

    These laws are exactly what let a node cache one measure for its subtree
    regardless of how the tree happens to be balanced. If [combine] is not
    associative, the value returned by {!measure} is meaningless. *)
module type Arg = sig
  type key
  type data
  type measure

  val compare_key : key -> key -> int
  val identity : measure
  val combine : measure -> measure -> measure

  (** [measure_of_entry ~key ~data] is the measure of the single entry
      [key -> data]. *)
  val measure_of_entry : key:key -> data:data -> measure
end

type ('key, 'data, 'measure) t

(** [empty (module Arg)] is a table with no entries that orders keys and
    combines measures as [Arg] describes. *)
val empty
  :  (module Arg
        with type key = 'key
         and type data = 'data
         and type measure = 'measure)
  -> ('key, 'data, 'measure) t

val is_empty : (_, _, _) t -> bool

(** Number of entries. O(1). *)
val length : (_, _, _) t -> int

(** The combined measure of every entry (or [Arg.identity] when empty). O(1)
    — this is the whole point of the structure. *)
val measure : (_, _, 'measure) t -> 'measure

(** [set t ~key ~data] adds [key -> data], replacing any existing binding for
    [key]. O(log n). *)
val set
  :  ('key, 'data, 'm) t
  -> key:'key
  -> data:'data
  -> ('key, 'data, 'm) t

(** [remove t key] drops the binding for [key] if present, and is [t]
    unchanged otherwise. O(log n). *)
val remove : ('key, 'data, 'm) t -> 'key -> ('key, 'data, 'm) t

(** [find t key] is the data bound to [key], or [None]. O(log n). *)
val find : ('key, 'data, _) t -> 'key -> 'data option

val mem : ('key, _, _) t -> 'key -> bool

(** Fold over entries in increasing key order. O(n). *)
val fold
  :  ('key, 'data, _) t
  -> init:'acc
  -> f:(key:'key -> data:'data -> 'acc -> 'acc)
  -> 'acc

(** All entries in increasing key order. O(n). Handy for tests and printing,
    since [t] itself is not [sexp]-derivable (it carries its [Arg]). *)
val to_alist : ('key, 'data, _) t -> ('key * 'data) list
