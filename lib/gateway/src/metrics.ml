open! Core
open! Async
open Jsip_types
open Jsip_order_book

(* Cap on latency samples retained per one-second window. A burst of millions
   of orders should not let a single snapshot allocate without bound; we keep
   the first [max_latency_samples] as the percentile input, while the [count]
   we report stays exact. *)
let max_latency_samples = 100_000
let sample_interval = Time_ns.Span.of_sec 1.

type t =
  { dispatcher : Dispatcher.t
  ; matching_engine : Matching_engine.t
  ; request_queue_length : unit -> int
  ; mutable seq : int
  ; submit_samples : float Queue.t
  ; mutable submit_count : int
  ; cancel_samples : float Queue.t
  ; mutable cancel_count : int
  ; orders_per_sec : int Participant.Table.t
  ; mutable busy_max_us : float
  ; subscribers : Exchange_stats.t Pipe.Writer.t Bag.t
  }

let create ~dispatcher ~matching_engine ~request_queue_length =
  { dispatcher
  ; matching_engine
  ; request_queue_length
  ; seq = 0
  ; submit_samples = Queue.create ()
  ; submit_count = 0
  ; cancel_samples = Queue.create ()
  ; cancel_count = 0
  ; orders_per_sec = Participant.Table.create ()
  ; busy_max_us = 0.
  ; subscribers = Bag.create ()
  }
;;

let record_arrival t ~participant = Hashtbl.incr t.orders_per_sec participant

let record_processed t ~kind ~latency ~busy =
  let us = Time_ns.Span.to_us latency in
  (match kind with
   | `Submit ->
     t.submit_count <- t.submit_count + 1;
     if Queue.length t.submit_samples < max_latency_samples
     then Queue.enqueue t.submit_samples us
   | `Cancel ->
     t.cancel_count <- t.cancel_count + 1;
     if Queue.length t.cancel_samples < max_latency_samples
     then Queue.enqueue t.cancel_samples us);
  t.busy_max_us <- Float.max t.busy_max_us (Time_ns.Span.to_us busy)
;;

let subscribe t =
  let reader, writer = Pipe.create () in
  let elt = Bag.add t.subscribers writer in
  don't_wait_for
    (let%map () = Pipe.closed writer in
     Bag.remove t.subscribers elt);
  reader
;;

(* Union the participants seen submitting this window with those holding
   resting orders now, so the table shows both a bot that only sends and a
   bot whose orders are piling up. *)
let per_participant t =
  let resting = Matching_engine.resting_order_counts t.matching_engine in
  let participants =
    Set.union
      (Participant.Set.of_list (Hashtbl.keys t.orders_per_sec))
      (Map.key_set resting)
  in
  Set.to_list participants
  |> List.map ~f:(fun participant ->
    { Exchange_stats.Participant_stats.participant
    ; orders_per_sec =
        Hashtbl.find t.orders_per_sec participant |> Option.value ~default:0
    ; resting_orders =
        Map.find resting participant |> Option.value ~default:0
    })
;;

let snapshot t : Exchange_stats.t =
  t.seq <- t.seq + 1;
  { seq = t.seq
  ; gc = Exchange_stats.Gc_snapshot.of_stat (Core.Gc.stat ())
  ; submit_latency =
      Exchange_stats.Latency_summary.of_samples
        (Queue.to_array t.submit_samples)
        ~count:t.submit_count
  ; cancel_latency =
      Exchange_stats.Latency_summary.of_samples
        (Queue.to_array t.cancel_samples)
        ~count:t.cancel_count
  ; audit_pipe =
      Exchange_stats.Pipe_group.of_lengths
        (Dispatcher.audit_queue_lengths t.dispatcher)
  ; market_data_pipe =
      Exchange_stats.Pipe_group.of_lengths
        (Dispatcher.market_data_queue_lengths t.dispatcher)
  ; session_pipe =
      Exchange_stats.Pipe_group.of_lengths
        (Dispatcher.session_queue_lengths t.dispatcher)
  ; request_queue_depth = t.request_queue_length ()
  ; matching_loop_busy_us = t.busy_max_us
  ; per_participant = per_participant t
  }
;;

let reset_window t =
  Queue.clear t.submit_samples;
  t.submit_count <- 0;
  Queue.clear t.cancel_samples;
  t.cancel_count <- 0;
  Hashtbl.clear t.orders_per_sec;
  t.busy_max_us <- 0.
;;

let broadcast t (stats : Exchange_stats.t) =
  Bag.iter t.subscribers ~f:(fun writer ->
    Pipe.write_without_pushback_if_open writer stats)
;;

let start t =
  Clock_ns.every sample_interval (fun () ->
    let stats = snapshot t in
    broadcast t stats;
    reset_window t)
;;

module For_testing = struct
  let snapshot = snapshot
  let reset = reset_window
end
