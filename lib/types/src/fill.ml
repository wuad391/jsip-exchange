open! Core

type t =
  { fill_id : int
  ; symbol : Symbol.t
  ; price : Price.t
  ; size : Size.t
  ; aggressor_order_id : Order_id.t
  ; aggressor_participant : Participant.t
  ; aggressor_side : Side.t
  ; resting_order_id : Order_id.t
  ; resting_participant : Participant.t
  }
[@@deriving sexp, bin_io]

let to_string
  ({ fill_id
   ; symbol
   ; price
   ; size
   ; aggressor_order_id
   ; aggressor_participant
   ; aggressor_side
   ; resting_order_id
   ; resting_participant
   } :
    t)
  =
  sprintf
    "fill_id=%d %s %s x%d aggressor=%s(%s) %s resting=%s(%s)"
    fill_id
    (Symbol.to_string symbol)
    (Price.to_string_dollar price)
    (Size.to_int size)
    (Order_id.to_string aggressor_order_id)
    (Participant.to_string aggressor_participant)
    (Side.to_string aggressor_side)
    (Order_id.to_string resting_order_id)
    (Participant.to_string resting_participant)
;;

(* this function satisfies exercise 4 and is used to return a client view.
   TODO: is there a more elegant way to not repeat the ugly sprintf. could
   factor out but then have to case again for None *)
let to_participant_view t participant =
  match
    ( Participant.equal participant t.aggressor_participant
    , Participant.equal participant t.resting_participant )
  with
  | true, _ ->
    Some
      (sprintf
         "You %s %d %s at %s."
         (match t.aggressor_side with Buy -> "bought" | Sell -> "sold")
         (Size.to_int t.size)
         (Symbol.to_string t.symbol)
         (Price.to_string_dollar t.price))
  | _, true ->
    Some
      (sprintf
         "You %s %d %s at %s."
         (match Side.flip t.aggressor_side with
          | Buy -> "bought"
          | Sell -> "sold")
         (Size.to_int t.size)
         (Symbol.to_string t.symbol)
         (Price.to_string_dollar t.price))
  | _ -> None
;;

let notional_cents t = Price.to_int_cents t.price * Size.to_int t.size
