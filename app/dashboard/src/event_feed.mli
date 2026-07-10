(** JS-safe rendering of {!Jsip_types.Exchange_event.t}s for the dashboard's
    live event feed.

    The exchange's full audit stream (orders, fills, cancels, market data) is
    projected into a one-line, colored {!feed_row} the browser feed pane
    draws. This is the js_of_ocaml-safe cousin of the terminal monitor's
    [Jsip_monitor.Event_log] formatting and
    [Jsip_gateway.Protocol.format_event] — neither of which can be linked
    into the client, since one pulls in [bonsai_term] and the other [async].
    Depends only on core and {!Jsip_types}, so it is safe on both the native
    server and the client. *)

open! Core
open Jsip_types
open Jsip_symbol_directory

(** The symbol an event pertains to, or [None] for events that carry no
    symbol (only {!Jsip_types.Exchange_event.Cancel_reject}). Drives the
    feed's per-symbol tab filtering. *)
val symbol_of_event : Exchange_event.t -> Symbol_id.t option

(** One rendered feed line: the (optional) symbol it belongs to, the display
    text, and the CSS hex color to draw it in (e.g. ["#3fb950"]). *)
type feed_row =
  { symbol : Symbol_id.t option
  ; text : string
  ; color : string
  }
[@@deriving sexp_of]

(** Render an event into a {!feed_row}. The text mirrors the terminal
    monitor's wording ([ACCEPTED …], [FILL …], [CANCELLED …], [BBO …],
    [TRADE …]); the color is fixed per event kind. With a [directory] (the
    browser fetches one at startup) the symbol renders as its name; the
    default empty directory falls back to the numeric id. *)
val format : ?directory:Symbol_directory.t -> Exchange_event.t -> feed_row
