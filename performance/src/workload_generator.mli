(** A deterministic stream of order submits and cancels for driving the
    {!Jsip_order_book.Matching_engine} under sustained load.

    Part 4's micro-benchmarks time one operation in isolation; to see where
    the engine spends its cycles under realistic flow we need a firehose of
    orders that (a) is fully reproducible from a seed, and (b) holds the book
    at a steady state so every moment of a run measures the same thing. This
    module is (a); the steady-state tuning is what the {!Config} presets and
    the {!Replay} driver's self-checks are for.

    Every "random" choice flows from a single {!Splittable_random.State}
    seeded once, so the same [seed] always yields the same action sequence.
    The generator is decoupled from the engine: it models each symbol's fair
    value as its own random walk and prices orders around that, rather than
    reading the live book — which keeps it deterministic and allocation-light
    (a graded concern: we don't want to profile the generator instead of the
    engine).

    Typical use, in {!Replay}:
    {[
      let config = Config.balanced in
      let engine = Matching_engine.create config.num_symbols in
      let gen = create ~config ~seed:0 in
      match next_action gen with
      | Submit request ->
        Matching_engine.submit
          engine
          ~participant:request.participant
          request
      | Cancel cancel -> Matching_engine.cancel engine cancel
    ]} *)

open! Core
open Jsip_types

(** The shape of the traffic. The presets below are starting points, tuned so
    each reaches its intended steady state; adjust the numbers as the
    driver's depth / fill-rate self-checks tell you to. *)
module Config : sig
  type t =
    { num_symbols : int (** distinct symbol ids [0 .. num_symbols-1] *)
    ; num_participants : int
    (** distinct participants, each with its own id space *)
    ; cancel_fraction : float
    (** P(an action cancels a resting order vs submits a new one) *)
    ; marketable_fraction : float
    (** P(a submit is priced to cross) vs placed to rest *)
    ; ioc_fraction : float (** among marketable submits, P(IOC) vs Day *)
    ; min_size : int (** smallest order size (>= 1) *)
    ; max_size : int (** largest order size *)
    ; reference_price_cents : int (** each symbol's fair value starts here *)
    ; drift_cents : int
    (** max +/- the fair value random-walks per submit; 0 pins it *)
    ; resting_offset_cents : int
    (** how far off the fair value resting orders sit *)
    ; cancel_pool_size : int
    (** capacity of the bounded ring cancels are drawn from *)
    }
  [@@deriving sexp_of]

  (** Roughly matched submit/cancel/fill rates: depth plateaus. *)
  val balanced : t

  (** Cancel-heavy, thin book: stresses add+remove churn. *)
  val churn : t

  (** Mostly resting Day orders: a deep — but still bounded — book. *)
  val book_heavy : t

  (** [(name, config)] pairs for a [-preset] command-line argument. *)
  val all : (string * t) list
end

type t

(** One unit of traffic. The driver executes it against the engine; the
    embedded [request.participant] is the participant to submit as. *)
type action =
  | Submit of Order.Request.t
  | Cancel of Order.Cancel.t

(** Build a generator. All state (per-participant id generators, per-symbol
    fair values, the cancel ring) is preallocated here, so {!next_action}
    allocates only the one request/cancel record it returns. Requires
    [num_symbols], [num_participants], and [cancel_pool_size] all [>= 1]. *)
val create : config:Config.t -> seed:int -> t

(** Produce the next action, advancing the RNG (and the chosen symbol's fair
    value, for a submit). Deterministic given the seed. *)
val next_action : t -> action

(** The config this generator was built with — the driver reads [num_symbols]
    to size the engine and [marketable_fraction] to check the realized fill
    rate against intent. *)
val config : t -> Config.t
