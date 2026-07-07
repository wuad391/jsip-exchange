open! Core

module T = struct
  type t = string [@@deriving sexp, bin_io, compare, equal, hash, string]
end

include T
include Comparable.Make (T)
include Hashable.Make (T)

(* XCR-soon claude for robyn: [Comparable.Make (T)] already includes a
   comparator, so this second [include Comparator.Make (T)] is redundant and
   introduces a *distinct* [comparator_witness] that shadows the first. Drop
   it (and the matching [include Comparator.S] in the .mli).

   claude: verified — the redundant [include Comparator.Make (T)] is gone
   from the .ml and [include Comparator.S] from the .mli; the comparator now
   comes solely from [Comparable.Make (T)]. *)

(* of_string automatically uppercases the symbol to avoid placing the burden
   of formatting on clients *)
let of_string s =
  if String.is_empty s
  then raise_s [%message "Symbol.of_string: symbol must be non-empty"];
  if not (String.for_all s ~f:Char.is_alphanum)
  then raise_s [%message "Symbol.of_string: contains invalid characters"];
  String.uppercase s
;;
