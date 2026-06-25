open! Core
open Jsip_types


(* We store an additional client_order_id_lookup so the matching machine can easily create Fill events (which require client order ids) from orders (which do not have client order ids for anonymity) *)
type t =
  { books : Order_book.t Symbol.Map.t
  ; order_id_gen : Order_id.Generator.t
  ; mutable next_fill_id : int
  ; client_order_id_sets : Client_order_id.t Hash_set.t Participant.Table.t
  ; client_order_id_lookup : Client_order_id.t Order_id.Table.t
  }
[@@deriving sexp_of]


let create symbols =
  let books =
    List.map symbols ~f:(fun sym -> sym, Order_book.create sym)
    |> Symbol.Map.of_alist_exn
  in
  { books
  ; order_id_gen = Order_id.Generator.create ()
  ; next_fill_id = 1
  ; client_order_id_sets = Hashtbl.create (module Participant)
  ; client_order_id_lookup = Hashtbl.create (module Order_id)
  }
;;

let book t symbol = Map.find t.books symbol

(* These are client_order_id functions to interact with the sets and lookup  *)
let validate_client_id t (request : Order.Request.t) =
  let client_order_id = request.client_order_id in
  let participant = request.participant in
  let client_order_id_set =
    Hashtbl.find_or_add
      t.client_order_id_sets
      participant
      ~default:(fun () -> Hash_set.create (module Client_order_id))
  in
  let is_duplicate =
    match
      Hash_set.find client_order_id_set ~f:(fun x ->
        Client_order_id.equal x client_order_id)
    with
    | None -> false
    | Some _ -> true
  in
  is_duplicate
;;

let get_client_order_id t order_id = Hashtbl.find_exn t.client_order_id_lookup order_id
   

let add_client_order_id t client_order_id order = 
  let order_id = Order.order_id order in 
  let participant = Order.participant order in 
  let client_set = Hashtbl.find_or_add t.client_order_id_sets participant ~default(fun () -> Hash_set.create (module Client_order_id)) in 
  Hash_set.add client_set client_order_id;
  ignore(Hashtbl.add t.client_order_id_lookup ~key:order_id ~data:client_order_id);
  ()

(** Run the matching loop: repeatedly find a compatible resting order and
    fill against it. Returns the list of Fill and Trade_report events
    produced, and the next fill_id to use. *)
let rec match_loop ~book ~order ~fill_id =
  if Size.( <= ) (Order.remaining_size order) Size.zero
  then [], fill_id
  else (
    match Order_book.find_match book order with
    | None -> [], fill_id
    | Some resting ->
      let fill_size =
        Size.min (Order.remaining_size order) (Order.remaining_size resting)
      in
      Order.fill order ~by:fill_size;
      Order.fill resting ~by:fill_size;
      if Order.is_fully_filled resting
      then Order_book.remove book (Order.order_id resting);
      let aggressor_client_order_id, resting_client_order_id = get_client_order_id 
      let fill_event =
        Exchange_event.Fill
          { fill_id
          ; symbol = Order.symbol order
          ; price = Order.price resting
          ; size = fill_size
          ; aggressor_order_id = Order.order_id order
          ; aggressor_client_order_id
          ; aggressor_participant = Order.participant order
          ; aggressor_side = Order.side order
          ; resting_order_id = Order.order_id resting
          ; resting_client_order_id
          ; resting_participant = Order.participant resting
          }
      in
      let trade_event =
        Exchange_event.Trade_report
          { symbol = Order.symbol order
          ; price = Order.price resting
          ; size = fill_size
          }
      in
      let remaining_events, next_fill_id =
        match_loop ~book ~order ~fill_id:(fill_id + 1)
      in
      fill_event :: trade_event :: remaining_events, next_fill_id)
;;



let submit t (request : Order.Request.t) =
  match Map.find t.books request.symbol with
  | None ->
    [ Exchange_event.Order_reject { request; reason = "unknown symbol" } ]
  | Some book ->
    let order_id = Order_id.Generator.next t.order_id_gen in
    let order = Order.create request ~order_id in
    let accept_or_reject =
      if validate_client_id t request
      then (
        let add_client_order_id = in 
        Exchange_event.Order_accept { order_id; request })
      else
        Exchange_event.Order_reject
          { request; reason = "Duplicate client order ID" }
    in
    (* Snapshot BBO before matching so we can detect changes. *)
    let bbo_before = Order_book.best_bid_offer book in
    (* Match *)
    let fill_events, next_fill_id =
      match_loop ~book ~order ~fill_id:t.next_fill_id ()
    in
    t.next_fill_id <- next_fill_id;
    (* Post-match: rest on book or cancel unfilled remainder. *)
    let post_events =
      if Size.( > ) (Order.remaining_size order) Size.zero
      then (
        match Order.time_in_force order with
        | Day ->
          Order_book.add book order;
          []
        | Ioc ->
          [ Exchange_event.Order_cancel
              { order_id
              ; participant = Order.participant order
              ; symbol = Order.symbol order
              ; remaining_size = Order.remaining_size order
              ; reason = Ioc_remainder
              }
          ])
      else []
    in
    (* Emit BBO update if the best bid or ask changed. *)
    let bbo_after = Order_book.best_bid_offer book in
    let bbo_events =
      if Bbo.equal bbo_before bbo_after
      then []
      else
        [ Exchange_event.Best_bid_offer_update
            { symbol = Order.symbol order; bbo = bbo_after }
        ]
    in
    List.concat
      [ [ accept_or_reject ]; fill_events; post_events; bbo_events ]
;;
