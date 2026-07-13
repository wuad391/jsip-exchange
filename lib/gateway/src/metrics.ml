open! Core
open! Async
open Jsip_types
open Jsip_order_book
open Jsip_exchange_stats

(* Cap on latency samples retained per sample window. A burst of millions of
   orders should not let a single snapshot allocate without bound; we keep
   the first [max_latency_samples] as the percentile input, while the [count]
   and [max] we report are tracked outside the cap and stay exact. *)
let max_latency_samples = 100_000
let sample_interval = Time_ns.Span.of_sec 0.5

(* [live_words] is the one GC figure that costs a full major-heap walk
   ([Gc.stat]); every other field is free from [Gc.quick_stat]. We refresh it
   on this slower cadence, off the [sample_interval] snapshot path, so the
   walk's cost — which grows with the live heap — never widens the snapshot
   cadence, and thus the dashboard's refresh latency, under load. At 1/20 the
   snapshot rate the walk is a rare isolated cost rather than a per-sample
   tax. *)
let live_words_sample_interval = Time_ns.Span.of_sec 10.

type t =
  { dispatcher : Dispatcher.t
  ; matching_engine : Matching_engine.t
  ; num_symbols : int
  ; request_queue_length : unit -> int
  ; mutable seq : int
  ; submit_samples : float Queue.t
  ; mutable submit_count : int
  ; mutable submit_max_us : float
  ; cancel_samples : float Queue.t
  ; mutable cancel_count : int
  ; mutable cancel_max_us : float
  ; orders_per_sec : int Participant.Table.t
  ; mutable busy_max_us : float
  ; (* Latest [live_words] from [Gc.stat], refreshed on
       [live_words_sample_interval] so the per-sample snapshot can read the
       O(1) [Gc.quick_stat] and never walk the heap itself. *)
    mutable last_live_words : int
  ; subscribers : Exchange_stats.t Pipe.Writer.t Bag.t
  }

let create ~dispatcher ~matching_engine ~num_symbols ~request_queue_length =
  { dispatcher
  ; matching_engine
  ; num_symbols
  ; request_queue_length
  ; seq = 0
  ; submit_samples = Queue.create ()
  ; submit_count = 0
  ; submit_max_us = 0.
  ; cancel_samples = Queue.create ()
  ; cancel_count = 0
  ; cancel_max_us = 0.
  ; orders_per_sec = Participant.Table.create ()
  ; busy_max_us = 0.
  ; last_live_words = 0
  ; subscribers = Bag.create ()
  }
;;

let record_arrival t ~participant = Hashtbl.incr t.orders_per_sec participant

let record_processed t ~kind ~latency ~busy =
  let us = Time_ns.Span.to_us latency in
  (match kind with
   | `Submit ->
     t.submit_count <- t.submit_count + 1;
     t.submit_max_us <- Float.max t.submit_max_us us;
     (* Percentiles come from at most [max_latency_samples] samples (kept
        first, to bound memory); [count] and [max] above are unbounded, so
        they stay exact even when the queue backs up and latency climbs. *)
     if Queue.length t.submit_samples < max_latency_samples
     then Queue.enqueue t.submit_samples us
   | `Cancel ->
     t.cancel_count <- t.cancel_count + 1;
     t.cancel_max_us <- Float.max t.cancel_max_us us;
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
    ; (* Raw window count; the dashboard divides by [sample_period_sec]. *)
      order_count =
        Hashtbl.find t.orders_per_sec participant |> Option.value ~default:0
    ; resting_orders =
        Map.find resting participant |> Option.value ~default:0
    })
;;

(* Runs every [sample_interval], so its wall time is what the dashboard's
   refresh latency is made of — it must stay cheap. GC figures come from
   [Gc.quick_stat] (O(1)); [live_words], the one field that needs a full-heap
   walk, is folded in from [last_live_words], refreshed off-path by [start]
   on [live_words_sample_interval]. This is the "revisit on a large heap" the
   old comment here flagged: the walk was the term that grew with the heap
   and stretched the snapshot cadence under load. *)
let snapshot t : Exchange_stats.t =
  t.seq <- t.seq + 1;
  let gc : Exchange_stats.Gc_snapshot.t =
    { (Exchange_stats.Gc_snapshot.of_stat (Core.Gc.quick_stat ())) with
      live_words = t.last_live_words
    }
  in
  { seq = t.seq
  ; sample_period_sec = Time_ns.Span.to_sec sample_interval
  ; gc
  ; submit_latency =
      Exchange_stats.Latency_summary.of_samples
        (Queue.to_array t.submit_samples)
        ~count:t.submit_count
        ~max_us:t.submit_max_us
  ; cancel_latency =
      Exchange_stats.Latency_summary.of_samples
        (Queue.to_array t.cancel_samples)
        ~count:t.cancel_count
        ~max_us:t.cancel_max_us
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
  ; top_of_book =
      List.init t.num_symbols ~f:(fun i ->
        let symbol = Symbol_id.of_int i in
        let bbo =
          Matching_engine.book t.matching_engine symbol
          |> Option.value_map ~default:Bbo.empty ~f:Order_book.best_bid_offer
        in
        { Exchange_stats.Top_of_book.symbol; bbo })
  }
;;

let reset_window t =
  Queue.clear t.submit_samples;
  t.submit_count <- 0;
  t.submit_max_us <- 0.;
  Queue.clear t.cancel_samples;
  t.cancel_count <- 0;
  t.cancel_max_us <- 0.;
  Hashtbl.clear t.orders_per_sec;
  t.busy_max_us <- 0.
;;

(* Bound each subscriber's buffer: if a stats client stalls, drop new
   snapshots for it rather than buffering forever — the very unbounded-buffer
   pathology this dashboard exists to expose. A stalled client just misses
   snapshots until it drains; the next one is a second away. *)
let max_subscriber_backlog = 5

let broadcast t (stats : Exchange_stats.t) =
  Bag.iter t.subscribers ~f:(fun writer ->
    if Pipe.length writer < max_subscriber_backlog
    then Pipe.write_without_pushback_if_open writer stats)
;;

let start t =
  (* Refresh the expensive [live_words] figure on its own slow cadence (and
     prime it once, so the first snapshots aren't zero). Only this timer pays
     for [Gc.stat]'s heap walk; the per-[sample_interval] snapshot reads
     [Gc.quick_stat]. Both fire on a fixed grid ([run_at_intervals]) rather
     than [interval]-after-completion ([every]), so a slow snapshot cannot
     stretch the cadence and stale the dashboard. *)
  let refresh_live_words () =
    let stat : Core.Gc.Stat.t = Core.Gc.stat () in
    t.last_live_words <- stat.live_words
  in
  refresh_live_words ();
  Clock_ns.run_at_intervals live_words_sample_interval refresh_live_words;
  Clock_ns.run_at_intervals sample_interval (fun () ->
    let stats = snapshot t in
    broadcast t stats;
    reset_window t)
;;

module For_testing = struct
  let snapshot = snapshot
  let reset = reset_window
end
