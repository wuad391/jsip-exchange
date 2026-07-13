(** A small integer identifier for a trading symbol.

    [Symbol_id.t] is the wire-facing counterpart to {!Symbol.t}: where
    [Symbol.t] is a human-readable ticker validated at the edges,
    [Symbol_id.t] is what actually crosses the wire and indexes the matching
    engine's order books. It carries no name — recovering a ticker from an id
    is a consumer concern (a symbol directory), not something this module
    does; [to_string] only ever prints the int.

    Ids are assigned once, by enumerating a fixed count of symbols an
    exchange trades (see {!Jsip_order_book.Matching_engine.create}) — unlike
    {!Order_id.t} or {!Client_order_id.t}, there is no [Generator]: nothing
    mints a fresh [Symbol_id.t] at runtime. *)

open! Core

type t = private int [@@deriving sexp, bin_io, compare, equal, hash, string]

val to_int : t -> int

(** Raises if [n] is negative. This is the only invariant [Symbol_id.t]
    itself can enforce — this module has no way to know how many symbols a
    given exchange trades, so it cannot reject an id that is merely out of
    range for one particular engine. That check happens where the range is
    known: see {!Jsip_order_book.Matching_engine.book}. [of_string] shares
    this same check (and additionally rejects non-numeric input). *)
val of_int : int -> t

include Comparable.S with type t := t
include Hashable.S with type t := t
