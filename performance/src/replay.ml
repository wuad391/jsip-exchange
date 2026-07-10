open! Core
open Jsip_types
open Jsip_order_book
open Jsip_exchange_stats

(* Self-check thresholds. Generous on purpose: the checks exist to catch a
   preset that is *qualitatively* broken (nothing trades; the book never
   stops growing), not to enforce tight tolerances while tuning. *)
let fill_rate_tolerance = 0.10
let depth_growth_ratio_limit = 1.25
let depth_growth_slack_orders = 500

(* Tallies of every event the engine emitted over the run. One mutable record
   rather than a Map so the hot loop stays allocation-free. *)
type event_counts =
  { mutable accepts : int
  ; mutable fills : int
  ; mutable order_cancels : int
  ; mutable order_rejects : int
  ; mutable cancel_rejects : int
  ; mutable bbo_updates : int
  ; mutable trade_reports : int
  }

let zero_counts () =
  { accepts = 0
  ; fills = 0
  ; order_cancels = 0
  ; order_rejects = 0
  ; cancel_rejects = 0
  ; bbo_updates = 0
  ; trade_reports = 0
  }
;;

(* Returns whether the batch contained at least one fill, which is how the
   run measures "this submit crossed" for the realized-fill-rate check. *)
let tally counts (events : Exchange_event.t list) =
  List.fold events ~init:false ~f:(fun had_fill (event : Exchange_event.t) ->
    match event with
    | Fill _ ->
      counts.fills <- counts.fills + 1;
      true
    | Order_accept _ ->
      counts.accepts <- counts.accepts + 1;
      had_fill
    | Order_cancel _ ->
      counts.order_cancels <- counts.order_cancels + 1;
      had_fill
    | Order_reject _ ->
      counts.order_rejects <- counts.order_rejects + 1;
      had_fill
    | Cancel_reject _ ->
      counts.cancel_rejects <- counts.cancel_rejects + 1;
      had_fill
    | Best_bid_offer_update _ ->
      counts.bbo_updates <- counts.bbo_updates + 1;
      had_fill
    | Trade_report _ ->
      counts.trade_reports <- counts.trade_reports + 1;
      had_fill)
;;

let total_resting engine =
  Matching_engine.resting_order_counts engine
  |> Map.data
  |> List.fold ~init:0 ~f:( + )
;;

(* Words the program allocated so far, GC-independent: everything ever
   allocated in the minor heap plus directly in the major heap, minus the
   double-count of survivors promoted from one to the other. *)
let allocated_words (stat : Gc.Stat.t) =
  stat.minor_words +. stat.major_words -. stat.promoted_words
;;

let run ~preset_name ~config ~num_actions ~seed ~depth_every ~gc_every =
  let engine =
    Matching_engine.create config.Workload_generator.Config.num_symbols
  in
  let generator = Workload_generator.create ~config ~seed in
  let submit_latency = Latency_histogram.create () in
  let cancel_latency = Latency_histogram.create () in
  let counts = zero_counts () in
  let submits_filled = ref 0 in
  let depth_samples = Queue.create () in
  printf
    "replay: preset=%s seed=%d actions=%d\n"
    preset_name
    seed
    num_actions;
  printf
    "config: %s\n\n"
    (Sexp.to_string_hum
       ~indent:1
       [%sexp (config : Workload_generator.Config.t)]);
  let gc_start : Gc.Stat.t = Gc.stat () in
  let started_at = Time_ns.now () in
  for action_idx = 1 to num_actions do
    (match Workload_generator.next_action generator with
     | Submit request ->
       let before = Time_ns.now () in
       let events =
         Matching_engine.submit
           engine
           ~participant:request.participant
           request
       in
       let after = Time_ns.now () in
       Latency_histogram.record
         submit_latency
         ~ns:(Time_ns.Span.to_int_ns (Time_ns.diff after before));
       if tally counts events then incr submits_filled
     | Cancel cancel ->
       let before = Time_ns.now () in
       let events = Matching_engine.cancel engine cancel in
       let after = Time_ns.now () in
       Latency_histogram.record
         cancel_latency
         ~ns:(Time_ns.Span.to_int_ns (Time_ns.diff after before));
       let (_ : bool) = tally counts events in
       ());
    if depth_every > 0 && action_idx % depth_every = 0
    then Queue.enqueue depth_samples (action_idx, total_resting engine);
    if gc_every > 0 && action_idx % gc_every = 0
    then (
      let gc = Exchange_stats.Gc_snapshot.of_stat (Gc.stat ()) in
      printf
        "[gc] actions=%d live_words=%d heap_words=%d minor=%d major=%d\n"
        action_idx
        gc.live_words
        gc.heap_words
        gc.minor_collections
        gc.major_collections)
  done;
  let elapsed = Time_ns.diff (Time_ns.now ()) started_at in
  let gc_end : Gc.Stat.t = Gc.stat () in
  (* Report. *)
  let seconds = Time_ns.Span.to_sec elapsed in
  printf
    "%-8s %.2fs  (%.0f actions/sec)\n"
    "wall"
    seconds
    (Float.of_int num_actions /. seconds);
  print_endline
    (Latency_histogram.summary_line submit_latency ~label:"submit");
  print_endline
    (Latency_histogram.summary_line cancel_latency ~label:"cancel");
  printf
    "%-8s accepts=%d fills=%d order_cancels=%d order_rejects=%d\n"
    "events"
    counts.accepts
    counts.fills
    counts.order_cancels
    counts.order_rejects;
  printf
    "%-8s cancel_rejects=%d bbo_updates=%d trade_reports=%d\n"
    ""
    counts.cancel_rejects
    counts.bbo_updates
    counts.trade_reports;
  (match Queue.to_list depth_samples with
   | [] -> printf "%-8s (no samples: depth-every > num-actions)\n" "depth"
   | samples ->
     printf
       "%-8s %s\n"
       "depth"
       (String.concat
          ~sep:"  "
          (List.map samples ~f:(fun (actions, depth) ->
             [%string "%{actions#Int}:%{depth#Int}"]))));
  let allocated = allocated_words gc_end -. allocated_words gc_start in
  printf
    "%-8s allocated=%.3e words (%.1f words/action)\n"
    "gc"
    allocated
    (allocated /. Float.of_int num_actions);
  printf
    "%-8s minor_collections=%d major_collections=%d\n"
    ""
    (gc_end.minor_collections - gc_start.minor_collections)
    (gc_end.major_collections - gc_start.major_collections);
  printf
    "%-8s live_words %d -> %d (delta %+d)  top_heap_words=%d\n"
    ""
    gc_start.live_words
    gc_end.live_words
    (gc_end.live_words - gc_start.live_words)
    gc_end.top_heap_words;
  print_endline "";
  (* Steady-state self-checks: warn loudly, never change the exit code. *)
  let num_submits = Latency_histogram.count submit_latency in
  (match num_submits with
   | 0 -> printf "%-8s fill rate: skipped (no submits)\n" "checks"
   | _ ->
     let realized =
       Float.of_int !submits_filled /. Float.of_int num_submits
     in
     let intended = config.marketable_fraction in
     let diff = Float.abs (realized -. intended) in
     printf
       "%-8s fill rate: realized=%.3f intended=%.3f  %s\n"
       "checks"
       realized
       intended
       (if Float.( <= ) diff fill_rate_tolerance then "OK" else "VIOLATED");
     if Float.( > ) diff fill_rate_tolerance
     then
       printf
         "WARNING: realized fill rate is off by %.3f (> %.2f tolerance).\n\
         \  Marketable orders may not be crossing (choose_price vs\n\
         \  drift_cents/resting_offset_cents interplay), or the far side is\n\
         \  empty too often. The book will not hold steady state.\n"
         diff
         fill_rate_tolerance);
  match Queue.to_list depth_samples with
  | [] | [ _ ] ->
    printf "%-8s depth plateau: skipped (fewer than 2 samples)\n" ""
  | samples ->
    let mid_idx = (List.length samples - 1) / 2 in
    let _, mid_depth = List.nth_exn samples mid_idx in
    let _, final_depth = List.last_exn samples in
    let limit =
      (Float.of_int mid_depth *. depth_growth_ratio_limit)
      +. Float.of_int depth_growth_slack_orders
    in
    let still_growing = Float.( > ) (Float.of_int final_depth) limit in
    printf
      "%-8s depth plateau: mid=%d final=%d  %s\n"
      ""
      mid_depth
      final_depth
      (if still_growing then "VIOLATED" else "OK");
    if still_growing
    then
      printf
        "WARNING: book depth grew from %d to %d between mid-run and end\n\
        \  (limit was %.0f). Resting orders are accumulating faster than\n\
        \  fills + cancels drain them; this preset is not at steady state.\n"
        mid_depth
        final_depth
        limit
;;

let preset_arg =
  Command.Arg_type.create (fun name ->
    match
      List.Assoc.find Workload_generator.Config.all name ~equal:String.equal
    with
    | Some config -> name, config
    | None ->
      raise_s
        [%message
          "unknown preset"
            (name : string)
            ~valid:
              (List.map Workload_generator.Config.all ~f:fst : string list)])
;;

let command =
  Command.basic
    ~summary:"Replay a generated workload through the matching engine"
    ~readme:(fun () ->
      "Runs one preset per invocation so a perf profile or GC trace of the \
       process covers exactly one workload. Steady-state check failures \
       print WARNING blocks but do not affect the exit code.")
    (let%map_open.Command preset =
       flag
         "-preset"
         (optional_with_default
            ("balanced", Workload_generator.Config.balanced)
            preset_arg)
         ~doc:
           (sprintf
              "NAME workload shape: %s (default: balanced)"
              (String.concat
                 ~sep:"|"
                 (List.map Workload_generator.Config.all ~f:fst)))
     and num_actions =
       flag
         "-num-actions"
         (optional_with_default 1_000_000 int)
         ~doc:"N total submit/cancel actions to replay (default: 1000000)"
     and seed =
       flag
         "-seed"
         (optional_with_default 0 int)
         ~doc:"N generator seed; same seed = same stream (default: 0)"
     and depth_every =
       flag
         "-depth-every"
         (optional_with_default 100_000 int)
         ~doc:
           "N sample total book depth every N actions; 0 = never (default: \
            100000)"
     and gc_every =
       flag
         "-gc-every"
         (optional_with_default 0 int)
         ~doc:
           "N print a Gc.stat line every N actions; 0 = never. Each sample \
            walks the heap, so leave off when profiling (default: 0)"
     in
     fun () ->
       let preset_name, config = preset in
       run ~preset_name ~config ~num_actions ~seed ~depth_every ~gc_every)
;;
