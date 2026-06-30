open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime
module Context = Bot_runtime.Context

type symbol_state =
  { mutable asks : Client_order_id.t Hash_set.t
  ; mutable bids : Client_order_id.t Hash_set.t
  ; inventory : Int.t Ref.t
  ; fair_value_cents : int
  ; bbo : Bbo.t
  }
[@@deriving sexp_of]

module Config = struct
  type t =
    { size_per_level : int
    ; num_levels : int
    ; inventory_skew_cents_per_share : int
    ; state : symbol_state Symbol.Table.t
    ; client_order_id_ref : Int.t Ref.t
    }
  [@@deriving sexp_of]
end

let name = "Market Maker"

(* ...................Internal helper function start........................ *)
let new_state (config : Config.t) (context : Bot_runtime.Context.t) symbol =
  { inventory = ref 0
  ; asks = Hash_set.create (module Client_order_id) ~size:config.num_levels
  ; bids = Hash_set.create (module Client_order_id) ~size:config.num_levels
  ; fair_value_cents =
      Price.to_int_cents (Bot_runtime.Context.fundamental context symbol)
  ; bbo = Bbo.empty
  }
;;

let get_symbol_state
  (config : Config.t)
  (context : Bot_runtime.Context.t)
  symbol
  =
  Hashtbl.find_or_add config.state symbol ~default:(fun () ->
    new_state config context symbol)
;;

let set_symbol_bids (config : Config.t) context symbol new_bids =
  let symbol_state = get_symbol_state config context symbol in
  symbol_state.bids <- new_bids
;;

let set_symbol_asks (config : Config.t) context symbol new_asks =
  let symbol_state = get_symbol_state config context symbol in
  symbol_state.asks <- new_asks
;;

let set_symbol_inventory (config : Config.t) context symbol new_inventory =
  let { asks = _; bids = _; inventory; fair_value_cents = _; bbo = _ } =
    get_symbol_state config context symbol
  in
  inventory := new_inventory
;;

let new_client_order_id (config : Config.t) =
  config.client_order_id_ref := !(config.client_order_id_ref) + 1;
  !(config.client_order_id_ref)
;;

(* half_spread will default to 50 cents if no BBO exists. *)
let half_spread_cents (bbo : Bbo.t) =
  match Bbo.spread bbo with
  | Some spread ->
    let spread = Price.to_int_cents spread in
    spread / 2
  | None -> 50
;;

let skewed_fair_value (config : Config.t) fair_value_cents inventory =
  fair_value_cents - (!inventory * config.inventory_skew_cents_per_share)
;;

let seed_book
  (config : Config.t)
  (context : Bot_runtime.Context.t)
  (symbols : Symbol.t List.t)
  =
  let _ : unit Deferred.t List.t =
    List.map symbols ~f:(fun symbol ->
      let { asks = _; bids = _; inventory; fair_value_cents; bbo } =
        get_symbol_state config context symbol
      in
      Deferred.List.iter
        ~how:`Parallel
        (List.init config.num_levels ~f:Fn.id)
        ~f:(fun level ->
          let offset = half_spread_cents bbo + level in
          let skewed_fair_value_cents =
            skewed_fair_value config fair_value_cents inventory
          in
          let%bind buy_result =
            Bot_runtime.Context.submit
              context
              ({ symbol
               ; participant = Bot_runtime.Context.participant context
               ; side = Buy
               ; price = Price.of_int_cents (skewed_fair_value_cents - offset)
               ; size = Size.of_int config.size_per_level
               ; time_in_force = Day
               ; client_order_id =
                   new_client_order_id config |> Client_order_id.of_int
               }
               : Order.Request.t)
          and sell_result =
            Bot_runtime.Context.submit
              context
              ({ symbol
               ; participant = Bot_runtime.Context.participant context
               ; side = Sell
               ; price = Price.of_int_cents (skewed_fair_value_cents + offset)
               ; size = Size.of_int config.size_per_level
               ; time_in_force = Day
               ; client_order_id =
                   new_client_order_id config |> Client_order_id.of_int
               }
               : Order.Request.t)
          in
          (match buy_result with
           | Ok _ok -> ()
           | Error err ->
             [%log.error "Buy failed: " (err : Error.t)];
             ());
          match sell_result with
          | Ok _ok -> return ()
          | Error err ->
            [%log.error "Sell failed: " (err : Error.t)];
            return ()))
  in
  return ()
;;

let on_start config context =
  seed_book config context (Hashtbl.keys config.state)
;;

(* I dont think this will actually do anything for MM bc we react to events *)
let on_tick _ _ = return ()

let on_event config context event =
  let participant = Context.participant context in
  let get_side_client_order_id (fill : Fill.t) =
    if Participant.equal fill.aggressor_participant participant
    then fill.aggressor_side, fill.aggressor_client_order_id
    else Side.flip fill.aggressor_side, fill.resting_client_order_id
  in
  (* update_books is used when something gets filled *)
  let update_books side symbol client_order_id : unit =
    let { asks; bids; inventory; fair_value_cents = _; bbo = _ } =
      get_symbol_state config context symbol
    in
    Hash_set.remove bids client_order_id;
    Hash_set.remove asks client_order_id;
    inventory
    := !inventory + match (side : Side.t) with Buy -> 1 | Sell -> -1
  in
  let cancel_all_orders side symbol =
    let { asks; bids; inventory = _; fair_value_cents = _; bbo = _ } =
      get_symbol_state config context symbol
    in
    let client_order_id_set =
      match (side : Side.t) with Buy -> bids | Sell -> asks
    in
    (* TODO: This is a very janky way of iterating through a hash set but the
       types don't work well in Hash_set.iter *)
    ignore
      (Hash_set.fold client_order_id_set ~init:(return ()) ~f:(fun _ id ->
         let%bind _ = Context.cancel context id in
         return ()));
    match side with
    | Buy ->
      set_symbol_bids
        config
        context
        symbol
        (Hash_set.create (module Client_order_id) ~size:config.num_levels)
    | Sell ->
      set_symbol_asks
        config
        context
        symbol
        (Hash_set.create (module Client_order_id) ~size:config.num_levels)
  in
  (* let print_books () = Hashtbl.iter config.state ~f:(fun
     [{ asks; bids; inventory; fair_value_cents = _; bbo = _ }] ->
     print_endline [%string "\nSTART ===================="]; print_endline
     [%string "Inventory: %{!(inventory)#Int}\n"]; print_string
     [%string "\nBIDS: "]; Hash_set.iter bids ~f:(fun client_order_id ->
     print_string
     [%string "%{(Client_order_id.to_int client_order_id)#Int}, "]);
     print_string [%string "\nASKS: "]; Hash_set.iter asks ~f:(fun
     client_order_id -> print_string
     [%string "%{(Client_order_id.to_int client_order_id)#Int}, "]);
     print_endline [%string "\nEND ===================="]) in *)
  (* This is where we actually match and handle all events *)
  let%bind () =
    match (event : Exchange_event.t) with
    | Order_accept { order_id = _; request } ->
      let { asks; bids; inventory; fair_value_cents = _; bbo = _ } =
        get_symbol_state config context request.symbol
      in
      set_symbol_inventory config context request.symbol (!inventory + 1);
      (match request.side with
       | Buy -> return (Hash_set.add bids request.client_order_id)
       | Sell -> return (Hash_set.add asks request.client_order_id))
    | Best_bid_offer_update _ ->
      return ()
      (* TODO: maybe adjust some of the config stuff based on BBO *)
    | Order_cancel _ ->
      return ()
      (* we only ever initiate cancel when we cancel everything. When we
         cancel everything, the internal books are already maintainted *)
      (* let [{ asks; bids; inventory = _ }] = get_symbol_state config
         cancel_info.symbol in Hash_set.remove bids
         cancel_info.client_order_id; return (Hash_set.remove asks
         cancel_info.client_order_id) *)
    | Fill fill ->
      let side, client_order_id = get_side_client_order_id fill in
      update_books side fill.symbol client_order_id;
      cancel_all_orders side fill.symbol;
      seed_book config context [ fill.symbol ]
    | Order_reject _ | Trade_report _ | Cancel_reject _ -> return ()
  in
  return ()
;;
