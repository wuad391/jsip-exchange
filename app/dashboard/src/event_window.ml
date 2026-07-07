open! Core
open Jsip_types

(* The feed poll response: a bounded, oldest-first buffer of the exchange's
   most recent audit events, each tagged with a server-assigned monotonic
   [id], packaged as a diffable value for the [Polling_state_rpc].

   It mirrors [Window] exactly — only the element type differs. Because every
   entry carries a strictly increasing [id] and the buffer is always the last
   [max_events] of them, a diff need only carry the entries newer than the
   ones the client already holds; [update] reconstructs the server buffer by
   appending them and re-capping. The client then filters by symbol locally,
   so switching the feed's symbol tab is instant — no re-fetch.

   This is the (duck-typed) [Polling_state_rpc.Response] interface — [t] with
   [bin_io], an [Update] with [bin_io]+[sexp_of], and [diffs]/[update] — so
   the module itself needs no RPC dependency. [Exchange_event.t] is [bin_io],
   so the paired [(int * Exchange_event.t) list] is too. *)

let max_events = 200

type t = (int * Exchange_event.t) list [@@deriving bin_io]

let id ((id, _) : int * Exchange_event.t) = id

module Update = struct
  (* The entries appended since the client's buffer — usually just the events
     from the last poll interval. *)
  type t = (int * Exchange_event.t) list [@@deriving bin_io, sexp_of]
end

let newest_id buffer =
  List.fold buffer ~init:0 ~f:(fun acc entry -> Int.max acc (id entry))
;;

let diffs ~from ~to_ =
  let threshold = newest_id from in
  List.filter to_ ~f:(fun entry -> id entry > threshold)
;;

let update from appended =
  let combined = from @ appended in
  let overflow = Int.max 0 (List.length combined - max_events) in
  List.drop combined overflow
;;
