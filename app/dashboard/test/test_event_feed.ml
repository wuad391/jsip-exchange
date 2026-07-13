open! Core
open Jsip_types
open Jsip_dashboard
open Jsip_symbol_directory

(* [Event_feed.format] is what the browser feed pane draws, so these pin the
   text and color of every event kind — and, via the [symbol] field,
   [symbol_of_event] (note [cancel_reject] carries no symbol). One event per
   variant so a wording or coloring change shows up here as a readable diff. *)

let sym = Symbol_id.of_int 0
let alice = Participant.of_string "alice"
let bob = Participant.of_string "bob"

let request ~side ~cents ~size : Order.Request.t =
  { Order.Request.symbol = sym
  ; participant = alice
  ; side
  ; price = Price.of_int_cents cents
  ; size = Size.of_int size
  ; time_in_force = Time_in_force.Day
  ; client_order_id = Client_order_id.of_int 1
  }
;;

let events : (string * Exchange_event.t) list =
  [ ( "order_accept"
    , Order_accept
        { order_id = Order_id.For_testing.of_int 7
        ; participant = alice
        ; request = request ~side:Side.Buy ~cents:15000 ~size:100
        } )
  ; ( "fill"
    , Fill
        { fill_id = 1
        ; symbol = sym
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 50
        ; aggressor_order_id = Order_id.For_testing.of_int 7
        ; aggressor_client_order_id = Client_order_id.of_int 1
        ; aggressor_participant = alice
        ; aggressor_side = Side.Buy
        ; resting_order_id = Order_id.For_testing.of_int 3
        ; resting_client_order_id = Client_order_id.of_int 2
        ; resting_participant = bob
        } )
  ; ( "order_cancel"
    , Order_cancel
        { order_id = Order_id.For_testing.of_int 7
        ; client_order_id = Client_order_id.of_int 1
        ; participant = alice
        ; symbol = sym
        ; remaining_size = Size.of_int 25
        ; reason = Cancel_reason.Participant_requested
        } )
  ; ( "order_reject"
    , Order_reject
        { participant = alice
        ; request = request ~side:Side.Sell ~cents:14000 ~size:10
        ; reason = "unknown symbol"
        } )
  ; ( "cancel_reject"
    , Cancel_reject
        { participant = alice
        ; client_order_id = Client_order_id.of_int 9
        ; reason = "no such order"
        } )
  ; ( "bbo"
    , Best_bid_offer_update
        { symbol = sym
        ; bbo =
            { bid =
                Some
                  { Level.price = Price.of_int_cents 14990
                  ; size = Size.of_int 5
                  }
            ; ask =
                Some
                  { Level.price = Price.of_int_cents 15010
                  ; size = Size.of_int 7
                  }
            }
        } )
  ; ( "trade_report"
    , Trade_report
        { symbol = sym
        ; price = Price.of_int_cents 15005
        ; size = Size.of_int 3
        } )
  ]
;;

let%expect_test "format renders each event kind" =
  List.iter events ~f:(fun (name, event) ->
    print_endline name;
    print_s [%sexp (Event_feed.format event : Event_feed.feed_row)]);
  [%expect
    {|
    order_accept
    ((symbol (0)) (text "ACCEPTED id=7 0 BUY 100@$150.00 DAY") (color #3fb950))
    fill
    ((symbol (0))
     (text
      "FILL fill_id=1 0 $150.00 x50 aggressor=7(alice w/ client order ID = 1) BUY resting=3(bob w/ client order ID = 2)")
     (color #39c5cf))
    order_cancel
    ((symbol (0))
     (text "CANCELLED id=7 0 remaining=25 reason=PARTICIPANT_REQUESTED")
     (color #e3b341))
    order_reject
    ((symbol (0)) (text "REJECTED 0 SELL 10@$140.00 reason=unknown symbol")
     (color #f85149))
    cancel_reject
    ((symbol ()) (text "REJECTED CANCEL because no such order") (color #f0883e))
    bbo
    ((symbol (0)) (text "BBO 0 bid=$149.90 x5 ask=$150.10 x7") (color #58a6ff))
    trade_report
    ((symbol (0)) (text "TRADE 0 $150.05 x3") (color #bc8cff))
    |}]
;;

let%expect_test "format resolves the symbol id to its name via the directory"
  =
  let directory = Symbol_directory.of_names [ Symbol.of_string "AAPL" ] in
  let find name = List.Assoc.find_exn events name ~equal:String.equal in
  (* The [symbol] field still carries the raw id (for tab filtering); only
     the display [text] gains the name. The hand-formatted fill line and a
     [%string] line both pick it up. *)
  print_s
    [%sexp
      (Event_feed.format ~directory (find "fill") : Event_feed.feed_row)];
  print_s
    [%sexp (Event_feed.format ~directory (find "bbo") : Event_feed.feed_row)];
  [%expect
    {|
    ((symbol (0))
     (text
      "FILL fill_id=1 AAPL $150.00 x50 aggressor=7(alice w/ client order ID = 1) BUY resting=3(bob w/ client order ID = 2)")
     (color #39c5cf))
    ((symbol (0)) (text "BBO AAPL bid=$149.90 x5 ask=$150.10 x7")
     (color #58a6ff))
    |}]
;;
