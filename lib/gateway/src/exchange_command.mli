open! Core
open Jsip_types

type t =
  | Submit of Order.Request.t
  | Book of Symbol_id.t
  | Subscribe of Symbol_id.t
  | Cancel of Order.Cancel.t
[@@deriving sexp]

val parse : ?default_participant:Participant.t -> string -> t Or_error.t
val to_string : t -> string
