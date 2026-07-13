open! Core

module T = struct
  type t = int [@@deriving sexp, bin_io, compare, equal, hash, string]
end

include T
include Comparable.Make (T)
include Hashable.Make (T)

let of_int n =
  if n < 0
  then
    raise_s [%message "Symbol_id.of_int: id must be non-negative" (n : int)];
  n
;;

let to_int t = t
let of_string s = of_int (Int.of_string s)
