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

(* Satisfies exercise 4: renders a fill from one participant's point of view,
   or [None] if they were not a party to it. The two [Some] cases differ only
   in whose [client_order_id] and which side to show, so the [sprintf] is
   factored into [describe] and each branch just supplies those two values —
   which keeps the [None] case in the match. *)
let to_participant_view t participant =
  let describe client_order_id (side : Side.t) =
    sprintf
      "Order %s: You %s %d %s at %s."
      (Client_order_id.to_string client_order_id)
      (match side with Buy -> "bought" | Sell -> "sold")
      (Size.to_int t.size)
      (Symbol_id.to_string t.symbol)
      (Price.to_string_dollar t.price)
  in
  match
    ( Participant.equal participant t.aggressor_participant
    , Participant.equal participant t.resting_participant )
  with
  | true, _ -> Some (describe t.aggressor_client_order_id t.aggressor_side)
  | _, true ->
    Some (describe t.resting_client_order_id (Side.flip t.aggressor_side))
  | _ -> None
;;

let notional_cents t = Price.to_int_cents t.price * Size.to_int t.size
