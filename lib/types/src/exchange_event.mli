(** Events produced by the matching engine.

    In a production exchange, events would be messages on a replicated
    stream, with all components seeing the same ordered sequence to keep
    their state consistent. The message schema would have dozens of variants
    for different order types, market data, control messages, etc.

    We model events as a simple variant type. The matching engine produces
    events; the gateway and market data systems consume them. *)

type t =
  | Order_accept of
      { order_id : Order_id.t
      ; request : Order.Request.t
      }
  | Fill of Fill.t
  | Order_cancel of
      { order_id : Order_id.t
      ; participant : Participant.t
      ; symbol : Symbol.t
      ; remaining_size : Size.t
      ; reason : Cancel_reason.t
      ; client_order_id : Client_order_id.t
      }
  | Order_reject of
      { request : Order.Request.t
      ; reason : string
      }
  | Best_bid_offer_update of
      { symbol : Symbol.t
      ; bbo : Bbo.t
      }
  | Trade_report of
      { symbol : Symbol.t
      ; price : Price.t
      ; size : Size.t
      }
  (* CR-soon claude for robyn: inserting [Cancel_reject] here orphaned the
     "public trade print" doc below onto it (odoc attaches a trailing
     [(** *)] to the *preceding* constructor). Move that doc up under
     [Trade_report], and give [Cancel_reject] its own doc. Also the
     [remaining_size] field doc on [Order_cancel] was dropped in this diff —
     restore it. *)
  | Cancel_reject of
      { participant : Participant.t
      ; client_order_id : Client_order_id.t
      ; reason : string
      }
  (** A public trade print. Unlike [Fill], this contains no information about
      the participants — it is what the broader market sees. *)
[@@deriving sexp, bin_io]

(** Is this a market data event (BBO update or trade report)? *)
val is_market_data : t -> bool

(** The symbol associated with market data events, or [None] for
    non-market-data events. *)
val symbol_of_market_data : t -> Symbol.t option
