open! Core
open! Async
open Jsip_types

(* Per-participant rate-limit capacities, in tokens and tokens/second (see
   {!Rate_limiter}). *)
module Limits = struct
  type t =
    { submit_burst : int
    ; submit_refill_per_sec : float
    ; cancel_burst : int
    ; cancel_refill_per_sec : float
    }

  (* A well-behaved client (noise or momentum trader) submits a few
     orders/second and never cancels; the seed market maker is the only
     honest source of cancels, and it cancels-all then reseeds (~10 orders
     per side) on every fill, in bursts. [*_burst = 20] clears a full reseed
     burst with headroom; [*_refill_per_sec = 30.] clears several
     reseeds/second of sustained honest load — while every pathological bot
     sits 1-4 orders of magnitude above this (the cancel storm alone is ~500
     submits+cancels/sec).

     Cancels are deliberately NOT capped tighter than submits: on this
     exchange the honest cancel traffic (the market maker) is as heavy as the
     honest submit traffic, so a tighter cancel budget would throttle the
     legitimate market maker before it touched any attacker. Calibrate
     against the dashboard before trusting these exact numbers. *)
  let default =
    { submit_burst = 20
    ; submit_refill_per_sec = 30.
    ; cancel_burst = 20
    ; cancel_refill_per_sec = 30.
    }
  ;;
end

type t =
  { participant : Participant.t
  ; reader : Exchange_event.t Pipe.Reader.t
  ; writer : Exchange_event.t Pipe.Writer.t
  ; submit_limiter : Rate_limiter.t
  ; cancel_limiter : Rate_limiter.t
  }

let create ?(limits = Limits.default) participant =
  let reader, writer = Pipe.create () in
  let { Limits.submit_burst
      ; submit_refill_per_sec
      ; cancel_burst
      ; cancel_refill_per_sec
      }
    =
    limits
  in
  { participant
  ; reader
  ; writer
  ; submit_limiter =
      Rate_limiter.create
        ~burst:submit_burst
        ~refill_per_sec:submit_refill_per_sec
  ; cancel_limiter =
      Rate_limiter.create
        ~burst:cancel_burst
        ~refill_per_sec:cancel_refill_per_sec
  }
;;

let participant t = t.participant
let reader t = t.reader
let submit_limiter t = t.submit_limiter
let cancel_limiter t = t.cancel_limiter
let push t event = Pipe.write_without_pushback_if_open t.writer event
let close t = Pipe.close t.writer
let is_closed t = Pipe.is_closed t.writer
let queue_length t = Pipe.length t.writer
