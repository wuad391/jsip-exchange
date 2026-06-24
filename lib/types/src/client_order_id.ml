open! Core

type t = int [@@deriving sexp, bin_io, compare, equal, hash, string]

let to_int t = t
let of_int t = t
