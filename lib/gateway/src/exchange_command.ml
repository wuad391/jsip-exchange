open! Core
open Jsip_types

module Verb = struct
  type t =
    | Buy
    | Sell
    | Book
    | Subscribe
    | Cancel
  [@@deriving string ~case_insensitive, enumerate]

  let all_str = String.concat (List.map all ~f:to_string) ~sep:", "
end

type t =
  | Submit of Order.Request.t
  | Book of Symbol_id.t
  | Subscribe of Symbol_id.t
  | Cancel of Order.Cancel.t
[@@deriving sexp]

let to_string t =
  match t with
  | Submit request -> [%string "%{request#Order.Request}"]
  | Book symbol -> [%string "BOOK %{symbol#Symbol_id}"]
  | Subscribe symbol -> [%string "SUBSCRIBE %{symbol#Symbol_id}"]
  | Cancel cancel -> [%string "%{(cancel)#Order.Cancel}"]
;;

(* This function is a more robust parser than the old parser previously found
   in protocol.ml. When callled, should be wrapped in a try catch *)
let parse ?(default_participant = Participant.of_string "anonymous") line =
  let line = String.strip line in
  if String.is_empty line
  then Or_error.error_string [%string "empty command"]
  else (
    let parts =
      String.split line ~on:' '
      |> List.map ~f:String.strip
      |> List.filter ~f:(Fn.non String.is_empty)
    in
    let submit_parse verb rest =
      let open Result.Let_syntax in
      let%bind side =
        match verb with
        | Ok Verb.Buy -> Ok Side.Buy
        | Ok Sell -> Ok Side.Sell
        | _ -> raise_s [%message "This should also not be possible..."]
      in
      match rest with
      | client_id_str :: symbol_str :: size_str :: price_str :: rest ->
        let%bind client_order_id =
          try Ok (Client_order_id.of_string client_id_str) with
          | exn ->
            let exn_str = Exn.to_string exn in
            Or_error.error_string
              [%string
                "invalid client_id: %{client_id_str}\nexception: %{exn_str}"]
        in
        let%bind size =
          match Int.of_string_opt size_str with
          | Some n when n > 0 -> Ok n
          | Some _ -> Or_error.error_string [%string "size must be positive"]
          | None ->
            Or_error.error_string [%string "invalid size: %{size_str}"]
        in
        let%bind price =
          try Ok (Price.of_string price_str) with
          | exn ->
            let exn_str = Exn.to_string exn in
            Or_error.error_string
              [%string "invalid price: %{price_str}\nexception: %{exn_str}"]
        in
        let%bind symbol =
          try Ok (Symbol_id.of_string symbol_str) with
          | exn ->
            let exn_str = Exn.to_string exn in
            Or_error.error_string
              [%string
                "invalid symbol: %{symbol_str}\nexception: %{exn_str}"]
        in
        let%bind time_in_force =
          match rest with
          | tif_str :: _ ->
            if String.is_empty tif_str
            then Ok Time_in_force.Day
            else (
              match
                Or_error.try_with (fun _ -> Time_in_force.of_string tif_str)
              with
              | Ok tif -> Ok tif
              | Error _ ->
                Or_error.error_string
                  [%string
                    "unknown time-in-force: %{tif_str#String} (expected \
                     %{Time_in_force.all_str#String})"])
          | [] -> Ok Time_in_force.Day
        in
        Ok
          (Submit
             ({ symbol
              ; participant = default_participant
              ; side
              ; price
              ; size = Size.of_int size
              ; time_in_force
              ; client_order_id
              }
              : Order.Request.t))
      | _ ->
        Or_error.error_string
          [%string
            "expected: BUY|SELL <client order id> <symbol> <size> <price> \
             [%{Time_in_force.all_str#String}]"]
    in
    let parse_symbol symbol_str =
      try Ok (Symbol_id.of_string symbol_str) with
      | exn ->
        let exn_str = Exn.to_string exn in
        Or_error.error_string
          [%string "invalid symbol: %{symbol_str}\nexception: %{exn_str}"]
    in
    let parse_client_order_id client_order_id_str =
      try Ok (Client_order_id.of_string client_order_id_str) with
      | exn ->
        let exn_str = Exn.to_string exn in
        Or_error.error_string
          [%string
            "invalid client_id: %{client_order_id_str}\n\
             exception: %{exn_str}"]
    in
    let cancel_parse client_order_id_str =
      Result.map
        (parse_client_order_id client_order_id_str)
        ~f:(fun client_order_id ->
          Cancel { participant = default_participant; client_order_id })
    in
    match parts with
    | verb :: second :: rest ->
      let verb_type = Or_error.try_with (fun _ -> Verb.of_string verb) in
      (match verb_type with
       | Ok Verb.Buy | Ok Sell -> submit_parse verb_type (second :: rest)
       | Ok Verb.Book ->
         Result.map (parse_symbol second) ~f:(fun s -> Book s)
       | Ok Verb.Subscribe ->
         Result.map (parse_symbol second) ~f:(fun s -> Subscribe s)
       | Ok Verb.Cancel -> cancel_parse second
       | Error _ ->
         Or_error.error_string
           [%string
             "unknown command %{verb#String} (expected \
              %{Verb.all_str#String})"])
    | _ ->
      Or_error.error_string
        [%string
          "expected: BUY|SELL <client order id> <symbol> <size> <price> \
           [%{Time_in_force.all_str#String}]"])
;;
