open! Core
open Jsip_types
open Jsip_symbol_directory

(* JS-safe formatting for the live event feed. The browser feed pane and its
   tests share this so the wording and colors are identical everywhere, and
   so the client never has to reach for [Jsip_gateway.Protocol.format_event]
   — that lives behind Async and cannot cross into js_of_ocaml. The palette
   is the same one the terminal monitor's [Event_log] uses, transposed from
   named ANSI colors to the dashboard's hex tokens. *)

(* One hex per event kind, matching [app/dashboard/client/dashboard_app.ml]'s
   dark palette so the feed reads as part of the same surface. *)
let color_accept = "#3fb950"
let color_fill = "#39c5cf"
let color_cancel = "#e3b341"
let color_reject = "#f85149"
let color_cancel_reject = "#f0883e"
let color_bbo = "#58a6ff"
let color_trade = "#bc8cff"
let color_session = "#8b949e"

let symbol_of_event : Exchange_event.t -> Symbol_id.t option = function
  | Order_accept { order_id = _; participant = _; request } ->
    Some request.symbol
  | Fill fill -> Some fill.symbol
  | Order_cancel
      { order_id = _
      ; client_order_id = _
      ; participant = _
      ; symbol
      ; remaining_size = _
      ; reason = _
      } ->
    Some symbol
  | Order_reject { participant = _; request; reason = _ } ->
    Some request.symbol
  | Cancel_reject { participant = _; client_order_id = _; reason = _ } ->
    None
  | Best_bid_offer_update { symbol; bbo = _ } -> Some symbol
  | Trade_report { symbol; price = _; size = _ } -> Some symbol
  | Session_status { participant = _; status = _ } -> None
;;

type feed_row =
  { symbol : Symbol_id.t option
  ; text : string
  ; color : string
  }
[@@deriving sexp_of]

let format ?(directory = Symbol_directory.empty) (event : Exchange_event.t)
  : feed_row
  =
  (* Resolve ids to names via the mirrored directory; an empty directory (the
     default, and what a caller passes before the fetch lands) falls back to
     the numeric id. *)
  let render_symbol id = Symbol_directory.name_or_id directory id in
  let text, color =
    match event with
    | Order_accept { order_id; participant = _; request } ->
      let symbol = render_symbol request.symbol in
      let side = request.side in
      let size = Size.to_int request.size in
      let price = Price.to_string_dollar request.price in
      let tif = request.time_in_force in
      ( [%string
          "ACCEPTED id=%{order_id#Order_id} %{symbol} %{side#Side} \
           %{size#Int}@%{price} %{tif#Time_in_force}"]
      , color_accept )
    | Fill fill ->
      (* Mirror [Fill.to_string]'s layout but render the symbol as a name via
         the directory — the same thing [Jsip_gateway.Protocol.format_event]
         does for the native consumers, reproduced here because that
         formatter lives behind Async and cannot cross into js_of_ocaml. *)
      ( sprintf
          "FILL fill_id=%d %s %s x%d aggressor=%s(%s w/ client order ID = \
           %s) %s resting=%s(%s w/ client order ID = %s)"
          fill.fill_id
          (render_symbol fill.symbol)
          (Price.to_string_dollar fill.price)
          (Size.to_int fill.size)
          (Order_id.to_string fill.aggressor_order_id)
          (Participant.to_string fill.aggressor_participant)
          (Client_order_id.to_string fill.aggressor_client_order_id)
          (Side.to_string fill.aggressor_side)
          (Order_id.to_string fill.resting_order_id)
          (Participant.to_string fill.resting_participant)
          (Client_order_id.to_string fill.resting_client_order_id)
      , color_fill )
    | Order_cancel
        { order_id
        ; client_order_id = _
        ; participant = _
        ; symbol
        ; remaining_size
        ; reason
        } ->
      let symbol = render_symbol symbol in
      let remaining = Size.to_int remaining_size in
      ( [%string
          "CANCELLED id=%{order_id#Order_id} %{symbol} \
           remaining=%{remaining#Int} reason=%{reason#Cancel_reason}"]
      , color_cancel )
    | Order_reject { participant = _; request; reason } ->
      let symbol = render_symbol request.symbol in
      let side = request.side in
      let size = Size.to_int request.size in
      let price = Price.to_string_dollar request.price in
      ( [%string
          "REJECTED %{symbol} %{side#Side} %{size#Int}@%{price} \
           reason=%{reason}"]
      , color_reject )
    | Cancel_reject { participant = _; client_order_id = _; reason } ->
      [%string "REJECTED CANCEL because %{reason}"], color_cancel_reject
    | Best_bid_offer_update { symbol; bbo } ->
      let symbol = render_symbol symbol in
      let bid = Level.opt_to_string bbo.bid in
      let ask = Level.opt_to_string bbo.ask in
      [%string "BBO %{symbol} bid=%{bid} ask=%{ask}"], color_bbo
    | Trade_report { symbol; price; size } ->
      let symbol = render_symbol symbol in
      let size = Size.to_int size in
      [%string "TRADE %{symbol} %{price#Price} x%{size#Int}"], color_trade
    | Session_status { participant; status } ->
      ( [%string
          "SESSION %{participant#Participant} %{status#Session_status}"]
      , color_session )
  in
  { symbol = symbol_of_event event; text; color }
;;
