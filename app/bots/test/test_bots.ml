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
         ; participant = alice
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
(* End-to-end walk-through of one seed -> BBO -> fill -> re-quote cycle,
   showing the [on_tick] book print at two points. [on_start] seeds at the
   default 50c half-spread (ids 1-6); [bbo_event] then narrows the target to
   the BBO-derived 10c half-spread, which differs from what's quoted, so it
   cancels 1-6 and re-quotes (ids 7-12) -- shown in the first book snapshot.
   The 50-lot buy fill moves inventory to +50, which again changes the target
   (skewed down), so it cancels 7-12 and re-quotes once more (ids 13-18) --
   the second snapshot. [submit_list] shows all 18 orders sent across the
   three seedings; the cancel line shows both rounds of pulled ids (1-6, then
   7-12). *)
let%expect_test "Basic test of Market Maker" =
  let bot, submit_list, cancel_list =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  let%bind () = Bot_runtime.For_testing.manual_tick bot in
  let%bind () = Bot_runtime.feed_event bot fill_event in
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


    BIDS: 11, 7, 9,
    ASKS: 12, 10, 8,
    END ====================

    START for AAPL====================
    Fair value price: 15000
    BBO: $149.90 x100 / $150.10 x200
    Inventory: 50


    BIDS: 17, 13, 15,
    ASKS: 16, 18, 14,
    END ====================
    BUY AAPL 100@$149.50 DAY
    SELL AAPL 100@$150.50 DAY
    BUY AAPL 100@$149.49 DAY
    SELL AAPL 100@$150.51 DAY
    BUY AAPL 100@$149.48 DAY
    SELL AAPL 100@$150.52 DAY
    BUY AAPL 100@$149.90 DAY
    SELL AAPL 100@$150.10 DAY
    BUY AAPL 100@$149.89 DAY
    SELL AAPL 100@$150.11 DAY
    BUY AAPL 100@$149.88 DAY
    SELL AAPL 100@$150.12 DAY
    BUY AAPL 100@$148.90 DAY
    SELL AAPL 100@$149.10 DAY
    BUY AAPL 100@$148.89 DAY
    SELL AAPL 100@$149.11 DAY
    BUY AAPL 100@$148.88 DAY
    SELL AAPL 100@$149.12 DAY
    ..................................................
     1 3 5 6 4 2 9 7 11 8 10 12
    |}];
  return ()
;;

(* [on_start] with no BBO yet seeds a symmetric ladder around the fundamental
   ($150.00). With no BBO, [half_spread_cents] defaults to 50c, and each
   level widens the offset by one more cent (50, 51, 52). Inventory is 0, so
   there is no skew: bids and asks are mirror images around $150.00. *)
let%expect_test "on_start seeds a symmetric default-spread ladder" =
  let bot, submitted, _cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 100@$149.50 DAY
    SELL AAPL 100@$150.50 DAY
    BUY AAPL 100@$149.49 DAY
    SELL AAPL 100@$150.51 DAY
    BUY AAPL 100@$149.48 DAY
    SELL AAPL 100@$150.52 DAY
    |}];
  return ()
;;

(* After a *buy* fill the bot is long, so the skewed fair value drops by
   [inventory * inventory_skew_cents_per_share] = 50 * 2 = 100c,
   moving *both* the bid and the ask down. This also confirms the ladder
   re-quotes at the BBO-derived half-spread (10c, from the $0.20 spread)
   rather than the 50c default. [submitted] is reset after seeding so only
   the re-quote shows. *)
let%expect_test "buy fill skews both quotes down at the BBO half-spread" =
  let bot, submitted, _cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  submitted := [];
  let%bind () = Bot_runtime.feed_event bot fill_event in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 100@$148.90 DAY
    SELL AAPL 100@$149.10 DAY
    BUY AAPL 100@$148.89 DAY
    SELL AAPL 100@$149.11 DAY
    BUY AAPL 100@$148.88 DAY
    SELL AAPL 100@$149.12 DAY
    |}];
  return ()
;;

(* On a fill the bot cancels *every* resting order on *both* books before
   re-quoting — including the just-(partially-)filled order, whose un-filled
   remainder would otherwise be orphaned on the exchange. [on_start] seeds
   bids
   {1 , 3, 5}
   and asks
   {2 , 4, 6}
   at the default 50c half-spread; [bbo_event] narrows the target to the
   BBO-derived 10c half-spread, which differs from what's quoted, so it
   cancels all six and re-quotes (ids 7-12) before the fill even arrives. The
   fill (on what is now bid id 9) then cancels that second round too. *)
let%expect_test "a fill cancels both books, including the filled order" =
  let bot, _submitted, cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  let%bind () = Bot_runtime.feed_event bot fill_event in
  print_cancelled cancelled;
  [%expect {| 1 3 5 6 4 2 9 7 11 8 10 12 |}];
  return ()
;;

(* The resting-side fill: a market maker mostly *rests*, and someone else
   crosses the spread to lift its quote. When the bot is the resting
   participant, [side_of_fill] takes its [else] branch and our side is
   the *flip* of the aggressor's; this is the only path the other fill tests
   never hit. Here [alice] is the BUY aggressor lifting one of our resting
   asks, so the bot's side resolves to Sell and inventory goes to -50. Short
   inventory skews the fair value *up* (the mirror of the buy-fill test), so
   both bid and ask re-quote above $150.00. *)
let%expect_test "resting-side sell fill skews both quotes up" =
  let bot, submitted, _cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  submitted := [];
  let resting_sell_fill : Exchange_event.t =
    Fill
      { fill_id = 2
      ; symbol = aapl
      ; price = Price.of_int_cents 15000
      ; size = Size.of_int 50
      ; aggressor_order_id = Order_id.For_testing.of_int 3
      ; aggressor_client_order_id = Client_order_id.of_int 99
      ; aggressor_participant = alice
      ; aggressor_side = Buy
      ; resting_order_id = Order_id.For_testing.of_int 4
      ; resting_client_order_id = Client_order_id.of_int 2
      ; resting_participant = market_maker
      }
  in
  let%bind () = Bot_runtime.feed_event bot resting_sell_fill in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 100@$150.90 DAY
    SELL AAPL 100@$151.10 DAY
    BUY AAPL 100@$150.89 DAY
    SELL AAPL 100@$151.11 DAY
    BUY AAPL 100@$150.88 DAY
    SELL AAPL 100@$151.12 DAY
    |}];
  return ()
;;

(* [Order_reject] must pull the order back out of the book we optimistically
   tracked it in at submit time. The seed places bids
   {1 , 3, 5}
   ; we reject bid id 1, then take a fill (which cancels the whole book). Id
   1 must be absent from the cancels — the reject removed it — while the
   other five are pulled. *)
let%expect_test "order reject removes the order from the book" =
  let bot, _submitted, cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let reject_bid_1 : Exchange_event.t =
    Order_reject
      { participant = market_maker
      ; request =
          { symbol = aapl
          ; participant = market_maker
          ; side = Buy
          ; price = Price.of_int_cents 14950
          ; size = Size.of_int 100
          ; time_in_force = Day
          ; client_order_id = Client_order_id.of_int 1
          }
      ; reason = "insufficient buying power"
      }
  in
  let%bind () = Bot_runtime.feed_event bot reject_bid_1 in
  let%bind () = Bot_runtime.feed_event bot fill_event in
  print_cancelled cancelled;
  [%expect {| 3 5 6 4 2 |}];
  return ()
;;

(* A one-sided BBO (only a bid, no ask) has no spread, so [half_spread_cents]
   falls back to its 50c default instead of deriving from the book. After a
   buy fill (inventory +50, skewed fair 14900) the re-quote uses that 50c
   half-spread — bids/asks sit 50/51/52c off the skewed fair, not 10c. *)
let%expect_test "one-sided BBO falls back to the default half-spread" =
  let one_sided_bbo : Exchange_event.t =
    Best_bid_offer_update
      { symbol = aapl
      ; bbo =
          { bid =
              Some
                { price = Price.of_int_cents 14990; size = Size.of_int 100 }
          ; ask = None
          }
      }
  in
  let bot, submitted, _cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot one_sided_bbo in
  submitted := [];
  let%bind () = Bot_runtime.feed_event bot fill_event in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 100@$148.50 DAY
    SELL AAPL 100@$149.50 DAY
    BUY AAPL 100@$148.49 DAY
    SELL AAPL 100@$149.51 DAY
    BUY AAPL 100@$148.48 DAY
    SELL AAPL 100@$149.52 DAY
    |}];
  return ()
;;

(* Inventory is cumulative: two 50-lot buy fills leave the bot long 100, so
   the skew deepens to 100 * 2 = 200c. The re-quote after the second fill
   sits a full $2.00 below the $150.00 fair (skewed fair 14800) — twice the
   $1.00 skew a single fill produces. *)
let%expect_test "inventory accumulates across fills, deepening the skew" =
  let bot, submitted, _cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = Bot_runtime.feed_event bot bbo_event in
  let%bind () = Bot_runtime.feed_event bot fill_event in
  submitted := [];
  let%bind () = Bot_runtime.feed_event bot fill_event in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 100@$147.90 DAY
    SELL AAPL 100@$148.10 DAY
    BUY AAPL 100@$147.89 DAY
    SELL AAPL 100@$148.11 DAY
    BUY AAPL 100@$147.88 DAY
    SELL AAPL 100@$148.12 DAY
    |}];
  return ()
;;

(* Market data for a symbol we don't quote must be ignored, not crash the
   bot. The bot is configured for AAPL only; pricing MSFT would ask the
   oracle for a fundamental it doesn't have and raise. Feeding an MSFT BBO
   should be a no-op: nothing submitted, nothing cancelled, no exception. *)
let%expect_test "BBO for an unconfigured symbol is ignored" =
  let bot, submitted, cancelled =
    make_market_maker_bot ~participant_name:"Market Maker"
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  submitted := [];
  let msft_bbo : Exchange_event.t =
    Best_bid_offer_update
      { symbol = Symbol.of_string "MSFT"
      ; bbo =
          { bid =
              Some
                { price = Price.of_int_cents 30000; size = Size.of_int 100 }
          ; ask =
              Some
                { price = Price.of_int_cents 30010; size = Size.of_int 100 }
          }
      }
  in
  let%bind () = Bot_runtime.feed_event bot msft_bbo in
  print_submitted submitted;
  print_cancelled cancelled;
  [%expect {| |}];
  return ()
;;

(* A low enough fundamental combined with the default 50c half-spread would
   drive every buy price below zero; [clamp_to_positive_cents] floors each
   one at one cent instead of letting a negative-priced order reach the
   exchange. The sell side isn't affected here, since adding the spread only
   pushes it further from zero. *)
let%expect_test "a quote that would go negative is floored at one cent" =
  let bot, submitted, _cancelled =
    make_recording_bot
      (module Market_maker_bot)
      (default_config ())
      ~initial_price_cents:3
      ()
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 100@$0.01 DAY
    SELL AAPL 100@$0.53 DAY
    BUY AAPL 100@$0.01 DAY
    SELL AAPL 100@$0.54 DAY
    BUY AAPL 100@$0.01 DAY
    SELL AAPL 100@$0.55 DAY
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
    BUY AAPL 104@$149.95 DAY
    SELL AAPL 113@$149.99 DAY
    SELL AAPL 82@$149.96 IOC
    SELL AAPL 79@$150.02 DAY
    SELL AAPL 95@$149.96 DAY
    BUY AAPL 96@$149.99 DAY
    BUY AAPL 118@$149.99 IOC
    SELL AAPL 86@$150.03 IOC
    BUY AAPL 118@$150.01 DAY
    SELL AAPL 89@$149.98 DAY
    BUY AAPL 84@$150.05 IOC
    BUY AAPL 92@$150.02 IOC
    SELL AAPL 124@$149.99 IOC
    BUY AAPL 92@$149.96 DAY
    BUY AAPL 85@$149.98 DAY
    SELL AAPL 91@$149.99 DAY
    SELL AAPL 98@$150.03 DAY
    BUY AAPL 101@$150.04 DAY
    BUY AAPL 111@$149.96 DAY
    SELL AAPL 78@$150.04 IOC
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
    BUY AAPL 104@$149.85 DAY
    SELL AAPL 113@$149.89 DAY
    SELL AAPL 82@$149.86 IOC
    SELL AAPL 79@$150.12 DAY
    SELL AAPL 95@$149.86 DAY
    BUY AAPL 96@$149.89 DAY
    BUY AAPL 118@$149.89 IOC
    SELL AAPL 86@$150.13 IOC
    BUY AAPL 118@$150.11 DAY
    SELL AAPL 89@$149.88 DAY
    BUY AAPL 84@$150.15 IOC
    BUY AAPL 92@$150.12 IOC
    SELL AAPL 124@$149.89 IOC
    BUY AAPL 92@$149.86 DAY
    BUY AAPL 85@$149.88 DAY
    SELL AAPL 91@$149.89 DAY
    SELL AAPL 98@$150.13 DAY
    BUY AAPL 101@$150.14 DAY
    BUY AAPL 111@$149.86 DAY
    SELL AAPL 78@$150.14 IOC
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

(* ---------------------------------------------------------------- *)
(* Cancel storm tests *)
(* ---------------------------------------------------------------- *)

(* The storm's contract: every tick it fires [cycles_per_tick] submit->cancel
   cycles, each under a *fresh* id, and cancels every id it submits. We
   assert the counts (real pressure, not one order per tick), that all ids
   are distinct (so duplicate-detection never blocks a submit), and that each
   submitted id is cancelled -- all computable without rerunning the bot's
   own logic. *)
let%expect_test "cancel storm fires a burst of fresh-id submit/cancel cycles"
  =
  let cycles_per_tick = 4 in
  let config =
    Cancel_storm.create_config
      ~symbols:[ aapl ]
      ~cycles_per_tick
      ~size:100
      ~pct_marketable:0
      ~price_offset_cents:100
  in
  let bot, submitted, cancelled =
    make_recording_bot (module Cancel_storm) config ()
  in
  let%bind () = Bot_runtime.For_testing.manual_start bot in
  let%bind () = drive_ticks bot ~count:3 in
  let submitted = List.rev !submitted in
  let cancelled = List.rev !cancelled in
  let submitted_ids =
    List.map submitted ~f:(fun (r : Order.Request.t) -> r.client_order_id)
  in
  printf
    "submits=%d cancels=%d\n"
    (List.length submitted)
    (List.length cancelled);
  printf
    "all ids distinct: %b\n"
    (not (List.contains_dup submitted_ids ~compare:Client_order_id.compare));
  printf
    "every submitted id cancelled: %b\n"
    (List.for_all submitted_ids ~f:(fun id ->
       List.mem cancelled id ~equal:Client_order_id.equal));
  [%expect
    {|
    submits=12 cancels=12
    all ids distinct: true
    every submitted id cancelled: true
    |}];
  return ()
;;

(* [pct_marketable] must actually steer pricing. With a flat $150.00
   fundamental, a marketable buy prices above it (a sell below) and a resting
   order the reverse, so we can classify each order and count: [0] should
   yield no marketable orders, [100] all of them. *)
let%expect_test "cancel storm pct_marketable steers whether orders cross" =
  let fundamental_cents = 15000 in
  let is_marketable (r : Order.Request.t) =
    match r.side with
    | Buy -> Price.to_int_cents r.price > fundamental_cents
    | Sell -> Price.to_int_cents r.price < fundamental_cents
  in
  let run ~pct_marketable =
    let config =
      Cancel_storm.create_config
        ~symbols:[ aapl ]
        ~cycles_per_tick:10
        ~size:100
        ~pct_marketable
        ~price_offset_cents:100
    in
    let bot, submitted, _cancelled =
      make_recording_bot (module Cancel_storm) config ()
    in
    let%bind () = Bot_runtime.For_testing.manual_start bot in
    let%bind () = drive_ticks bot ~count:5 in
    return (List.rev !submitted)
  in
  let%bind resting = run ~pct_marketable:0 in
  let%bind crossing = run ~pct_marketable:100 in
  printf
    "pct=0   marketable %d/%d\n"
    (List.count resting ~f:is_marketable)
    (List.length resting);
  printf
    "pct=100 marketable %d/%d\n"
    (List.count crossing ~f:is_marketable)
    (List.length crossing);
  [%expect
    {|
    pct=0   marketable 0/50
    pct=100 marketable 50/50
    |}];
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
         ; participant = alice
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
