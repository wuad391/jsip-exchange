open! Core
open! Async
open Jsip_types
module Bot_runtime = Jsip_bot_runtime.Bot_runtime
module Context = Bot_runtime.Context

module Config = struct
  type t =
    { symbols : Symbol_id.t list
    ; orders_per_tick : int
    ; order_size : int
    ; price_offset_cents : int
    ; level_spacing_cents : int
    ; next_client_order_id : int ref
    }
  [@@deriving sexp_of]
end

let name = "book_filler"

(* Validate the config once at startup so a bad scenario fails loudly rather
   than crashing mid-tick (empty [symbols] divides by zero in the
   round-robin). *)
let on_start (config : Config.t) _context =
  if List.is_empty config.symbols
  then raise_s [%message "Book_filler: symbols must be non-empty"];
  if config.orders_per_tick <= 0
  then
    raise_s
      [%message
        "Book_filler: orders_per_tick must be positive"
          ~orders_per_tick:(config.orders_per_tick : int)];
  if config.order_size <= 0
  then
    raise_s
      [%message
        "Book_filler: order_size must be positive"
          ~order_size:(config.order_size : int)];
  Deferred.unit
;;

(* Mint a fresh client order id and advance the counter. Ids can't repeat,
   and the counter lives in [config] because the [Bot] interface keeps no
   state. *)
let fresh_client_order_id (config : Config.t) =
  let id = !(config.next_client_order_id) in
  incr config.next_client_order_id;
  Client_order_id.of_int id
;;

(* Build the [index]th order of this tick, priced to rest rather than fill.
   Orders alternate side (even buys, odd sells); each sits at least
   [price_offset_cents] from fair (buys below, sells above), and [level]
   marches each pair out by [level_spacing_cents]. Buy prices floor at one
   cent to stay valid. *)
let make_order (config : Config.t) context ~symbol ~index : Order.Request.t =
  let fundamental_cents =
    Context.fundamental context symbol |> Price.to_int_cents
  in
  let level = index / 2 in
  let distance =
    config.price_offset_cents + (level * config.level_spacing_cents)
  in
  let side : Side.t = if index % 2 = 0 then Buy else Sell in
  let price_cents =
    match side with
    | Buy -> Int.max 1 (fundamental_cents - distance)
    | Sell -> fundamental_cents + distance
  in
  { client_order_id = fresh_client_order_id config
  ; symbol
  ; participant = Context.participant context
  ; side
  ; price = Price.of_int_cents price_cents
  ; size = Size.of_int config.order_size
  ; time_in_force = Day
  }
;;

(* Cap on in-flight submits per tick: firing a huge [orders_per_tick] fully
   parallel would stress the bot's own scheduler and write buffer rather than
   the exchange. Bounding it keeps the bot healthy and load steady. *)
let max_concurrent_submits = 64

(* Each tick, fire [orders_per_tick] resting orders, round-robining across
   symbols. [submit] is one-way, so we only log an enqueue failure. *)
let on_tick (config : Config.t) context =
  let symbols = Array.of_list config.symbols in
  let num_symbols = Array.length symbols in
  Deferred.List.iter
    ~how:(`Max_concurrent_jobs max_concurrent_submits)
    (List.init config.orders_per_tick ~f:Fn.id)
    ~f:(fun index ->
      let symbol = symbols.(index % num_symbols) in
      let request = make_order config context ~symbol ~index in
      match%map Context.submit context request with
      | Ok () -> ()
      | Error error ->
        [%log.error
          "book_filler: submit failed"
            (request : Order.Request.t)
            (error : Error.t)])
;;

(* The bot is fire-and-forget: it never reacts to fills, rejects, or market
   data. *)
let on_event _config _context _event = Deferred.unit
