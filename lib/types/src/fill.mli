(** A fill (execution) produced by the matching engine when two orders trade.

    Every fill involves exactly two sides: the "aggressor" (the incoming
    order that caused the match) and the "resting" order (which was already
    on the book). Both sides see the fill, but from their own perspective.

    A production exchange fill would carry additional metadata: liquidity
    flags, regulatory indicators, fee codes, timestamps, etc. *)

type t =
  { fill_id : int
  ; symbol : Symbol_id.t
  ; price : Price.t
  ; size : Size.t
  ; aggressor_order_id : Order_id.t
  ; aggressor_client_order_id : Client_order_id.t
  ; aggressor_participant : Participant.t
  ; aggressor_side : Side.t
  ; resting_order_id : Order_id.t
  ; resting_client_order_id : Client_order_id.t
  ; resting_participant : Participant.t
  }
[@@deriving sexp, bin_io]

(** Render a fill as a single line, printing the raw {!Symbol_id.t}. Naming a
    symbol needs a directory (a display concern owned by the gateway/client),
    so it is not done here; the gateway's [Protocol.format_event] renders the
    named, human-facing fill lines. *)
val to_string : t -> string

(** {2 Convenience accessors} *)

(** The total notional value of the fill in cents (price * size). *)
val notional_cents : t -> int
