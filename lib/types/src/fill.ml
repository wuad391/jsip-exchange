open! Core

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

let to_string
  ({ fill_id
   ; symbol
   ; price
   ; size
   ; aggressor_order_id
   ; aggressor_client_order_id
   ; aggressor_participant
   ; aggressor_side
   ; resting_order_id
   ; resting_participant
   ; resting_client_order_id
   } :
    t)
  =
  sprintf
    "fill_id=%d %s %s x%d aggressor=%s(%s w/ client order ID = %s) %s \
     resting=%s(%s w/ client order ID = %s)"
    fill_id
    (Symbol_id.to_string symbol)
    (Price.to_string_dollar price)
    (Size.to_int size)
    (Order_id.to_string aggressor_order_id)
    (Participant.to_string aggressor_participant)
    (Client_order_id.to_string aggressor_client_order_id)
    (Side.to_string aggressor_side)
    (Order_id.to_string resting_order_id)
    (Participant.to_string resting_participant)
    (Client_order_id.to_string resting_client_order_id)
;;

(* [to_string] deliberately prints the raw [Symbol_id.t]: turning an id into
   a human name needs a symbol directory, and the directory lives at the
   edges (the gateway, the interactive client), never in the domain layer —
   so [Fill] has no notion of a symbol's name and no second source of truth
   for its symbol.

   The per-viewer "Order <id>: You bought <n> <symbol> at <price>" line (an
   exercise-4 feature, formerly [to_participant_view] here) has exactly the
   same naming need, so it is built in [Jsip_gateway.Protocol.format_event],
   where the directory is in scope, rather than in this module. *)

let notional_cents t = Price.to_int_cents t.price * Size.to_int t.size
