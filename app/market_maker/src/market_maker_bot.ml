open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime
module Context = Bot_runtime.Context

(* An event-driven market maker: it reacts to fills rather than ticks (a tick
   only prints the internal books when [print_books] is set). Per-symbol
   state lives in a table keyed by symbol; inventory skew, the shared
   order-id counter, shares per level, and the number of levels are common
   across all symbols. *)

type symbol_state =
  { mutable asks : Client_order_id.t Hash_set.t
  ; mutable bids : Client_order_id.t Hash_set.t
  ; inventory : Int.t Ref.t
  ; mutable fair_value_cents : int
  ; bbo : Bbo.t
  ; mutable quoted : (int * int) option
      (* The [(skewed_fair, half_spread)] our currently-resting ladder was
         placed at, or [None] if we haven't quoted yet. Lets
         [Best_bid_offer_update] decide whether a BBO move actually changes
         where we'd quote, instead of re-seeding on every tick of the market
         -- re-seeding unconditionally would itself move the BBO and trigger
         another re-seed, forever. *)
  ; mutable reseeding : bool
  (* Set for the duration of a cancel-then-reseed cycle for this symbol. A
     fill and a [Best_bid_offer_update] can each trigger a reseed, and both
     involve real RPC round-trips (real [Async] yields), so without this
     guard two reseeds for the same symbol can overlap: the second one's
     [cancel_all_orders] reads [bids]/[asks] before the first one's
     [seed_book] has finished repopulating them, orphaning orders that never
     get cancelled and never get tracked. Left resting, those orphans quote
     at a stale (and, after enough churn, wildly skewed) price and sit
     alongside the fresh ladder, so the book alternates between two unrelated
     price levels. Skipping a reseed while one is already in flight is safe:
     the in-flight one will pick up the current inventory and BBO when it
     re-derives its target from scratch, and further events keep arriving to
     trigger a fresh check afterward. *)
  }
[@@deriving sexp_of]

module Config = struct
  type t =
    { size_per_level : int
    ; num_levels : int
    ; inventory_skew_cents_per_share : int
    ; requote_threshold_cents : int
        (* Hysteresis band: on a BBO move, re-seed only once our target quote
           has drifted at least this far from where our ladder is resting.
           Zero reproduces the old "re-quote on any change" behavior. *)
    ; state : symbol_state Symbol_id.Table.t
    ; client_order_id_ref : Int.t Ref.t
    ; print_books : Bool.t
    }
  [@@deriving sexp_of]
end

let name = "Market Maker"

(* ...................Internal helper function start........................ *)
let update_all_fair_prices (config : Config.t) context =
  Hashtbl.iteri config.state ~f:(fun ~key:symbol ~data:symbol_state ->
    symbol_state.fair_value_cents
    <- Price.to_int_cents (Bot_runtime.Context.fundamental context symbol))
;;

let blank_symbol_state () =
  { inventory = ref 0
  ; asks = Hash_set.create (module Client_order_id)
  ; bids = Hash_set.create (module Client_order_id)
  ; fair_value_cents = 0
  ; bbo = Bbo.empty
  ; quoted = None
  ; reseeding = false
  }
;;

let priced_symbol_state
  (_config : Config.t)
  (context : Bot_runtime.Context.t)
  symbol
  =
  let new_state = blank_symbol_state () in
  new_state.fair_value_cents
  <- Price.to_int_cents (Bot_runtime.Context.fundamental context symbol);
  new_state
;;

let get_symbol_state
  (config : Config.t)
  (context : Bot_runtime.Context.t)
  symbol
  =
  Hashtbl.find_or_add config.state symbol ~default:(fun () ->
    priced_symbol_state config context symbol)
;;

let set_symbol_state (config : Config.t) symbol state =
  Hashtbl.update config.state symbol ~f:(fun _state_opt -> state)
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
  let { asks = _
      ; bids = _
      ; inventory
      ; fair_value_cents = _
      ; bbo = _
      ; quoted = _
      ; reseeding = _
      }
    =
    get_symbol_state config context symbol
  in
  inventory := new_inventory
;;

let new_client_order_id (config : Config.t) =
  config.client_order_id_ref := !(config.client_order_id_ref) + 1;
  !(config.client_order_id_ref)
;;

(* With no BBO to mirror (an empty side), quote this far off fair value. *)
let default_half_spread_cents = 50

(* Floor for the mirrored half-spread. The maker mirrors the market by
   quoting half the current spread on each side, but it is itself the
   dominant liquidity, so as it (and others) tighten the book the measured
   spread collapses toward zero. At zero the maker would quote bid = ask; a
   crossed book makes [Bbo.spread] negative, so it would then quote
   bid *above* ask. Flooring keeps every quote non-crossing and stops that
   feedback. It is load-bearing now that self-trade prevention is in place:
   before, the degenerate quotes self-filled and cleared themselves; now they
   would rest locked and drive the maker to re-seed without end. *)
let min_half_spread_cents = 5

(* Half of the current market spread (what we quote on each side), floored so
   the mirror can never collapse to a zero or crossed quote. *)
let half_spread_cents (bbo : Bbo.t) =
  let mirrored =
    match Bbo.spread bbo with
    | Some spread -> Price.to_int_cents spread / 2
    | None -> default_half_spread_cents
  in
  Int.max mirrored min_half_spread_cents
;;

let skewed_fair_value (config : Config.t) fair_value_cents inventory =
  fair_value_cents - (!inventory * config.inventory_skew_cents_per_share)
;;

(* A skewed quote can go non-positive: enough inventory skew or price levels
   can push [skewed_fair_value_cents -/+ offset] to or below zero, and
   [Price.of_int_cents] will happily wrap a negative number into a [Price.t]
   with no complaint. The exchange now rejects negative-priced orders
   outright (see [Matching_engine.submit]), so an un-clamped quote here would
   just get bounced -- but the market maker should never try to post one in
   the first place. Floor at one cent, the smallest representable price tick,
   matching [Fundamental_oracle.min_price_cents]. *)
let clamp_to_positive_cents cents = Int.max cents 1

(* Would re-seeding actually move our quotes enough to bother? [current] and
   [target] are each a [(skewed_fair, half_spread)] pair; we translate both
   to the inner (top-of-book) bid and ask they imply and answer yes only once
   one of those has drifted at least [threshold] cents from where our ladder
   is resting. Comparing against the resting quote (not the previous tick)
   means slow drift still accumulates past the threshold and re-quotes, while
   the sub-tick flicker the maker's own re-seeds emit is ignored. *)
let requote_warranted ~threshold ~current ~target =
  let inner_bid_ask (fair, half_spread) =
    fair - half_spread, fair + half_spread
  in
  let cur_bid, cur_ask = inner_bid_ask current in
  let tgt_bid, tgt_ask = inner_bid_ask target in
  Int.abs (tgt_bid - cur_bid) >= threshold
  || Int.abs (tgt_ask - cur_ask) >= threshold
;;

(* ....................................................... *)

(* Seeds each symbol's state with fair value 0; [on_start] repopulates the
   real fair values before any quoting. *)
(* A few cents of hysteresis by default: enough to swallow the sub-tick BBO
   churn the maker's own re-seeds create, small enough that real drift still
   re-quotes promptly. *)
let default_requote_threshold_cents = 5

let create_config
  ?(testing = false)
  ?(requote_threshold_cents = default_requote_threshold_cents)
  ()
  ~size_per_level
  ~num_levels
  ~inventory_skew_cents_per_share
  ~symbols
  : Config.t
  =
  let symbol_state_list =
    List.map symbols ~f:(fun symbol -> symbol, blank_symbol_state ())
  in
  { size_per_level
  ; num_levels
  ; inventory_skew_cents_per_share
  ; requote_threshold_cents
  ; state = Hashtbl.of_alist_exn (module Symbol_id) symbol_state_list
  ; client_order_id_ref = ref 0
  ; print_books = testing
  }
;;

let seed_book
  (config : Config.t)
  (context : Bot_runtime.Context.t)
  (symbols : Symbol_id.t List.t)
  =
  let%bind () =
    Deferred.List.iter
      ~how:(`Max_concurrent_jobs 64)
      symbols
      ~f:(fun symbol ->
        let ({ asks
             ; bids
             ; inventory
             ; fair_value_cents
             ; bbo
             ; quoted = _
             ; reseeding = _
             } as symbol_state)
          =
          get_symbol_state config context symbol
        in
        let half_spread = half_spread_cents bbo in
        let skewed_fair_value_cents =
          skewed_fair_value config fair_value_cents inventory
        in
        symbol_state.quoted <- Some (skewed_fair_value_cents, half_spread);
        Deferred.List.iter
          ~how:`Parallel
          (List.init config.num_levels ~f:Fn.id)
          ~f:(fun level ->
            let offset = half_spread + level in
            let buy_client_order_id =
              new_client_order_id config |> Client_order_id.of_int
            in
            let sell_client_order_id =
              new_client_order_id config |> Client_order_id.of_int
            in
            let%bind buy_result =
              Bot_runtime.Context.submit
                context
                ({ symbol
                 ; participant = Context.participant context
                 ; side = Buy
                 ; price =
                     Price.of_int_cents
                       (clamp_to_positive_cents
                          (skewed_fair_value_cents - offset))
                 ; size = Size.of_int config.size_per_level
                 ; time_in_force = Day
                 ; client_order_id = buy_client_order_id
                 }
                 : Order.Request.t)
            and sell_result =
              Bot_runtime.Context.submit
                context
                ({ symbol
                 ; participant = Context.participant context
                 ; side = Sell
                 ; price =
                     Price.of_int_cents
                       (clamp_to_positive_cents
                          (skewed_fair_value_cents + offset))
                 ; size = Size.of_int config.size_per_level
                 ; time_in_force = Day
                 ; client_order_id = sell_client_order_id
                 }
                 : Order.Request.t)
            in
            (* Track resting orders at submit time — the moment they go onto
               the wire — not at [Order_accept]. This keeps the local books
               in sync with what the exchange holds, so [cancel_all_orders]
               can always see (and cancel) a freshly-seeded ladder rather
               than orphaning it while the accepts are still in flight. A
               rejected order never rests, so it is pulled back out in the
               [Order_reject] arm. *)
            (match buy_result with
             | Ok _ok -> Hash_set.add bids buy_client_order_id
             | Error err -> [%log.error "Buy failed: " (err : Error.t)]);
            match sell_result with
            | Ok _ok ->
              Hash_set.add asks sell_client_order_id;
              return ()
            | Error err ->
              [%log.error "Sell failed: " (err : Error.t)];
              return ()))
  in
  return ()
;;

(* Cancels every resting order on both sides for [symbol] and clears the
   local books. We cancel both sides (not just a just-filled one) because a
   fill or a BBO move shifts the skewed fair value, so quotes on *both* sides
   are stale and get re-seeded together — see [reseed]. *)
let cancel_all_orders (config : Config.t) context symbol =
  let { asks
      ; bids
      ; inventory = _
      ; fair_value_cents = _
      ; bbo = _
      ; quoted = _
      ; reseeding = _
      }
    =
    get_symbol_state config context symbol
  in
  let cancel_ids ids =
    Deferred.List.iter ~how:`Sequential (Hash_set.to_list ids) ~f:(fun id ->
      Context.cancel context id >>| (ignore : _ -> unit))
  in
  let%bind () = cancel_ids bids in
  let%bind () = cancel_ids asks in
  set_symbol_bids
    config
    context
    symbol
    (Hash_set.create (module Client_order_id) ~size:config.num_levels);
  set_symbol_asks
    config
    context
    symbol
    (Hash_set.create (module Client_order_id) ~size:config.num_levels);
  return ()
;;

(* Cancel-then-reseed [symbol], guarded so two triggers (the initial seed, a
   fill, a BBO move) can't run this concurrently for the same symbol — see
   [symbol_state.reseeding]. This is the *only* place that seeds or re-seeds
   a book; [on_start] goes through it too, so a [Best_bid_offer_update]
   arriving while the initial seed is still in flight can't race it. *)
let reseed (config : Config.t) context symbol =
  let symbol_state = get_symbol_state config context symbol in
  if symbol_state.reseeding
  then return ()
  else (
    symbol_state.reseeding <- true;
    let%bind () = cancel_all_orders config context symbol in
    let%bind () = seed_book config context [ symbol ] in
    symbol_state.reseeding <- false;
    return ())
;;

let on_start config context =
  update_all_fair_prices config context;
  Deferred.List.iter
    ~how:(`Max_concurrent_jobs 64)
    (Hashtbl.keys config.state)
    ~f:(reseed config context)
;;

(* No tick-driven quoting — the market maker reacts to events. A tick only
   prints the internal books when [print_books] is set. *)
let on_tick (config : Config.t) context =
  let print_books () =
    Hashtbl.iteri
      config.state
      ~f:
        (fun
          ~key:symbol
          ~data:
            { asks
            ; bids
            ; inventory
            ; fair_value_cents
            ; bbo
            ; quoted = _
            ; reseeding = _
            }
        ->
        print_endline
          [%string "\nSTART for %{symbol#Symbol_id}===================="];
        print_endline [%string "Fair value price: %{fair_value_cents#Int}"];
        print_endline [%string "BBO: %{bbo#Bbo}"];
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
  update_all_fair_prices config context;
  if config.print_books then print_books () else ();
  return ()
;;

let on_event config context event =
  let participant = Context.participant context in
  (* Our side of a fill: if we crossed the spread we were the aggressor and
     keep the aggressor's side; otherwise we were resting and take the
     opposite side. (The client-order-id no longer matters — a fill re-quotes
     the whole book — so we only need the side.) *)
  let side_of_fill (fill : Fill.t) =
    if Participant.equal fill.aggressor_participant participant
    then fill.aggressor_side
    else Side.flip fill.aggressor_side
  in
  (* On a fill we only move inventory here. We deliberately do NOT drop the
     filled order id from the books: on a *partial* fill the un-filled
     remainder is still resting on the exchange, so forgetting it here would
     orphan it (never cancelled, never re-quoted). Instead
     [cancel_all_orders] below sweeps *both entire books* and re-seeds, so
     the just-filled order is cancelled there — a partial remainder gets
     pulled, and a fully-filled order simply yields a [Cancel_reject], which
     we already ignore.

     Inventory accumulates signed [fill.size] (cents-per-*share* skew), not a
     +/-1 order count. *)
  let update_books side symbol size : unit =
    let { asks = _
        ; bids = _
        ; inventory
        ; fair_value_cents = _
        ; bbo = _
        ; quoted = _
        ; reseeding = _
        }
      =
      get_symbol_state config context symbol
    in
    set_symbol_inventory
      config
      context
      symbol
      (!inventory + match (side : Side.t) with Buy -> size | Sell -> -size)
  in
  (* TODO keep track of Cancel_reject. would mess up our books *)
  (* This is where we actually match and handle all events *)
  let%bind () =
    match (event : Exchange_event.t) with
    | Order_accept _ ->
      (* Resting orders are tracked at submit time in [seed_book], so the
         acceptance confirmation needs no further bookkeeping. *)
      return ()
    | Best_bid_offer_update { symbol; bbo } ->
      (* Only track BBOs for symbols we actually quote. Market data is
         broadcast for every subscribed symbol, but [get_symbol_state] would
         [find_or_add] an unknown one and price it via the oracle — which
         raises for a symbol outside our config. So look up the existing
         state and ignore data for anything we don't trade. *)
      (match Hashtbl.find config.state symbol with
       | None -> return ()
       | Some curr_symbol_state ->
         set_symbol_state config symbol { curr_symbol_state with bbo };
         (* Re-quote only if the market moved enough to shift where we'd
            quote. We compare the target [(skewed_fair, half_spread)] against
            where our ladder is *resting* (not just "did the BBO change"),
            and require it to have drifted past [requote_threshold_cents] of
            hysteresis. Both guards matter: comparing against the resting
            quote keeps a reseed (which itself moves the BBO) from triggering
            another reseed, and the hysteresis band swallows the sub-tick
            flicker that would otherwise have the maker re-seeding thousands
            of times a second. *)
         let target =
           ( skewed_fair_value
               config
               curr_symbol_state.fair_value_cents
               curr_symbol_state.inventory
           , half_spread_cents bbo )
         in
         (match curr_symbol_state.quoted with
          | Some current
            when not
                   (requote_warranted
                      ~threshold:config.requote_threshold_cents
                      ~current
                      ~target) ->
            return ()
          | None | Some _ -> reseed config context symbol))
    | Order_cancel _ -> return ()
    | Fill fill ->
      let side = side_of_fill fill in
      update_books side fill.symbol (Size.to_int fill.size);
      reseed config context fill.symbol
    | Order_reject { request; reason = _; participant = _ } ->
      (* A rejected order never rests, so drop it from the book we
         optimistically added it to at submit time. *)
      let { asks
          ; bids
          ; inventory = _
          ; fair_value_cents = _
          ; bbo = _
          ; quoted = _
          ; reseeding = _
          }
        =
        get_symbol_state config context request.symbol
      in
      (match request.side with
       | Buy -> Hash_set.remove bids request.client_order_id
       | Sell -> Hash_set.remove asks request.client_order_id);
      return ()
    | Trade_report _ | Cancel_reject _ -> return ()
  in
  return ()
;;

module For_testing = struct
  let half_spread_cents = half_spread_cents
  let min_half_spread_cents = min_half_spread_cents
  let requote_warranted = requote_warranted
end
