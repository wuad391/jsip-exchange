open! Core
open Jsip_types

(* Ex4 phase 1: symbols are ints end-to-end, so a caller handing us a
   Symbol_id.t already has the array index — there is no name left to hash. A
   lookup is a bounds check plus an O(1) array index, nothing else. *)
module Symbol_registry = struct
  type t = { books : Order_book.t array } [@@deriving sexp_of]

  let create (num_symbols : int) : t =
    { books =
        Array.init num_symbols ~f:(fun i ->
          Order_book.create (Symbol_id.of_int i))
    }
  ;;

  let find t symbol_id =
    let i = Symbol_id.to_int symbol_id in
    if i >= 0 && i < Array.length t.books then Some t.books.(i) else None
  ;;
end

(* We store an additional client_order_id_lookup so the matching machine can
   easily create Fill events (which require client order ids) from orders
   (which do not have client order ids for anonymity) *)
type t =
  { symbols : Symbol_registry.t
  ; order_id_gen : Order_id.Generator.t
  ; mutable next_fill_id : int
  ; client_order_tables : Order.t Client_order_id.Table.t Participant.Table.t
  ; client_order_id_lookup : Client_order_id.t Order_id.Table.t
  }
[@@deriving sexp_of]

let create symbols =
  { symbols = Symbol_registry.create symbols
  ; order_id_gen = Order_id.Generator.create ()
  ; next_fill_id = 1
  ; client_order_tables = Hashtbl.create (module Participant)
  ; client_order_id_lookup = Hashtbl.create (module Order_id)
  }
;;

let book t symbol = Symbol_registry.find t.symbols symbol

let resting_order_counts t =
  Hashtbl.fold
    t.client_order_tables
    ~init:Participant.Map.empty
    ~f:(fun ~key:participant ~data:client_order_table acc ->
      match Hashtbl.length client_order_table with
      | 0 -> acc
      | count -> Map.set acc ~key:participant ~data:count)
;;

(* These are client_order_id functions to interact with the sets and lookup *)
let validate_client_id t ~participant (request : Order.Request.t) =
  match Hashtbl.find t.client_order_tables participant with
  | None -> true
  | Some client_order_table ->
    not (Hashtbl.mem client_order_table request.client_order_id)
;;

let get_client_order t participant client_order_id =
  let client_order_table_opt =
    Hashtbl.find t.client_order_tables participant
  in
  match client_order_table_opt with
  | None -> None
  | Some table -> Hashtbl.find table client_order_id
;;

let remove_client_order t participant client_order_id =
  let client_order_table_opt =
    Hashtbl.find t.client_order_tables participant
  in
  match client_order_table_opt with
  | None -> ()
  | Some table ->
    let client_order_opt = Hashtbl.find_and_remove table client_order_id in
    (match client_order_opt with
     | None -> ()
     | Some client_order ->
       Hashtbl.remove t.client_order_id_lookup (Order.order_id client_order))
;;

(* Precondition: [order_id] is registered in [client_order_id_lookup]. This
   holds for every order we look up here — [add_client_order] registers an
   order the moment it can rest, and it stays registered until it is fully
   filled or cancelled (see [remove_client_order]). Looking up an
   unregistered id is an internal invariant violation, so we raise with the
   offending id rather than returning an option a caller could quietly drop. *)
let get_client_order_id t order_id =
  match Hashtbl.find t.client_order_id_lookup order_id with
  | Some client_order_id -> client_order_id
  | None ->
    raise_s
      [%message
        "Matching_engine.get_client_order_id: order_id not registered"
          (order_id : Order_id.t)]
;;

let add_client_order t client_order_id order =
  let order_id = Order.order_id order in
  let participant = Order.participant order in
  let client_order_table =
    Hashtbl.find_or_add t.client_order_tables participant ~default:(fun () ->
      Hashtbl.create (module Client_order_id))
  in
  Hashtbl.add_exn client_order_table ~key:client_order_id ~data:order;
  Hashtbl.add_exn
    t.client_order_id_lookup
    ~key:order_id
    ~data:client_order_id
;;

(* END client order id functions *)

(** Run the matching loop: repeatedly find a compatible resting order and
    fill against it. Returns the list of Fill and Trade_report events
    produced, and the next fill_id to use. *)
let rec match_loop t ~book ~order ~fill_id =
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
      let aggressor_client_order_id, resting_client_order_id =
        ( get_client_order_id t (Order.order_id order)
        , get_client_order_id t (Order.order_id resting) )
      in
      if Order.is_fully_filled resting
      then (
        Order_book.remove book (Order.order_id resting);
        remove_client_order
          t
          (Order.participant resting)
          resting_client_order_id);
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
        match_loop t ~book ~order ~fill_id:(fill_id + 1)
      in
      fill_event :: trade_event :: remaining_events, next_fill_id)
;;

let cancel t ({ participant; client_order_id } : Order.Cancel.t) =
  let client_order_opt = get_client_order t participant client_order_id in
  match client_order_opt with
  | None ->
    [ Exchange_event.Cancel_reject
        { participant
        ; client_order_id
        ; reason = "Cannot cancel non-existent order"
        }
    ]
  | Some order ->
    let order_id = Order.order_id order in
    let symbol = Order.symbol order in
    (* The symbol comes from a valid order which => there exists a book with
       that order *)
    let book = Option.value_exn (book t symbol) in
    let bbo = Order_book.best_bid_offer book in
    Order_book.remove book order_id;
    remove_client_order t participant client_order_id;
    let new_bbo = Order_book.best_bid_offer book in
    let cancel_event =
      Exchange_event.Order_cancel
        { order_id
        ; participant
        ; symbol
        ; remaining_size = Order.remaining_size order
        ; reason = Cancel_reason.Participant_requested
        ; client_order_id
        }
    in
    if Bbo.equal bbo new_bbo
    then [ cancel_event ]
    else
      [ cancel_event
      ; Exchange_event.Best_bid_offer_update { symbol; bbo = new_bbo }
      ]
;;

let cancel_all_for_participant t participant =
  match Hashtbl.find t.client_order_tables participant with
  | None -> 0, []
  | Some client_order_table ->
    (* Snapshot before sweeping: each removal below mutates
       [client_order_table] via [remove_client_order], and removing from a
       table while iterating it would skip entries. Sort by [Order_id.t] so
       orders are cancelled in submission order — a hash table iterates in
       unspecified order, and the sweep's events should be deterministic. *)
    let resting =
      Hashtbl.to_alist client_order_table
      |> List.sort ~compare:(fun (_, order) (_, order') ->
        Order_id.compare (Order.order_id order) (Order.order_id order'))
    in
    (* Record each touched symbol's BBO once, before its first removal, and
       emit at most one [Best_bid_offer_update] per changed symbol after the
       whole sweep — pulling a ladder of N orders must not spam N BBO events
       the way N single [cancel]s would. *)
    let pre_bbos = Symbol_id.Table.create () in
    let touched = Queue.create () in
    let record_pre_bbo symbol book =
      if not (Hashtbl.mem pre_bbos symbol)
      then (
        Hashtbl.add_exn
          pre_bbos
          ~key:symbol
          ~data:(Order_book.best_bid_offer book);
        Queue.enqueue touched (symbol, book))
    in
    let cancel_events =
      List.map resting ~f:(fun (client_order_id, order) ->
        let order_id = Order.order_id order in
        let symbol = Order.symbol order in
        (* The order was resting, so its symbol's book must exist. *)
        let book = Option.value_exn (book t symbol) in
        (* Before either removal: the post-sweep comparison needs the
           symbol's true starting BBO. *)
        record_pre_bbo symbol book;
        Order_book.remove book order_id;
        remove_client_order t participant client_order_id;
        Exchange_event.Order_cancel
          { order_id
          ; client_order_id
          ; participant
          ; symbol
          ; remaining_size = Order.remaining_size order
          ; reason = Cancel_reason.Mass_cancel
          })
    in
    let bbo_events =
      Queue.to_list touched
      |> List.filter_map ~f:(fun (symbol, book) ->
        let bbo = Order_book.best_bid_offer book in
        if Bbo.equal (Hashtbl.find_exn pre_bbos symbol) bbo
        then None
        else Some (Exchange_event.Best_bid_offer_update { symbol; bbo }))
    in
    List.length cancel_events, cancel_events @ bbo_events
;;

let submit t ~participant (request : Order.Request.t) =
  (* Identity is server-authoritative: overwrite whatever participant the
     client put in the request with the [~participant] established at login,
     so an order is attributed to the authenticated session rather than a
     client-supplied name. *)
  let request = { request with participant } in
  if Price.(request.price < zero)
  then
    [ Exchange_event.Order_reject
        { participant; request; reason = "negative price" }
    ]
  else (
    match book t request.symbol with
    | None ->
      [ Exchange_event.Order_reject
          { participant; request; reason = "unknown symbol" }
      ]
    | Some book ->
      let order_id = Order_id.Generator.next t.order_id_gen in
      let order = Order.create request ~order_id in
      if not (validate_client_id t ~participant request)
      then
        [ Exchange_event.Order_reject
            { participant; request; reason = "Duplicate client order ID" }
        ]
      else (
        add_client_order t request.client_order_id order;
        let accepted_event =
          Exchange_event.Order_accept { order_id; participant; request }
        in
        (* Snapshot BBO before matching so we can detect changes. *)
        let bbo_before = Order_book.best_bid_offer book in
        (* Match *)
        let fill_events, next_fill_id =
          match_loop t ~book ~order ~fill_id:t.next_fill_id
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
              remove_client_order t participant request.client_order_id;
              [ Exchange_event.Order_cancel
                  { order_id
                  ; participant = Order.participant order
                  ; symbol = Order.symbol order
                  ; remaining_size = Order.remaining_size order
                  ; reason = Ioc_remainder
                  ; client_order_id = request.client_order_id
                  }
              ])
          else (
            remove_client_order t participant request.client_order_id;
            [])
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
          [ [ accepted_event ]; fill_events; post_events; bbo_events ]))
;;
