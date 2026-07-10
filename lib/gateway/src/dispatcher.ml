open! Core
open! Async
open Jsip_types

module Config = struct
  type t =
    { market_data : Bounded_pipe.Limit.t
    ; audit : Bounded_pipe.Limit.t
    ; session : Bounded_pipe.Limit.t
    }
  [@@deriving sexp_of]

  let uniform (limit : Bounded_pipe.Limit.t) : t =
    { market_data = limit; audit = limit; session = limit }
  ;;

  (* Two shapes of stream, two policies.

     Market data is a best-effort public feed of *supersedable* values — a
     newer BBO or trade print obsoletes an older one — so a consumer that
     briefly stalls can miss ticks without real harm. Drop the newest events
     once it is behind, exactly as {!Metrics} does for its stats feed.
     (Dropping the *oldest* would suit market data even better, but the
     writer side of an {!Async.Pipe} cannot pop its buffer — see
     {!Bounded_pipe}.)

     Session and audit feeds are *ledgers*: a client's own order/fill
     acknowledgements, and the operator's complete event record. Silently
     dropping from either misleads the reader about what actually happened,
     so when a consumer falls hopelessly behind we disconnect it and let it
     reconnect and resync rather than lie by omission.

     Caps are per-consumer buffer ceilings, sized so a healthy client never
     reaches them; the audit firehose (every event) gets the most headroom. *)
  let market_data_max_length = 256
  let session_max_length = 256
  let audit_max_length = 1024

  let default : t =
    { market_data =
        { max_length = market_data_max_length
        ; policy = Bounded_pipe.Policy.Drop_newest
        }
    ; audit =
        { max_length = audit_max_length
        ; policy = Bounded_pipe.Policy.Disconnect
        }
    ; session =
        { max_length = session_max_length
        ; policy = Bounded_pipe.Policy.Disconnect
        }
    }
  ;;
end

type t =
  { market_data_subscribers_by_symbol :
      Exchange_event.t Pipe.Writer.t Bag.t Symbol_id.Table.t
  ; audit_subscribers : Exchange_event.t Pipe.Writer.t Bag.t
  ; sessions : Session.t Participant.Table.t
  ; config : Config.t
  }

let create config =
  { market_data_subscribers_by_symbol = Symbol_id.Table.create ()
  ; audit_subscribers = Bag.create ()
  ; sessions = Participant.Table.create ()
  ; config
  }
;;

let clean_up_session t session =
  let participant = Session.participant session in
  Hashtbl.remove t.sessions participant;
  return (Session.close session)
;;

let set_up_session t participant =
  let has_active_session = Hashtbl.find t.sessions participant in
  let%bind () =
    match has_active_session with
    | None -> return ()
    | Some old_session -> clean_up_session t old_session
  in
  let new_session = Session.create participant ~limit:t.config.session in
  let () = Hashtbl.add_exn t.sessions ~key:participant ~data:new_session in
  return ()
;;

let subscribe_market_data t symbols =
  let reader, writer = Pipe.create () in
  (* Register the same writer in every requested symbol's bag. A per-symbol
     publish iterates a single bag, so a subscriber listed in multiple bags
     receives each event exactly once — only via whichever bag matches the
     event's symbol. *)
  let elts =
    List.map symbols ~f:(fun symbol ->
      let subscribers =
        Hashtbl.find_or_add
          t.market_data_subscribers_by_symbol
          ~default:Bag.create
          symbol
      in
      symbol, Bag.add subscribers writer)
  in
  don't_wait_for
    (let%map () = Pipe.closed writer in
     List.iter elts ~f:(fun (symbol, elt) ->
       match Hashtbl.find t.market_data_subscribers_by_symbol symbol with
       | None -> ()
       | Some subscribers -> Bag.remove subscribers elt));
  reader
;;

let subscribe_audit t =
  let reader, writer = Pipe.create () in
  let elt = Bag.add t.audit_subscribers writer in
  don't_wait_for
    (let%map () = Pipe.closed writer in
     Bag.remove t.audit_subscribers elt);
  reader
;;

let push_market_data t event symbol =
  match Hashtbl.find t.market_data_subscribers_by_symbol symbol with
  | None -> ()
  | Some subscribers ->
    Bag.iter subscribers ~f:(fun writer ->
      Bounded_pipe.push writer ~limit:t.config.market_data event)
;;

let push_audit t event =
  Bag.iter t.audit_subscribers ~f:(fun writer ->
    Bounded_pipe.push writer ~limit:t.config.audit event)
;;

let is_active t participant =
  match Hashtbl.find t.sessions participant with
  | None -> false
  | Some _ -> true
;;

let lookup_session t = Hashtbl.find t.sessions

let push_to_session t participant event =
  let find_session = Hashtbl.find t.sessions participant in
  match find_session with
  | None -> ()
  | Some session -> Session.push session event
;;

let dispatch_event t (event : Exchange_event.t) =
  push_audit t event;
  match event with
  | Best_bid_offer_update { symbol; bbo = _ } ->
    push_market_data t event symbol
  | Trade_report { symbol; price = _; size = _ } ->
    push_market_data t event symbol
  | Order_accept { order_id = _; participant; request = _ }
  | Order_reject { participant; request = _; reason = _ } ->
    push_to_session t participant event
  | Order_cancel
      { order_id = _
      ; participant
      ; symbol = _
      ; remaining_size = _
      ; reason = _
      ; client_order_id = _
      } ->
    push_to_session t participant event
  | Fill
      { fill_id = _
      ; symbol = _
      ; price = _
      ; size = _
      ; aggressor_order_id = _
      ; aggressor_client_order_id = _
      ; aggressor_participant
      ; aggressor_side = _
      ; resting_order_id = _
      ; resting_client_order_id = _
      ; resting_participant
      } ->
    push_to_session t aggressor_participant event;
    push_to_session t resting_participant event
  | Cancel_reject { participant; client_order_id = _; reason = _ } ->
    push_to_session t participant event
;;

let dispatch t events = List.iter events ~f:(dispatch_event t)

let audit_queue_lengths t =
  Bag.fold t.audit_subscribers ~init:[] ~f:(fun acc writer ->
    Pipe.length writer :: acc)
;;

(* A market-data subscriber to N symbols is registered as the *same* physical
   writer in N per-symbol bags (see [subscribe_market_data]), but it is one
   pipe with one buffer. Dedup by writer identity before measuring, so a
   monitor listening to every symbol counts as one pipe at its true depth,
   not N pipes at N times the depth. Physical equality is exactly right here:
   it is the same writer value added to each bag. The dedup is O(pipes^2),
   bounded by the handful of live market-data subscribers. *)
let market_data_queue_lengths t =
  let distinct_writers =
    Hashtbl.fold
      t.market_data_subscribers_by_symbol
      ~init:[]
      ~f:(fun ~key:_ ~data:subscribers acc ->
        Bag.fold subscribers ~init:acc ~f:(fun acc writer ->
          if List.mem acc writer ~equal:phys_equal
          then acc
          else writer :: acc))
  in
  List.map distinct_writers ~f:Pipe.length
;;

let session_queue_lengths t =
  Hashtbl.fold t.sessions ~init:[] ~f:(fun ~key:_ ~data:session acc ->
    Session.queue_length session :: acc)
;;

module For_testing = struct
  let audit_subscriber_count t = Bag.length t.audit_subscribers
end
