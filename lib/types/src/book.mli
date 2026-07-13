(** A read-only snapshot of an order book.

    Contains the symbol, all resting price levels on each side (aggregated by
    price), and the BBO. *)

open! Core

type t =
  { symbol : Symbol_id.t
  ; bids : Level.t list
  ; asks : Level.t list
  ; bbo : Bbo.t
  }
[@@deriving sexp, bin_io]

(** Render the book as multi-line text; the header prints the raw
    {!Symbol_id.t}. A caller that wants the human name has a directory and
    prints the name itself before this — [Book] stays int-only. *)
val to_string : t -> string
