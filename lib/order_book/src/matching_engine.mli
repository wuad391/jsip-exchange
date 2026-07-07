(** The matching engine: receives order requests, manages order books, and
    produces exchange events.

    The engine is the heart of the exchange. It assigns order IDs, determines
    which orders can trade against each other, executes fills, and manages
    the lifecycle of resting orders. *)

open! Core
open Jsip_types

type t [@@deriving sexp_of]

(** Create a matching engine for the given symbols. Each symbol gets its own
    order book. *)
val create : Symbol.t list -> t

(** {2 Order submission} *)

(** Submit a new order request. Returns the list of exchange events produced:
    an acceptance or rejection, followed by any fills, and possibly a
    cancellation of unfilled remainder (for IOC orders).

    The event list is always non-empty (at minimum an acceptance or
    rejection). *)
val submit
  :  t
  -> participant:Participant.t
  -> Order.Request.t
  -> Exchange_event.t list

(** Cancels an existing order. Returns a list of exchange events: acceptance
    or rejection of cancel (canceled for reasons like nonexistent order),
    followed by any BBO updates *)
val cancel : t -> Order.Cancel.t -> Exchange_event.t list

(** {2 Queries} *)

(** The order book for a given symbol, or [None] if the symbol is not traded
    on this engine. *)
val book : t -> Symbol.t -> Order_book.t option

(** The number of orders each participant currently has resting on the book,
    summed across all symbols. Derived from the engine's live client-order
    tables, so it counts exactly the orders {!submit} accepted that have not
    since been fully filled or cancelled. Participants with no resting orders
    are absent from the map. Used by the gateway's monitoring metrics. *)
val resting_order_counts : t -> int Participant.Map.t
