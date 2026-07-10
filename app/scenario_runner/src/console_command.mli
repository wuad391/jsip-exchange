(** The interactive console's command grammar (the [-interactive] flag).

    One line, one command:

    {v
      spawn <kind> [<name>] [<SYMBOL>...] [key=value ...]
      kill <name>
      crash <name>
      list
      kinds
      help
      quit
    v}

    This is only the string grammar — resolving [kind] against the menu of
    spawnable bots, applying knobs, and driving the registry happen in
    {!Console}. Modeled on {!Jsip_gateway.Exchange_command}: verbs are
    case-insensitive, and with a [directory] symbol tokens are human names
    ([AAPL]) resolved to ids. *)

open! Core
open Jsip_types
open Jsip_symbol_directory

type t =
  | Spawn of
      { kind : string (** Menu token, e.g. ["mm"] — validated later. *)
      ; name : string option
      (** Participant to log in as; [None] lets the console auto-name (e.g.
          [mm-1]). *)
      ; symbols : Symbol_id.t list
      (** Symbols to trade; [[]] means every symbol in the directory. *)
      ; knobs : (string * int) list
      (** Raw [key=value] overrides, validated against the kind's menu entry
          later. *)
      }
  | Kill of string (** Graceful: flatten (cancel-all), then disconnect. *)
  | Crash of string (** Hard drop: disconnect, ghost orders left resting. *)
  | List_bots
  | Kinds
  | Help
  | Quit
[@@deriving sexp_of]

(** Parse one console line. Spawn tokens after the kind are classified in
    order: [key=value] tokens (integer values) must be trailing; the first
    bare token that does not resolve as a symbol is the bot's name; every
    other bare token must be a symbol. One consequence, worth knowing: a bot
    cannot be NAMED like a known ticker, and a misspelled ticker in the first
    bare position is read as a name rather than an error. [kill] and [crash]
    take the rest of the line verbatim-ish (whitespace collapsed) since
    scenario bot names contain spaces (["Market Maker"]). *)
val parse : ?directory:Symbol_directory.t -> string -> t Or_error.t
