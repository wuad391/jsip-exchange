(** The replay driver: pushes a {!Workload_generator} stream through a fresh
    {!Jsip_order_book.Matching_engine} and reports what happened — latency
    percentiles ({!Latency_histogram}), event counts, book-depth trajectory,
    GC deltas — plus steady-state self-checks.

    One invocation runs {e one} preset: the process is the unit of
    measurement, so a [perf record] of a run profiles exactly one workload
    and the GC numbers start from a cold heap. To compare presets, run it
    three times:
    {[
      for p in balanced churn book-heavy; do
        main.exe replay -preset $p -num-actions 1000000
      done
    ]}

    The self-checks (realized fill rate vs the preset's
    [marketable_fraction]; book depth plateauing rather than growing) print
    loud [WARNING] blocks but never change the exit code — this is an
    exploratory tool, and a run that drifted out of steady state still has
    numbers worth reading. *)

open! Core

(** [replay] subcommand for the perf binary's {!Command.group}. Flags:
    [-preset], [-num-actions], [-seed], [-depth-every], and [-gc-every]
    (periodic [Gc.stat] sampling for leak hunts; off by default because each
    sample walks the heap). *)
val command : Command.t
