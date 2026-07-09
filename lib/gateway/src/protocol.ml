open! Core
open Jsip_types

(* Render side of the readability layer: given the [directory] the client
   fetched at connect, an id prints as its human name; without one (or for an
   id the directory doesn't know) it falls back to the numeric id. The wire
   event itself only ever carries [Symbol_id.t]. *)
let format_event ?directory ?(participant = None) event =
  let symbol_to_string symbol =
    match directory with
    | None -> Symbol_id.to_string symbol
    | Some directory -> Symbol_directory.name_or_id directory symbol
  in
  match event with
  | Exchange_event.Order_accept { order_id; participant = _; request } ->
    sprintf
      "ACCEPTED id=%s %s %s %d@%s %s"
      (Order_id.to_string order_id)
      (symbol_to_string request.symbol)
      (Side.to_string request.side)
      (Size.to_int request.size)
      (Price.to_string_dollar request.price)
      (Time_in_force.to_string request.time_in_force)
  | Fill fill ->
    (* Fills are hand-formatted here (like every other event variant) rather
       than via [Fill.to_string], because rendering the symbol as a name
       needs the directory, which lives here, not in [lib/types]. *)
    let symbol = symbol_to_string fill.symbol in
    let generic_line () =
      sprintf
        "FILL fill_id=%d %s %s x%d aggressor=%s(%s w/ client order ID = %s) \
         %s resting=%s(%s w/ client order ID = %s)"
        fill.fill_id
        symbol
        (Price.to_string_dollar fill.price)
        (Size.to_int fill.size)
        (Order_id.to_string fill.aggressor_order_id)
        (Participant.to_string fill.aggressor_participant)
        (Client_order_id.to_string fill.aggressor_client_order_id)
        (Side.to_string fill.aggressor_side)
        (Order_id.to_string fill.resting_order_id)
        (Participant.to_string fill.resting_participant)
        (Client_order_id.to_string fill.resting_client_order_id)
    in
    (match participant with
     | None -> generic_line ()
     | Some viewer ->
       (* The viewer's own perspective: their [client_order_id] and the side
          they were on — the resting party's side is the opposite of the
          aggressor's. Not a party to this fill → fall back to the generic
          line. *)
       let own_side =
         if Participant.equal viewer fill.aggressor_participant
         then Some (fill.aggressor_client_order_id, fill.aggressor_side)
         else if Participant.equal viewer fill.resting_participant
         then
           Some (fill.resting_client_order_id, Side.flip fill.aggressor_side)
         else None
       in
       (match own_side with
        | None -> generic_line ()
        | Some (client_order_id, side) ->
          sprintf
            "FILL Order %s: You %s %d %s at %s."
            (Client_order_id.to_string client_order_id)
            (match side with Buy -> "bought" | Sell -> "sold")
            (Size.to_int fill.size)
            symbol
            (Price.to_string_dollar fill.price)))
  | Order_cancel
      { order_id; participant = _; symbol; remaining_size; reason; _ } ->
    sprintf
      "CANCELLED id=%s %s remaining=%d reason=%s"
      (Order_id.to_string order_id)
      (symbol_to_string symbol)
      (Size.to_int remaining_size)
      (Cancel_reason.to_string reason)
  | Order_reject { participant = _; request; reason } ->
    sprintf
      "REJECTED %s %s %d@%s reason=%s"
      (symbol_to_string request.symbol)
      (Side.to_string request.side)
      (Size.to_int request.size)
      (Price.to_string_dollar request.price)
      reason
  | Best_bid_offer_update { symbol; bbo } ->
    let symbol = symbol_to_string symbol in
    let bid = Level.opt_to_string bbo.bid in
    let ask = Level.opt_to_string bbo.ask in
    [%string "BBO %{symbol} bid=%{bid} ask=%{ask}"]
  | Trade_report { symbol; price; size } ->
    let symbol = symbol_to_string symbol in
    let size = Size.to_int size in
    [%string "TRADE %{symbol} %{price#Price} x%{size#Int}"]
  | Cancel_reject { participant = _; client_order_id = _; reason } ->
    [%string "REJECTED CANCEL because %{reason}"]
;;

let format_events ?directory ?(participant = None) events =
  List.map events ~f:(format_event ?directory ~participant)
  |> String.concat ~sep:"\n"
;;
