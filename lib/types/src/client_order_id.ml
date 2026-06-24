open! Core

type t = int [@@deriving sexp, bin_io, compare, equal, hash, string]
