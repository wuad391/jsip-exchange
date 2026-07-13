open! Core

type t =
  { symbol : Symbol_id.t
  ; bids : Level.t list
  ; asks : Level.t list
  ; bbo : Bbo.t
  }
[@@deriving sexp, bin_io]

(* The header prints the raw [Symbol_id.t]; a caller that wants the human
   name (e.g. the interactive client) has a directory and prints the name
   itself before this. [Book] stays int-only, with no second source of truth
   for its symbol. *)
let to_string { symbol; bids; asks; bbo } =
  let format_side label levels =
    match levels with
    | [] -> [%string "  %{label}: (empty)"]
    | _ ->
      let lines =
        List.map levels ~f:(fun level -> [%string "    %{level#Level}"])
        |> String.concat ~sep:"\n"
      in
      [%string "  %{label}:\n%{lines}"]
  in
  String.concat
    ~sep:"\n"
    [ [%string "=== %{symbol#Symbol_id} ==="]
    ; format_side "BIDS" bids
    ; format_side "ASKS" asks
    ; [%string "  BBO: %{bbo#Bbo}"]
    ]
;;
