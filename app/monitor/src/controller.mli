(** The monitor's pure state machine.

    A [Controller.t] holds everything the UI needs to render a single frame:
    the running event log, which filters are enabled, what the user is
    currently typing into the substring box, and whether the app should quit.
    [handle_key] and [feed_event] are pure transitions — the bonsai_term
    layer threads them through [Bonsai.state] and renders [display] to the
    screen.

    The state machine is intentionally testable without bringing in any
    bonsai_term machinery: the only bonsai_term type it touches is
    [Event.Key.t], which is a plain variant. *)

open! Core
open Jsip_types
open Jsip_gateway

(** A single labelled toggle in the filter row. The bonsai_term layer renders
    each chip as bracketed text colored by [enabled] and prefixed with its
    [hotkey]. *)
module Chip : sig
  type t =
    { hotkey : char
    ; label : string
    ; enabled : bool
    }
  [@@deriving sexp_of, compare, equal]
end

(** The structured view the bonsai_term layer reads. Decoupled from any
    bonsai_term type so the controller is fully testable as plain data. *)
module Display : sig
  type substring_field =
    { value : string
    ; editing : bool
    }
  [@@deriving sexp_of, compare, equal]

  (** One participant's net profit-and-loss, aggregated across every symbol
      they have traded, in integer cents (matching {!Jsip_types.Price}). The
      view formats [total_cents] to dollars and colors it by sign. *)
  module Participant_pnl : sig
    type t =
      { participant : string
      ; total_cents : int
      }
    [@@deriving sexp_of, compare, equal]
  end

  type t =
    { title : string
    ; counter : string
    ; bbo_panel : (string * Bbo.t) list
    (** Snapshot of the latest BBO per symbol, in first-appearance order,
        with the symbol already rendered to its display label (name if the
        directory knows it, else the raw id) so the view layer needs no
        directory. Always visible in the chrome — independent of the
        event-list filters — so the user can keep an eye on the live market
        while drilling into specific event categories. *)
    ; participant_pnl : Participant_pnl.t list
    (** Net P&L per participant, sorted by [total_cents] descending (biggest
        winner first, ties broken by name). Accumulated from the audit
        stream's {!Jsip_types.Exchange_event.Fill} and [Trade_report] events,
        so — like [bbo_panel] — it is always visible and independent of the
        event-list filters. *)
    ; category_chips : Chip.t list
    ; substring_field : substring_field
    ; visible_events : (Event_log.Color.t * string) list
    ; mode_indicator : string
    ; footer : string
    }
  [@@deriving sexp_of, compare, equal]
end

type t

(** Create the initial state. [directory] (default
    {!Jsip_gateway.Symbol_directory.empty}) is the id<->name map used to
    render event lines and the BBO panel; the default renders raw ids. *)
val create : ?directory:Symbol_directory.t -> unit -> t

(** Deliver a new exchange event. The controller appends it to the log; the
    next call to [display] will include it if the current filter admits. *)
val feed_event : t -> Exchange_event.t -> t

(** Apply a single keystroke. Most keys mutate filter UI state or the mode;
    [q] sets [should_exit] to [true]. [Ctrl-C] is intercepted in [Term_app]
    and never reaches the controller. *)
val handle_key : t -> Bonsai_term.Event.Key.t -> t

(** [true] once the user has asked to quit. The bonsai_term loop should
    notice and unblock. *)
val should_exit : t -> bool

(** [true] when the controller is in the substring-editing mode. The Bonsai
    layer uses this to decide whether to route navigation keys (e.g. [j],
    [k], arrow keys) to a scroller or treat them as buffer input. *)
val is_editing_substring : t -> bool

(** Render the current state as [Display.t]. *)
val display : t -> Display.t
