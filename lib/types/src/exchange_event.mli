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
      ; participant : Participant.t
      ; request : Order.Request.t
      }
  | Fill of Fill.t
  | Order_cancel of
      { order_id : Order_id.t
      ; client_order_id : Client_order_id.t
      ; participant : Participant.t
      ; symbol : Symbol_id.t
      ; remaining_size : Size.t
      (** Size that was still unfilled when the order was cancelled. *)
      ; reason : Cancel_reason.t
      }
  | Order_reject of
      { participant : Participant.t
      ; request : Order.Request.t
      ; reason : string
      }
  | Cancel_reject of
      { participant : Participant.t
      ; client_order_id : Client_order_id.t
      ; reason : string
      }
  | Best_bid_offer_update of
      { symbol : Symbol_id.t
      ; bbo : Bbo.t
      }
  | Trade_report of
      { symbol : Symbol_id.t
      ; price : Price.t
      ; size : Size.t
      }
  (** A public trade print. Unlike [Fill], this contains no information about
      the participants — it is what the broader market sees. *)
  | Session_status of
      { participant : Participant.t
      ; status : Session_status.t
      }
  (** A participant's session came up ([Connected]) or went away
      ([Disconnected]). Emitted by the gateway at login and at session
      cleanup. Operator-facing telemetry — neither market data nor an order
      event — so the dispatcher routes it to audit subscribers only, never to
      session feeds or market-data streams. *)
[@@deriving sexp, bin_io]

(** Is this a market data event (BBO update or trade report)? *)
val is_market_data : t -> bool

(** The symbol associated with market data events, or [None] for
    non-market-data events. *)
val symbol_of_market_data : t -> Symbol_id.t option
