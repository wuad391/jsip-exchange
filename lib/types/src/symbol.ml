open! Core

module T = struct
  type t = string [@@deriving sexp, bin_io, compare, equal, hash, string]
end

include T
include Comparable.Make (T)
include Hashable.Make (T)

(* of_string automatically uppercases the symbol to avoid placing the burden
   of formatting on clients *)
let of_string s =
  if String.is_empty s
  then raise_s [%message "Symbol.of_string: symbol must be non-empty"];
  (* TODO: change to not once i figure out how to do that bc not in core bool
     library?? *)
  if Bool.equal (String.for_all s ~f:Char.is_alphanum) false
  then raise_s [%message "Symbol.of_string: contains invalid characters"];
  String.uppercase s
;;
