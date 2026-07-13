(** Whether a participant's session just came up or went away.

    Carried by the [Session_status] constructor of {!Exchange_event.t} so the
    audit log (and the monitor watching it) can announce ["X connected"] /
    ["X disconnected"] as sessions appear and disappear. *)

open! Core

type t =
  | Connected
  | Disconnected
[@@deriving sexp, bin_io, compare, equal, hash]

(** Lowercase and human-readable: ["connected"] / ["disconnected"]. *)
val to_string : t -> string
