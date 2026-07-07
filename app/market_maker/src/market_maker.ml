open! Core
open! Async
open Jsip_types
open Jsip_gateway

module Config = struct
  type t =
    { participant : Participant.t
    ; symbol : Symbol.t
    ; fair_value_cents : int
    ; half_spread_cents : int
    ; size_per_level : int
    ; num_levels : int
    ; inventory_skew_cents_per_share : int
    }
  [@@deriving sexp_of]
end

(* A single monotonic counter, shared across every [seed_book] call, so that
   repeated seedings (e.g. the server's back-and-forth demo, which re-seeds
   each cycle) never reuse a [client_order_id] and get rejected as
   duplicates. *)
let client_order_id_ref = ref 1

let new_client_order_id () =
  client_order_id_ref := !client_order_id_ref + 1;
  Client_order_id.of_int !client_order_id_ref
;;

let seed_book (config : Config.t) conn =
  let submit request =
    let%map result =
      Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc conn request
    in
    match result with
    | Ok () -> ()
    | Error msg ->
      [%log.error
        "market_maker: submit failed"
          (request : Order.Request.t)
          (msg : Error.t)]
  in
  Deferred.List.iter
    ~how:`Parallel
    (List.init config.num_levels ~f:Fn.id)
    ~f:(fun level ->
      let offset = config.half_spread_cents + level in
      let%bind () =
        submit
          ({ symbol = config.symbol
           ; participant = config.participant
           ; side = Buy
           ; price = Price.of_int_cents (config.fair_value_cents - offset)
           ; size = Size.of_int config.size_per_level
           ; time_in_force = Day
           ; client_order_id = new_client_order_id ()
           }
           : Order.Request.t)
      and () =
        submit
          ({ symbol = config.symbol
           ; participant = config.participant
           ; side = Sell
           ; price = Price.of_int_cents (config.fair_value_cents + offset)
           ; size = Size.of_int config.size_per_level
           ; time_in_force = Day
           ; client_order_id = new_client_order_id ()
           }
           : Order.Request.t)
      in
      Deferred.unit)
;;
