(** Server-side collector for {!Exchange_stats.t}.

    Owns the per-second measurement window: the exchange server feeds it
    order arrivals and per-request processing results, and once a second it
    samples the GC and pipe occupancy, folds everything into an
    {!Exchange_stats.t}, broadcasts it to every subscriber, and resets the
    window.

    Subscribers arrive via {!Rpc_protocol.exchange_stats_rpc}, implemented in
    {!Exchange_server} on top of {!subscribe}. Keeping this separate from
    {!Dispatcher} keeps infrastructure metrics out of the event-routing path. *)

open! Core
open! Async
open Jsip_types
open Jsip_exchange_stats

type t

(** [request_queue_length] is read at snapshot time to report the matching
    engine's inbound backlog; [matching_engine] supplies live resting-order
    counts; [dispatcher] supplies subscriber-pipe occupancy. *)
val create
  :  dispatcher:Dispatcher.t
  -> matching_engine:Jsip_order_book.Matching_engine.t
  -> request_queue_length:(unit -> int)
  -> t

(** Record that an order request (submit or cancel) arrived from
    [participant], for the per-participant order-rate pane. *)
val record_arrival : t -> participant:Participant.t -> unit

(** Record that the matching engine finished one request. [latency] is the
    enqueue-to-matched time (goes into the submit/cancel percentiles per
    [kind]); [busy] is the wall-clock the whole loop iteration took,
    including dispatch (feeds [matching_loop_busy_us]). *)
val record_processed
  :  t
  -> kind:[ `Submit | `Cancel ]
  -> latency:Time_ns.Span.t
  -> busy:Time_ns.Span.t
  -> unit

(** A fresh reader that receives one {!Exchange_stats.t} per second until the
    reader is closed. *)
val subscribe : t -> Exchange_stats.t Pipe.Reader.t

(** Begin the once-per-second snapshot loop. Call once, after [create]. *)
val start : t -> unit

(** Hooks to drive the snapshot machinery synchronously in tests, without the
    1 Hz timer. *)
module For_testing : sig
  (** Build an {!Exchange_stats.t} from the current window (as {!start}'s
      loop would) without clearing it. Increments the sequence number. *)
  val snapshot : t -> Exchange_stats.t

  (** Clear the current window, as {!start} does after each snapshot. *)
  val reset : t -> unit
end
