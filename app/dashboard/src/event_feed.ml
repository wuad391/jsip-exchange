open! Core
open Jsip_types

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
;;

type feed_row =
  { symbol : Symbol_id.t option
  ; text : string
  ; color : string
  }
[@@deriving sexp_of]

let format (event : Exchange_event.t) : feed_row =
  let text, color =
    match event with
    | Order_accept { order_id; participant = _; request } ->
      let symbol = request.symbol in
      let side = request.side in
      let size = Size.to_int request.size in
      let price = Price.to_string_dollar request.price in
      let tif = request.time_in_force in
      ( [%string
          "ACCEPTED id=%{order_id#Order_id} %{symbol#Symbol_id} \
           %{side#Side} %{size#Int}@%{price} %{tif#Time_in_force}"]
      , color_accept )
    | Fill fill -> [%string "FILL %{fill#Fill}"], color_fill
    | Order_cancel
        { order_id
        ; client_order_id = _
        ; participant = _
        ; symbol
        ; remaining_size
        ; reason
        } ->
      let remaining = Size.to_int remaining_size in
      ( [%string
          "CANCELLED id=%{order_id#Order_id} %{symbol#Symbol_id} \
           remaining=%{remaining#Int} reason=%{reason#Cancel_reason}"]
      , color_cancel )
    | Order_reject { participant = _; request; reason } ->
      let symbol = request.symbol in
      let side = request.side in
      let size = Size.to_int request.size in
      let price = Price.to_string_dollar request.price in
      ( [%string
          "REJECTED %{symbol#Symbol_id} %{side#Side} %{size#Int}@%{price} \
           reason=%{reason}"]
      , color_reject )
    | Cancel_reject { participant = _; client_order_id = _; reason } ->
      [%string "REJECTED CANCEL because %{reason}"], color_cancel_reject
    | Best_bid_offer_update { symbol; bbo } ->
      let bid = Level.opt_to_string bbo.bid in
      let ask = Level.opt_to_string bbo.ask in
      [%string "BBO %{symbol#Symbol_id} bid=%{bid} ask=%{ask}"], color_bbo
    | Trade_report { symbol; price; size } ->
      let size = Size.to_int size in
      ( [%string "TRADE %{symbol#Symbol_id} %{price#Price} x%{size#Int}"]
      , color_trade )
  in
  { symbol = symbol_of_event event; text; color }
;;
