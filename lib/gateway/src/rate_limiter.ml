open! Core

type t =
  { mutable tokens : float
  ; mutable last_refill : Time_ns.t
  ; burst : float
  ; refill_per_sec : float
  }

let create ~burst ~refill_per_sec =
  { tokens = Float.of_int burst
  ; (* Start [last_refill] at the epoch. The bucket starts full, and the
       first [try_consume] refills by a huge elapsed span that clamps
       straight back to [burst] — so the choice of initial time is harmless. *)
    last_refill = Time_ns.epoch
  ; burst = Float.of_int burst
  ; refill_per_sec
  }
;;

(* Refill the bucket for the time elapsed since [last_refill] (capped at
   [burst]), advance [last_refill] to [now], then consume one token if the
   bucket has at least one. Return whether a token was consumed. *)
let try_consume t ~now =
  let elapsed_sec = Time_ns.Span.to_sec (Time_ns.diff now t.last_refill) in
  t.tokens
  <- Float.min t.burst (t.tokens +. (elapsed_sec *. t.refill_per_sec));
  t.last_refill <- now;
  if Float.(t.tokens >= 1.)
  then (
    t.tokens <- t.tokens -. 1.;
    true)
  else false
;;
