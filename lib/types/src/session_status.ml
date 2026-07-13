open! Core

type t =
  | Connected
  | Disconnected
[@@deriving sexp, bin_io, compare, equal, hash]

let to_string = function
  | Connected -> "connected"
  | Disconnected -> "disconnected"
;;
