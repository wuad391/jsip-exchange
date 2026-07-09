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
    | Some directory ->
      (match Symbol_directory.name directory symbol with
       | Some name -> Symbol.to_string name
       | None -> Symbol_id.to_string symbol)
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
    (match participant with
     | None -> [%string "FILL %{fill#Fill}"]
     | Some guy ->
       (match Fill.to_participant_view fill guy with
        | None -> [%string "FILL %{fill#Fill}"]
        | Some new_fill_string -> [%string "FILL %{new_fill_string}"]))
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
