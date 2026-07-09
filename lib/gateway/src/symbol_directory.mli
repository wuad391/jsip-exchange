(** A bijection between human-readable {!Jsip_types.Symbol.t} names and the
    wire-facing {!Jsip_types.Symbol_id.t} ids the exchange runs on.

    Ex4 phase 2: the exchange is int-only end to end (see {!Jsip_types.Symbol_id}
    and the phase-1 work); this directory is the one place names and ids meet.
    It is authoritative in the server's [main] (built from the ordered symbol
    set the server trades, so a symbol's position in that list is its id,
    matching {!Jsip_order_book.Matching_engine.create}), and served to clients
    over {!Rpc_protocol.symbol_directory_rpc}. Each client mirrors it locally to
    resolve names at parse time and ids at render time. [lib/types] stays
    int-only; names live only here, at the edges — which is why this lives in
    the gateway, not in [lib/types]. *)

open! Core
open Jsip_types

type t [@@deriving sexp_of]

(** Build the authoritative directory from the ordered names the exchange
    trades: the name at position [i] gets id [i]. Raises on a duplicate name. *)
val of_names : Symbol.t list -> t

(** The [(id, name)] pairs in id order — what {!Rpc_protocol.symbol_directory_rpc}
    serves. *)
val to_alist : t -> (Symbol_id.t * Symbol.t) list

(** Rebuild a directory from the pairs served over the wire — the inverse of
    {!to_alist}, used by a client mirroring the server's registry. *)
val of_alist : (Symbol_id.t * Symbol.t) list -> t

(** The name for an id, or [None] if the id is not one this directory knows. *)
val name : t -> Symbol_id.t -> Symbol.t option

(** The id for a name, or [None] if the name is not one this directory trades. *)
val id : t -> Symbol.t -> Symbol_id.t option

(** How many symbols the directory covers (ids [0 .. num_symbols - 1]). *)
val num_symbols : t -> int
