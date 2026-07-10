open! Core
open! Async
open Jsip_types
open Jsip_gateway
module Bot_runtime = Jsip_bot_runtime.Bot_runtime

type t =
  { participant : Participant.t
  ; kind : string
  ; symbols : Symbol_id.t list
  ; connection : Rpc.Connection.t
  ; runtime : Bot_runtime.t
  ; tick_loop : unit Deferred.t
  ; feed : Exchange_event.t Pipe.Reader.t
  ; feed_pump : unit Deferred.t
  ; started_at : Time_ns.t
  }

(* Shared teardown prefix: silence the strategy — no more ticks, no more
   events — so it cannot react to what happens to its orders next (a market
   maker would otherwise re-quote off the BBO moves its own cancel-all
   causes). *)
let quiesce t =
  Bot_runtime.stop t.runtime;
  let%bind () = t.tick_loop in
  Pipe.close_read t.feed;
  t.feed_pump
;;

let disconnect t =
  let%bind () = Rpc.Connection.close t.connection in
  Rpc.Connection.close_finished t.connection
;;

let kill t =
  let%bind () = quiesce t in
  (* Flatten while the connection is still up; whatever the outcome,
     disconnect — a broken bot must not linger half-dead. *)
  let%bind cancelled =
    Rpc.Rpc.dispatch Rpc_protocol.cancel_all_rpc t.connection ()
    >>| Or_error.join
  in
  let%map () = disconnect t in
  cancelled
;;

let crash t =
  let%bind () = quiesce t in
  disconnect t
;;
