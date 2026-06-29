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

let client_order_id_test_ref = ref 1

let new_client_order_id () =
  client_order_id_test_ref := !client_order_id_test_ref + 1;
  Client_order_id.of_int !client_order_id_test_ref
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

type t =
  { inventory : Int.t Ref.t
  ; mutable bids : Client_order_id.t Hash_set.t
  ; mutable asks : Client_order_id.t Hash_set.t
  }

(* let books = ref
   [{ inventory = ref 0 ; bids = Hash_set.create (module Client_order_id) ; asks = Hash_set.create (module Client_order_id) }]
   ;; *)

let run ?(testing = false) (config : Config.t) conn =
  let t =
    { inventory = ref 0
    ; bids = Hash_set.create (module Client_order_id)
    ; asks = Hash_set.create (module Client_order_id)
    }
  in
  let get_side_client_order_id (fill : Fill.t) =
    if Participant.equal fill.aggressor_participant config.participant
    then fill.aggressor_side, fill.aggressor_client_order_id
    else Side.flip fill.aggressor_side, fill.resting_client_order_id
  in
  (* update_books is used when something gets filled *)
  let update_books side client_order_id =
    Hash_set.remove t.bids client_order_id;
    Hash_set.remove t.asks client_order_id;
    t.inventory
    := !(t.inventory) + match (side : Side.t) with Buy -> 1 | Sell -> -1
  in
  let cancel_all_orders side : unit =
    let client_order_id_set =
      match (side : Side.t) with Buy -> t.bids | Sell -> t.asks
    in
    (* TODO: This is a very janky way of iterating through a hash set but the
       types don't work well in Hash_set.iter *)
    ignore
      (Hash_set.fold client_order_id_set ~init:(return ()) ~f:(fun _ id ->
         let%bind _ =
           Rpc.Rpc.dispatch_exn Rpc_protocol.cancel_order_rpc conn id
         in
         return ()));
    match side with
    | Buy -> t.bids <- Hash_set.create (module Client_order_id)
    | Sell -> t.asks <- Hash_set.create (module Client_order_id)
  in
  let print_books () =
    print_endline [%string "\nSTART ===================="];
    print_endline [%string "Inventory: %{!(t.inventory)#Int}\n"];
    print_string [%string "\nBIDS: "];
    Hash_set.iter t.bids ~f:(fun client_order_id ->
      print_string
        [%string "%{(Client_order_id.to_int client_order_id)#Int}, "]);
    print_string [%string "\nASKS: "];
    Hash_set.iter t.asks ~f:(fun client_order_id ->
      print_string
        [%string "%{(Client_order_id.to_int client_order_id)#Int}, "]);
    print_endline [%string "\nEND ===================="]
  in
  (* This is the function that handles all events *)
  let trading_function event =
    let%bind () =
      match (event : Exchange_event.t) with
      | Order_accept { order_id = _; request } ->
        t.inventory := !(t.inventory) + 1;
        (match request.side with
         | Buy -> return (Hash_set.add t.bids request.client_order_id)
         | Sell -> return (Hash_set.add t.asks request.client_order_id))
      | Best_bid_offer_update _ ->
        return
          () (* TODO: maybe adjust some of the config stuff based on BBO *)
      | Order_cancel cancel_info ->
        Hash_set.remove t.bids cancel_info.client_order_id;
        return (Hash_set.remove t.asks cancel_info.client_order_id)
      | Fill fill ->
        let side, client_order_id = get_side_client_order_id fill in
        update_books side client_order_id;
        cancel_all_orders side;
        seed_book
          { config with
            fair_value_cents =
              config.fair_value_cents
              - (!(t.inventory) * config.inventory_skew_cents_per_share)
          }
          conn
      | Order_reject _ | Trade_report _ | Cancel_reject _ -> return ()
    in
    let () = if testing then print_books () else () in
    return ()
  in
  let%bind session_feed, _metadata =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc conn ()
  in
  let%bind () = seed_book config conn in
  (* initial ladder *)
  don't_wait_for (Pipe.iter session_feed ~f:trading_function);
  if testing then return () else Deferred.never ()
;;
