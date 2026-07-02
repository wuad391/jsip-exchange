open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime
module Context = Bot_runtime.Context

(* This market maker bot implements dynamicism by reacting to events and not
   through any tick functions. Every tick, if print_books is true, then the
   internal books are printed. Internal books are tracked through a table
   keyed by symbol with symbol_state values. Unified across alll symbols is
   the inventory skew per share, globally unique client order id, # of shares
   per level, and the number of lvls. *)

type symbol_state =
  { mutable asks : Client_order_id.t Hash_set.t
  ; mutable bids : Client_order_id.t Hash_set.t
  ; inventory : Int.t Ref.t
  ; mutable fair_value_cents : int
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

(* ....................................................... *)

(* This function dummy sets fair value for ecah symbol at 0 bc on_start will
   be called to make it nice and pretty yay *)
let create_config
  ?(testing = false)
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
  ; state = Hashtbl.of_alist_exn (module Symbol) symbol_state_list
  ; client_order_id_ref = ref 0
  ; print_books = testing
  }
;;

let seed_book
  (config : Config.t)
  (context : Bot_runtime.Context.t)
  (symbols : Symbol.t List.t)
  =
  (* XCR claude for robyn: this binds the list of submit deferreds to [_] and
     then returns [return ()], so [seed_book] does NOT await the submits —
     [on_start] completes before any order is actually sent. Use
     [Deferred.List.iter ~how:`Parallel symbols ~f:...] (or
     [Deferred.all_unit (List.map ...)]) so the returned deferred reflects
     the real work.

     claude: verified — now
     [let%bind () = Deferred.List.iter ~how:(`Max_concurrent_jobs 64) symbols ...]
     awaits every submit before returning. Minor: the inner "TODO: Think
     about making this a parallel map" comment is now stale (you did it) —
     drop it. *)
  let%bind () =
    (* TODO: Think about making this a parallel map *)
    Deferred.List.iter
      ~how:(`Max_concurrent_jobs 64)
      symbols
      ~f:(fun symbol ->
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
                 ; price =
                     Price.of_int_cents (skewed_fair_value_cents - offset)
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
                 ; price =
                     Price.of_int_cents (skewed_fair_value_cents + offset)
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
  update_all_fair_prices config context;
  seed_book config context (Hashtbl.keys config.state)
;;

(* I dont think this will actually do anything for MM bc we react to events *)
let on_tick (config : Config.t) context =
  let print_books () =
    Hashtbl.iteri
      config.state
      ~f:
        (fun
          ~key:symbol
          ~data:{ asks; bids; inventory; fair_value_cents; bbo }
        ->
        print_endline
          [%string "\nSTART for %{symbol#Symbol}===================="];
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
  let get_side_client_order_id (fill : Fill.t) =
    if Participant.equal fill.aggressor_participant participant
    then fill.aggressor_side, fill.aggressor_client_order_id
    else Side.flip fill.aggressor_side, fill.resting_client_order_id
  in
  (* update_books is used when something gets filled *)
  (* XCR claude for robyn: inventory moves by +/-1 per fill regardless of
     [fill.size], but your skew is [inventory_skew_cents_per_share] — cents
     per *share*. Accumulate signed size instead (thread [fill] in):
     [!inventory + (match side with Buy -> Size.to_int fill.size | Sell -> - Size.to_int fill.size)].
     As-is the skew multiplies an order-count, so the quote adjustment is
     wrong. Same bug exists in market_maker.ml.

     claude: verified — [update_books] now takes [size] and accumulates
     [!inventory + (match side with Buy -> size | Sell -> -size)], called
     with [Size.to_int fill.size]. The twin in market_maker.ml (line 100)
     still has +/-1, but that file is slated for deletion per its CR-someday. *)
  let update_books side symbol client_order_id size : unit =
    let { asks; bids; inventory; fair_value_cents = _; bbo = _ } =
      get_symbol_state config context symbol
    in
    Hash_set.remove bids client_order_id;
    Hash_set.remove asks client_order_id;
    set_symbol_inventory
      config
      context
      symbol
      (!inventory + match (side : Side.t) with Buy -> size | Sell -> -size)
  in
  (* TODO keep track of Cancel_reject. would mess up our books *)
  let cancel_all_orders side symbol =
    let { asks; bids; inventory = _; fair_value_cents = _; bbo = _ } =
      get_symbol_state config context symbol
    in
    (* TODO: This is a very janky way of iterating through a hash set but the
       types don't work well in Hash_set.iter. Deferred.Hash_set.iter *)
    (* XCR claude for robyn: two things here. (1) Remove the
       [print_endline "HERE"] debug line — it fires on every cancel and got
       promoted into test_bots' expect output. (2) This [Hash_set.fold]
       discards its accumulator ([fun _ id -> ...]), so the per-id deferreds
       aren't chained; the [let%bind] only awaits the *last* cancel. Use
       [Deferred.List.iter (Hash_set.to_list client_order_id_set) ~f:(fun id -> Context.cancel context id >>| (ignore : _ -> unit))].

       claude: verified — [HERE] print is gone and the fold is replaced with
       [Deferred.List.iter ~how:`Sequential (Hash_set.to_list ...) ~f:(fun id -> Context.cancel context id >>| (ignore : _ -> unit))],
       which awaits every cancel. *)
    let%bind () =
      Deferred.List.iter
        ~how:`Sequential
        (Hash_set.to_list bids)
        ~f:(fun id -> Context.cancel context id >>| (ignore : _ -> unit))
    in
    let%bind () =
      Deferred.List.iter
        ~how:`Sequential
        (Hash_set.to_list asks)
        ~f:(fun id -> Context.cancel context id >>| (ignore : _ -> unit))
    in
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
  in
  (* This is where we actually match and handle all events *)
  let%bind () =
    match (event : Exchange_event.t) with
    | Order_accept { order_id = _; request } ->
      let { asks; bids; inventory = _; fair_value_cents = _; bbo = _ } =
        get_symbol_state config context request.symbol
      in
      (match request.side with
       | Buy -> return (Hash_set.add bids request.client_order_id)
       | Sell -> return (Hash_set.add asks request.client_order_id))
    | Best_bid_offer_update { symbol; bbo } ->
      let curr_symbol_state = get_symbol_state config context symbol in
      set_symbol_state config symbol { curr_symbol_state with bbo };
      return ()
      (* TODO: maybe adjust some of the config stuff based on BBO *)
    | Order_cancel _ ->
      return ()
      (* CR claude for robyn: on a fill you [cancel_all_orders side] (one
         side) but [seed_book] re-places a *full two-sided* ladder — so the
         un-cancelled side keeps its old resting orders AND gets a fresh set
         stacked on top. Over repeated fills the opposite side accumulates
         duplicate orders. Cancel both sides before re-seeding, or re-seed
         only the cancelled side.

         claude: still open — the [Fill] arm below is unchanged: it calls
         [cancel_all_orders side fill.symbol] (single side) then
         [seed_book config context [fill.symbol]] (re-seeds BOTH sides). A
         Buy fill cancels+reseeds the bids but leaves the old asks resting
         while seed_book stacks a fresh ask ladder on top; repeated same-side
         fills double the opposite book. Since inventory (and thus the skewed
         fair value) moves on every fill, both sides are stale anyway —
         simplest fix is to cancel both sides before re-seeding (call
         [cancel_all_orders] for Buy and Sell, then [seed_book]). *)

      (* REVIEW *)
    | Fill fill ->
      let side, client_order_id = get_side_client_order_id fill in
      update_books side fill.symbol client_order_id (Size.to_int fill.size);
      let%bind () = cancel_all_orders side fill.symbol in
      seed_book config context [ fill.symbol ]
    | Order_reject _ | Trade_report _ | Cancel_reject _ -> return ()
  in
  return ()
;;
