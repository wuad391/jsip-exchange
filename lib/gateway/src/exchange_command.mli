open! Core
open Jsip_types

type t =
  | Submit of Order.Request.t
  | Book of Symbol_id.t
  | Subscribe of Symbol_id.t
  | Cancel of Order.Cancel.t
[@@deriving sexp]

(** Parse one command line into a typed command.

    Symbol tokens are resolved against [directory] when given: the token is a
    human name (e.g. [AAPL]) and is looked up to its
    {!Jsip_types.Symbol_id.t} — this is what the interactive client passes
    after fetching the directory at connect. Without a [directory] the token
    is parsed as the id itself, for in-process callers that already speak
    ids. Should be wrapped in a try/catch (some malformed input raises rather
    than returning [Error]). *)
val parse
  :  ?directory:Symbol_directory.t
  -> ?default_participant:Participant.t
  -> string
  -> t Or_error.t

val to_string : t -> string
