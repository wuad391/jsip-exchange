(** Scaffolding for bot tests. *)

open! Core
open! Async
open Jsip_types
open Jsip_fundamental
open Jsip_bot_runtime
open Jsip_market_maker
open! Jsip_bots

let aapl = Symbol.of_string "AAPL"
let alice = Participant.of_string "Alice"
let market_maker = Participant.of_string "Market Maker"

(* .......................... Events .......................... *)
let bbo_event : Exchange_event.t =
  Best_bid_offer_update
    { symbol = aapl
    ; bbo =
        { bid =
            Some { price = Price.of_int_cents 14990; size = Size.of_int 100 }
        ; ask =
            Some { price = Price.of_int_cents 15010; size = Size.of_int 200 }
        }
    }
;;

let fill_event : Exchange_event.t =
  Fill
    { fill_id = 1
    ; symbol = aapl
    ; price = Price.of_int_cents 15000
    ; size = Size.of_int 50
    ; aggressor_order_id = Order_id.For_testing.of_int 1
    ; aggressor_client_order_id = Client_order_id.of_int 1
    ; aggressor_participant = market_maker
    ; aggressor_side = Buy
    ; resting_order_id = Order_id.For_testing.of_int 2
    ; resting_client_order_id = Client_order_id.of_int 1
    ; resting_participant = Participant.of_string "john"
    }
;;

let accepted_event : Exchange_event.t =
  Order_accept
    { order_id = Order_id.For_testing.of_int 1
    ; request =
        { symbol = aapl
        ; participant = alice
        ; side = Buy
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 10
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_int 1
        }
    }
;;

let accepted_event_buy : Exchange_event.t =
  Order_accept
    { order_id = Order_id.For_testing.of_int 1
    ; request =
        { symbol = aapl
        ; participant = market_maker
        ; side = Buy
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 10
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_int 1
        }
    }
;;

let accepted_event_buy2 : Exchange_event.t =
  Order_accept
    { order_id = Order_id.For_testing.of_int 1
    ; request =
        { symbol = aapl
        ; participant = market_maker
        ; side = Buy
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 10
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_int 3
        }
    }
;;

let accepted_event_sell : Exchange_event.t =
  Order_accept
    { order_id = Order_id.For_testing.of_int 1
    ; request =
        { symbol = aapl
        ; participant = market_maker
        ; side = Sell
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 10
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_int 2
        }
    }
;;

(* ............................................................... *)

let oracle_config ~initial_price_cents =
  Symbol.Map.of_alist_exn
    [ ( aapl
      , { Fundamental_oracle.Config.initial_price_cents
        ; volatility_cents_per_sec = 0.0
        ; mean_reversion_strength = 0.0
        ; tick_interval = Time_ns.Span.of_sec 1.0
        } )
    ]
;;

(* .............. Bot creation ............................. *)
let default_config () =
  Market_maker_bot.create_config
    ~testing:true
    ()
    ~size_per_level:100
    ~num_levels:3
    ~inventory_skew_cents_per_share:2
    ~symbols:[ aapl ]
;;

(* Make a market maker that has a fake runtime (does not actually start up
   server or anything, just feeds in fake events) *)
let make_market_maker_bot ~participant_name =
  let submitted = ref [] in
  let cancelled = ref [] in
  let submit request =
    submitted := request :: !submitted;
    return (Ok ())
  in
  let cancel client_order_id =
    cancelled := client_order_id :: !cancelled;
    return (Ok ())
  in
  let bot =
    Bot_runtime.create
      (module Market_maker_bot)
      (default_config ())
      ~participant:(Participant.of_string participant_name)
      ~oracle:
        (Fundamental_oracle.create
           (oracle_config ~initial_price_cents:15000)
           ~seed:42)
      ~rng:(Splittable_random.of_int 7)
      ~submit
      ~cancel
      ~tick_interval:(Time_ns.Span.of_sec 0.5)
  in
  bot, submitted, cancelled
;;

(* Build a runtime around a bot module with a mock submit/cancel that records
   what the bot does. *)
let make_recording_bot
  (type cfg)
  (bot_module : (module Bot_runtime.Bot with type Config.t = cfg))
  (config : cfg)
  ?(initial_price_cents = 15000)
  ()
  =
  let submitted = ref [] in
  let cancelled = ref [] in
  let submit request =
    submitted := request :: !submitted;
    return (Ok ())
  in
  let cancel order_id =
    cancelled := order_id :: !cancelled;
    return (Ok ())
  in
  let oracle =
    Fundamental_oracle.create (oracle_config ~initial_price_cents) ~seed:42
  in
  let bot =
    Bot_runtime.create
      bot_module
      config
      ~participant:alice
      ~oracle
      ~rng:(Splittable_random.of_int 7)
      ~submit
      ~cancel
      ~tick_interval:(Time_ns.Span.of_sec 1.0)
  in
  bot, submitted, cancelled
;;

let print_submitted (submitted : Order.Request.t list ref) =
  let recent = List.rev !submitted in
  List.iter recent ~f:(fun req ->
    printf
      !"%{Side} %{Symbol} %d@%{Price#dollar} %{Time_in_force}\n"
      req.side
      req.symbol
      (Size.to_int req.size)
      req.price
      req.time_in_force)
;;

let print_cancelled (cancelled : Client_order_id.t list ref) =
  let recent = List.rev !cancelled in
  List.iter recent ~f:(fun client_order_id ->
    print_string [%string " %{client_order_id#Client_order_id}"])
;;

(* Smoke test: drive the do-nothing reference bot through one event so the
   runtest target exercises the helpers above. Replace or extend with
   bot-specific tests as concrete strategies are added to [Jsip_bots]. *)
module Inert_bot = struct
  module Config = struct
    type t = unit
  end

  let name = "inert"
  let on_start () _ctx = return ()
  let on_tick () _ctx = return ()
  let on_event () _ctx _event = return ()
end

(* ................................................................. *)
let%expect_test "make_recording_bot wires up a runnable bot" =
  let bot, submitted, _cancelled =
    make_recording_bot (module Inert_bot) () ()
  in
  let%bind () =
    Bot_runtime.feed_event
      bot
      (Order_accept
         { order_id = Order_id.For_testing.of_int 1
         ; request =
             { symbol = aapl
             ; participant = alice
             ; side = Buy
             ; price = Price.of_int_cents 15000
             ; size = Size.of_int 10
             ; time_in_force = Day
             ; client_order_id = Client_order_id.of_int 1
             }
         })
  in
  print_submitted submitted;
  [%expect {| |}];
  return ()
;;

(* ---------------------------------------------------------------- *)
(* Market Maker tests *)
(* ---------------------------------------------------------------- *)
(* default bbo value is good ? *)
let%expect_test "Basic test of Market Maker" =
  let bot, submit_list, cancel_list =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  (* set an initial bbo *)
  let%bind () = Bot_runtime.For_testing.manual_tick bot in
  let%bind () = Bot_runtime.feed_event bot accepted_event_buy in
  (* made a bid *)
  let%bind () = Bot_runtime.For_testing.manual_tick bot in
  let%bind () = Bot_runtime.feed_event bot accepted_event_sell in
  (* made an ask *)
  let%bind () = Bot_runtime.For_testing.manual_tick bot in
  let%bind () = Bot_runtime.For_testing.manual_tick bot in
  (* made anoter bid *)
  let%bind () = Bot_runtime.feed_event bot accepted_event_buy2 in
  let%bind () = Bot_runtime.feed_event bot fill_event in
  (* filled! against john yay *)
  let%bind () = Bot_runtime.For_testing.manual_tick bot in
  print_submitted submit_list;
  print_endline
    [%string ".................................................."];
  print_cancelled cancel_list;
  [%expect
    {|
    START for AAPL====================
    Fair value price: 15000
    BBO: $149.90 x100 / $150.10 x200
    Inventory: 0


    BIDS:
    ASKS:
    END ====================

    START for AAPL====================
    Fair value price: 15000
    BBO: $149.90 x100 / $150.10 x200
    Inventory: 0


    BIDS: 1,
    ASKS:
    END ====================

    START for AAPL====================
    Fair value price: 15000
    BBO: $149.90 x100 / $150.10 x200
    Inventory: 0


    BIDS: 1,
    ASKS: 2,
    END ====================

    START for AAPL====================
    Fair value price: 15000
    BBO: $149.90 x100 / $150.10 x200
    Inventory: 0


    BIDS: 1,
    ASKS: 2,
    END ====================

    START for AAPL====================
    Fair value price: 15000
    BBO: $149.90 x100 / $150.10 x200
    Inventory: 50


    BIDS:
    ASKS: 2,
    END ====================
    BUY AAPL 100@$149.50 DAY
    SELL AAPL 100@$150.50 DAY
    BUY AAPL 100@$149.49 DAY
    SELL AAPL 100@$150.51 DAY
    BUY AAPL 100@$149.48 DAY
    SELL AAPL 100@$150.52 DAY
    BUY AAPL 100@$148.90 DAY
    SELL AAPL 100@$149.10 DAY
    BUY AAPL 100@$148.89 DAY
    SELL AAPL 100@$149.11 DAY
    BUY AAPL 100@$148.88 DAY
    SELL AAPL 100@$149.12 DAY
    ..................................................
     3
    |}];
  return ()
;;

(* ---------------------------------------------------------------- *)
(* Noise trader tests *)
(* ---------------------------------------------------------------- *)

let noise_config ?(tick_chance = 1.0) () =
  Noise_trader.create_config
    ~symbols:[ aapl ]
    ~avg_size:100
    ~tick_chance
    ~aggressiveness_pct:50
    ~ioc_pct:50
;;

(* Run [count] ticks back-to-back off the bot's seeded RNG. *)
let drive_ticks bot ~count =
  Deferred.List.iter ~how:`Sequential (List.init count ~f:Fn.id) ~f:(fun _ ->
    Bot_runtime.For_testing.manual_tick bot)
;;

(* With an empty book, prices hang off the oracle fundamental ($150.00 for
   AAPL): a buy priced above it / a sell below it is marketable, the reverse
   rests. The seed is pinned, so the buy/sell mix, the sizes (100 +/- 25%),
   and the Day/Ioc mix are all reproducible. *)
let%expect_test "noise trader prices off the fundamental when the book is \
                 empty"
  =
  let bot, submitted, _cancelled =
    make_recording_bot (module Noise_trader) (noise_config ()) ()
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = drive_ticks bot ~count:20 in
  print_submitted submitted;
  [%expect
    {|
    SELL AAPL 104@$150.05 DAY
    BUY AAPL 113@$149.99 IOC
    BUY AAPL 82@$149.96 IOC
    BUY AAPL 79@$149.98 IOC
    BUY AAPL 95@$149.96 IOC
    SELL AAPL 96@$150.01 IOC
    SELL AAPL 118@$149.99 IOC
    BUY AAPL 86@$150.03 IOC
    SELL AAPL 118@$150.01 IOC
    BUY AAPL 89@$149.98 IOC
    SELL AAPL 84@$149.95 DAY
    SELL AAPL 92@$150.02 IOC
    BUY AAPL 124@$150.01 IOC
    SELL AAPL 92@$150.04 DAY
    SELL AAPL 85@$150.02 IOC
    BUY AAPL 91@$150.01 IOC
    BUY AAPL 98@$149.97 IOC
    SELL AAPL 101@$149.96 DAY
    SELL AAPL 111@$150.04 IOC
    BUY AAPL 78@$149.96 DAY
    |}];
  return ()
;;

(* After caching a BBO ($149.90 bid / $150.10 ask), marketable orders cross
   it (buys at/above $150.10, sells at/below $149.90) and resting orders sit
   outside the spread. *)
let%expect_test "noise trader prices marketable and resting orders off the \
                 cached BBO"
  =
  let bot, submitted, _cancelled =
    make_recording_bot (module Noise_trader) (noise_config ()) ()
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  let%bind () = drive_ticks bot ~count:20 in
  print_submitted submitted;
  [%expect
    {|
    SELL AAPL 104@$150.15 DAY
    BUY AAPL 113@$149.89 IOC
    BUY AAPL 82@$149.86 IOC
    BUY AAPL 79@$149.88 IOC
    BUY AAPL 95@$149.86 IOC
    SELL AAPL 96@$150.11 IOC
    SELL AAPL 118@$149.89 IOC
    BUY AAPL 86@$150.13 IOC
    SELL AAPL 118@$150.11 IOC
    BUY AAPL 89@$149.88 IOC
    SELL AAPL 84@$149.85 DAY
    SELL AAPL 92@$150.12 IOC
    BUY AAPL 124@$150.11 IOC
    SELL AAPL 92@$150.14 DAY
    SELL AAPL 85@$150.12 IOC
    BUY AAPL 91@$150.11 IOC
    BUY AAPL 98@$149.87 IOC
    SELL AAPL 101@$149.86 DAY
    SELL AAPL 111@$150.14 IOC
    BUY AAPL 78@$149.86 DAY
    |}];
  return ()
;;

(* [tick_chance = 0.0] gates every tick, so a bot on a fast clock can still
   trade sparsely -- here, not at all. *)
let%expect_test "tick_chance of 0.0 keeps the noise trader silent" =
  let bot, submitted, _cancelled =
    make_recording_bot
      (module Noise_trader)
      (noise_config ~tick_chance:0.0 ())
      ()
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = drive_ticks bot ~count:20 in
  print_submitted submitted;
  [%expect {| |}];
  return ()
;;

let%expect_test "make_recording_bot wires up a runnable bot" =
  let bot, submitted, _cancelled =
    make_recording_bot (module Inert_bot) () ()
  in
  let%bind () =
    Bot_runtime.feed_event
      bot
      (Order_accept
         { order_id = Order_id.For_testing.of_int 1
         ; request =
             { symbol = aapl
             ; participant = alice
             ; side = Buy
             ; price = Price.of_int_cents 15000
             ; size = Size.of_int 10
             ; time_in_force = Day
             ; client_order_id = Client_order_id.of_int 1
             }
         })
  in
  print_submitted submitted;
  [%expect {| |}];
  return ()
;;
