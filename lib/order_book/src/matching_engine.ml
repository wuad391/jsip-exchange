open! Core
open Jsip_types

(* We store an additional client_order_id_lookup so the matching machine can
   easily create Fill events (which require client order ids) from orders
   (which do not have client order ids for anonymity) *)
type t =
  { books : Order_book.t Symbol.Map.t
  ; order_id_gen : Order_id.Generator.t
  ; mutable next_fill_id : int
  ; client_order_tables : Order.t Client_order_id.Table.t Participant.Table.t
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
  ; client_order_tables = Hashtbl.create (module Participant)
  ; client_order_id_lookup = Hashtbl.create (module Order_id)
  }
;;

let book t symbol = Map.find t.books symbol

(* These are client_order_id functions to interact with the sets and lookup *)
let validate_client_id t (request : Order.Request.t) =
  let client_order_id = request.client_order_id in
  let participant = request.participant in
  let client_order_table =
    Hashtbl.find_or_add t.client_order_tables participant ~default:(fun () ->
      Hashtbl.create (module Client_order_id))
  in
  let is_duplicate =
    match Hashtbl.find client_order_table client_order_id with
    | None -> false
    | Some _ -> true
  in
  not is_duplicate
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

(* TODO: currently, there is a precondition that this order_id must exist in
   the table. this is very bad *)
let get_client_order_id t order_id =
  Hashtbl.find_exn t.client_order_id_lookup order_id
;;

let add_client_order t client_order_id order =
  let order_id = Order.order_id order in
  let participant = Order.participant order in
  let client_order_table =
    Hashtbl.find_or_add t.client_order_tables participant ~default:(fun () ->
      Hashtbl.create (module Client_order_id))
  in
  ignore (Hashtbl.add client_order_table ~key:client_order_id ~data:order);
  ignore
    (Hashtbl.add
       t.client_order_id_lookup
       ~key:order_id
       ~data:client_order_id);
  ()
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
        (* match *)
        ( get_client_order_id t (Order.order_id order)
        , get_client_order_id t (Order.order_id resting) )
        (* with | Some id1, Some id2 -> id1, id2 | _ -> raise (Exn.of_string
           "Client order ID missing") *)
      in
      (* XCR claude for robyn: [remove_client_order] used to sit *outside* this
         [if] (dangling [then]), so a partially-filled resting order got evicted
         from the client tables while still resting on the book — the owner
         could no longer cancel it, and a later fill against it crashed via
         [get_client_order_id]'s [find_exn]. Both removals are now guarded by
         [then], so they only fire on a full fill.

         robyn: fixed. (Small style nit: the [else ()] below can be dropped —
         house style is no [else ()] for a unit [then].) *)
      if Order.is_fully_filled resting
      then (
        Order_book.remove book (Order.order_id resting);
        remove_client_order
          t
          (Order.participant resting)
          resting_client_order_id)
      else ();
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
    let () = Order_book.remove book order_id in
    let () = remove_client_order t participant client_order_id in
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

let submit t (request : Order.Request.t) =
  match book t request.symbol with
  | None ->
    [ Exchange_event.Order_reject { request; reason = "unknown symbol" } ]
  | Some book ->
    let order_id = Order_id.Generator.next t.order_id_gen in
    let order = Order.create request ~order_id in
    if not (validate_client_id t request)
    then
      [ Exchange_event.Order_reject
          { request; reason = "Duplicate client order ID" }
      ]
    else (
      add_client_order t request.client_order_id order;
      let accepted_event =
        Exchange_event.Order_accept { order_id; request }
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
            remove_client_order t request.participant request.client_order_id;
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
          remove_client_order t request.participant request.client_order_id;
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
        [ [ accepted_event ]; fill_events; post_events; bbo_events ])
;;
