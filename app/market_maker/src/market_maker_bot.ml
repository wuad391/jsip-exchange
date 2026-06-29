open! Core
open! Async
open Jsip_types
open Jsip_gateway
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle
module News_injector = Jsip_news_injector.News_injector
module Bot_runtime = Jsip_bot_runtime.Bot_runtime

type symbol_state =
  { mutable asks : Client_order_id.t Hash_set.t
  ; mutable bids : Client_order_id.t Hash_set.t
  ; inventory : Int.t Ref.t
  }
[@@deriving sexp_of]

module Config = struct
  type t =
    { symbol : Symbol.t
    ; fair_value_cents : int
    ; half_spread_cents : int
    ; size_per_level : int
    ; num_levels : int
    ; inventory_skew_cents_per_share : int
    ; state : symbol_state Symbol.Table.t
    ; client_order_id_ref : Int.t Ref.t
    }
  [@@deriving sexp_of]
end

let state = Hashtbl.create (module Symbol)
let name = "Market Maker"

let new_client_order_id config =
  config.client_order_id_ref := !(config.client_order_id_ref) + 1
;;

let seed_book (config : Config.t) =
  Deferred.List.iter
    ~how:`Parallel
    (List.init config.num_levels ~f:Fn.id)
    ~f:(fun level ->
      let offset = config.half_spread_cents + level in
      let%bind () =
        Context.submit
          context
          ([ { symbol = config.symbol
             ; participant = Context.participant context
             ; side = Buy
             ; price = Price.of_int_cents (config.fair_value_cents - offset)
             ; size = Size.of_int config.size_per_level
             ; time_in_force = Day
             ; client_order_id = new_client_order_id config
             }
           ]
           : Order.Request.t)
      and () =
        Context.submit
          context
          ([ { symbol = config.symbol
             ; participant = config.participant
             ; side = Sell
             ; price = Price.of_int_cents (config.fair_value_cents + offset)
             ; size = Size.of_int config.size_per_level
             ; time_in_force = Day
             ; client_order_id = new_client_order_id ()
             }
           ]
           : Order.Request.t)
      in
      Deferred.unit)
;;

let on_start config _context = seed_book config

(* I dont think this will actually do anything for MM bc we react to events *)
let on_tick _ _ = return ()

(* Internal helper functions start *)

(* Precondition: only call if the state exists *)
(* TODO there has got to be a better way to do this *)
let get_symbol_state (config : Config.t) symbol =
  Hashtbl.find_exn config.state symbol
;;

(* Precondition: only call if the state exists *)
(* TODO there has got to be a better way to do this *)
let get_symbol_inventory (config : Config.t) symbol =
  let { asks = _; bids = _; inventory } =
    Hashtbl.find_exn config.state symbol
  in
  inventory
;;

(* Precondition: only call if the state exists *)
(* TODO there has got to be a better way to do this *)
let get_symbol_asks (config : Config.t) symbol =
  let { asks; bids = _; inventory = _ } =
    Hashtbl.find_exn config.state symbol
  in
  asks
;;

(* Precondition: only call if the state exists *)
(* TODO there has got to be a better way to do this *)
let get_symbol_bids (config : Config.t) symbol =
  let { asks = _; bids; inventory = _ } =
    Hashtbl.find_exn config.state symbol
  in
  bids
;;

let on_event config context event =
  let participant = Context.participant context in
  let get_side_client_order_id (fill : Fill.t) =
    if Participant.equal fill.aggressor_participant participant
    then fill.aggressor_side, fill.aggressor_client_order_id
    else Side.flip fill.aggressor_side, fill.resting_client_order_id
  in
  (* update_books is used when something gets filled *)
  let update_books side symbol client_order_id : unit =
    let { asks; bids; inventory } = get_symbol_state config symbol in
    Hash_set.remove bids client_order_id;
    Hash_set.remove asks client_order_id;
    (* TODO i do not think this is going to work *)
    inventory
    := !inventory + match (side : Side.t) with Buy -> 1 | Sell -> -1
  in
  let cancel_all_orders side symbol =
    let { asks; bids; inventory } = get_symbol_state config symbol in
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
    | Buy -> bids <- Hash_set.create (module Client_order_id)
    | Sell -> asks <- Hash_set.create (module Client_order_id)
  in
  let print_books () =
    Hashtbl.iter config.state ~f:(fun { asks; bids; inventory } ->
      print_endline [%string "\nSTART ===================="];
      print_endline [%string "Inventory: %{!(inventory)#Int}\n"];
      print_string [%string "\nBIDS: "];
      Hash_set.iter bids ~f:(fun client_order_id ->
        print_string
          [%string "%{(Client_order_id.to_int client_order_id)#Int}, "]);
      print_string [%string "\nASKS: "];
      Hash_set.iter asks ~f:(fun client_order_id ->
        print_string
          [%string "%{(Client_order_id.to_int client_order_id)#Int}, "]);
      print_endline [%string "\nEND ===================="])
  in
  (* This is the function that handles all events *)
  let trading_function event =
    let%bind () =
      match (event : Exchange_event.t) with
      | Order_accept { order_id = _; request } ->
        let { asks; bids; inventory } =
          get_symbol_state config request.symbol
        in
        inventory := !inventory + 1;
        (match request.side with
         | Buy -> return (Hash_set.add bids request.client_order_id)
         | Sell -> return (Hash_set.add asks request.client_order_id))
      | Best_bid_offer_update _ ->
        return ()
        (* TODO: maybe adjust some of the config stuff based on BBO *)
      | Order_cancel cancel_info ->
        let { asks; bids; inventory = _ } =
          get_symbol_state config cancel_info.symbol
        in
        Hash_set.remove bids cancel_info.client_order_id;
        return (Hash_set.remove asks cancel_info.client_order_id)
      | Fill fill ->
        let inventory = get_symbol_inventory config fill.symbol in
        let side, client_order_id = get_side_client_order_id fill in
        update_books side fill.symbol client_order_id;
        cancel_all_orders side fill.symbol;
        seed_book
          { config with
            fair_value_cents =
              config.fair_value_cents
              - (!inventory * config.inventory_skew_cents_per_share)
          }
      | Order_reject _ | Trade_report _ | Cancel_reject _ -> return ()
    in
    return ()
  in
  trading_function
;;
