open! Core

type t [@@deriving sexp, bin_io, compare, equal, hash, string]

val to_int : t -> int
val of_int : int -> t

include Comparable.S with type t := t
include Hashable.S with type t := t

(** A source of fresh client order IDs for a single client. Each bot keeps
    one generator and pulls a new ID for every order it submits, giving it a
    predictable, collision-free namespace it can later use to cancel.

    IDs are handed out sequentially from [1]; a fresh generator is
    independent of every other, matching the per-participant scoping of {!t}. *)
module Generator : sig
  type order_id := t
  type t [@@deriving sexp_of]

  val create : unit -> t

  (** Return the next unused ID and advance the generator. *)
  val next : t -> order_id
end
