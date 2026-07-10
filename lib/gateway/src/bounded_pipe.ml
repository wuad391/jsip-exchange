open! Core
open! Async

module Policy = struct
  type t =
    | Drop_newest
    | Disconnect
  [@@deriving sexp_of]
end

module Limit = struct
  type t =
    { max_length : int
    ; policy : Policy.t
    }
  [@@deriving sexp_of]
end

(* Mirror the guard in {!Metrics.broadcast}: measure the buffer with
   [Pipe.length] (valid on a writer — both ends share the buffer) and only
   write while there's room. [Pipe.close] is idempotent, so applying
   [Disconnect] to an already-closed pipe is harmless; likewise
   [write_without_pushback_if_open] is a no-op once closed. *)
let push writer ~(limit : Limit.t) event =
  if Pipe.length writer < limit.max_length
  then Pipe.write_without_pushback_if_open writer event
  else (
    match limit.policy with
    | Drop_newest -> ()
    | Disconnect -> Pipe.close writer)
;;
