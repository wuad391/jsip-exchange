open! Core
open! Async
open Jsip_types
module Fundamental_oracle = Jsip_fundamental.Fundamental_oracle

module Context = struct
  type t =
    { participant : Participant.t
    ; oracle : Fundamental_oracle.t
    ; rng : Splittable_random.t
    ; dispatch_submit : Order.Request.t -> unit Deferred.Or_error.t
    ; dispatch_cancel : Client_order_id.t -> unit Deferred.Or_error.t
    }

  let participant t = t.participant
  let fundamental t symbol = Fundamental_oracle.price t.oracle symbol
  let random t = t.rng
  let submit t request = t.dispatch_submit request
  let cancel t cancel_order_id = t.dispatch_cancel cancel_order_id
end

module type Bot = sig
  module Config : sig
    type t
  end

  val name : string

  (** Called exactly once, before the tick loop starts and before any events
      are delivered. Use this for one-time setup that needs to happen on the
      same scheduler as [on_tick] / [on_event] — e.g., seeding an initial
      ladder of orders. *)
  val on_start : Config.t -> Context.t -> unit Deferred.t

  val on_tick : Config.t -> Context.t -> unit Deferred.t
  val on_event : Config.t -> Context.t -> Exchange_event.t -> unit Deferred.t
end

type packed_bot =
  | Packed :
      { bot : (module Bot with type Config.t = 'cfg)
      ; config : 'cfg
      }
      -> packed_bot

type t =
  { context : Context.t
  ; bot : packed_bot
  ; tick_interval : Time_ns.Span.t
  ; stop : unit Ivar.t
  }

let create
  (type cfg)
  (bot_module : (module Bot with type Config.t = cfg))
  (config : cfg)
  ~participant
  ~oracle
  ~rng
  ~submit
  ~cancel
  ~tick_interval
  =
  let context : Context.t =
    { participant
    ; oracle
    ; rng
    ; dispatch_submit = submit
    ; dispatch_cancel = cancel
    }
  in
  { context
  ; bot = Packed { bot = bot_module; config }
  ; tick_interval
  ; stop = Ivar.create ()
  }
;;

let participant t = t.context.participant

let bot_name t =
  let (Packed { bot = (module B); config = _ }) = t.bot in
  B.name
;;

let stop t = Ivar.fill_if_empty t.stop ()

let feed_event t event =
  let (Packed { bot = (module B); config }) = t.bot in
  B.on_event config t.context event
;;

let start t =
  let (Packed { bot = (module B); config }) = t.bot in
  if Ivar.is_full t.stop
  then return ()
  else (
    let%bind () = B.on_start config t.context in
    (* Race each inter-tick sleep against the stop signal, so [stop] wakes a
       sleeping loop immediately instead of waiting out the interval — then
       re-check before ticking, since the sleep can also win the race after
       [stop] was called. *)
    let rec loop () =
      let%bind () =
        Deferred.any_unit
          [ Clock_ns.after t.tick_interval; Ivar.read t.stop ]
      in
      if Ivar.is_full t.stop
      then return ()
      else (
        let%bind () = B.on_tick config t.context in
        loop ())
    in
    loop ())
;;

module For_testing = struct
  let context_of t = t.context

  let manual_tick t =
    let (Packed { bot = (module B); config }) = t.bot in
    B.on_tick config t.context
  ;;

  let manual_start t =
    let (Packed { bot = (module B); config }) = t.bot in
    B.on_start config t.context
  ;;
end
