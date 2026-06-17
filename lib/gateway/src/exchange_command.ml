open! Core
open Jsip_types

type verb =
  | Buy
  | Sell
  | Book
  | Subscribe
[@@deriving string ~case_insensitive]

type t =
  | Submit of Order.Request.t
  | Book of Symbol.t
  | Subscribe of Symbol.t

(* This function is a more robust parser than the old parser previously found
   in protocol.ml *)
(* TODO: This is a very ugly function... *)
let parse ?(default_participant = "anonymous") line =
  let line = String.strip line in
  if String.is_empty line
  then Error "empty command"
  else (
    let parts = String.split line ~on:' ' in
    let submit_parse verb rest =
      let open Result.Let_syntax in
      let%bind side =
        match verb with
        | "BUY" -> Ok Side.Buy
        | "SELL" -> Ok Side.Sell
        | _ -> raise_s [%message "This should also not be possible..."]
      in
      match rest with
      | symbol_str :: size_str :: price_str :: rest ->
        let%bind size =
          match Int.of_string_opt size_str with
          | Some n when n > 0 -> Ok n
          | Some _ -> Error "size must be positive"
          | None -> Error [%string "invalid size: %{size_str}"]
        in
        let%bind price =
          try Ok (Price.of_string price_str) with
          | exn ->
            let exn_str = Exn.to_string exn in
            Error
              [%string "invalid price: %{price_str}\nexception: %{exn_str}"]
        in
        let%bind symbol =
          try Ok (Symbol.of_string symbol_str) with
          | exn ->
            let exn_str = Exn.to_string exn in
            Error
              [%string
                "invalid symbol: %{symbol_str}\nexception: %{exn_str}"]
        in
        let%bind time_in_force, rest =
          match rest with
          | tif_str :: rest' ->
            Time_in_force.of_string
              tif_string chekc if of_string errors
              (match String.uppercase tif_str with
               | "IOC" -> Ok (Time_in_force.Ioc, rest')
               | "DAY" -> Ok (Day, rest')
               | "AS" -> Ok (Day, rest)
               | _ ->
                 Error
                   [%string
                     "unknown time-in-force: %{tif_str} (expected DAY or \
                      IOC)"])
          | [] -> Ok (Day, [])
        in
        let%bind participant =
          match rest with
          | "as" :: name :: _ | "AS" :: name :: _ ->
            Ok (Participant.of_string name)
          | [] -> Ok (Participant.of_string default_participant)
          | _ ->
            let trailing = String.concat ~sep:" " rest in
            Error [%string "unexpected trailing arguments: %{trailing}"]
        in
        Ok
          (Submit
             ({ symbol
              ; participant
              ; side
              ; price
              ; size = Size.of_int size
              ; time_in_force
              }
              : Order.Request.t))
      | _ ->
        Error
          "expected: BUY|SELL <symbol> <size> <price> [DAY|IOC] [as <name>]"
    in
    match parts with
    | verb :: symbol :: rest ->
      (match String.uppercase verb with
       | "BUY" | "SELL" -> submit_parse verb (symbol :: rest)
       | "BOOK" -> Ok (Book (Symbol.of_string symbol))
       | "SUBSCRIBE" -> Ok (Subscribe (Symbol.of_string symbol))
       | other -> Error [%string "Invalid verb in parse in exchange_command"])
    | _ -> raise_s [%message "This is impossible in parse"])
;;
