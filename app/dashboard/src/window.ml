open! Core
open Jsip_exchange_stats

(* The dashboard poll response: the rolling window of per-second snapshots,
   oldest first, packaged as a diffable value for the [Polling_state_rpc].

   Every snapshot carries a monotonically increasing [seq], and the window is
   always the last [Dashboard_state.max_window] of them, so a diff need only
   carry the snapshots newer than the ones the client already holds; [update]
   reconstructs the exact server window by appending them and re-capping. That
   keeps the wire small no matter how large individual snapshots grow.

   This is the (duck-typed) [Polling_state_rpc.Response] interface — [t] with
   [bin_io], an [Update] with [bin_io]+[sexp_of], and [diffs]/[update] — so the
   module itself needs no RPC dependency. *)

type t = Exchange_stats.t list [@@deriving bin_io]

let seq (snapshot : Exchange_stats.t) = snapshot.seq

module Update = struct
  (* The snapshots appended since the client's window — usually just the one
     new second. *)
  type t = Exchange_stats.t list [@@deriving bin_io, sexp_of]
end

let newest_seq window =
  List.fold window ~init:0 ~f:(fun acc snapshot -> Int.max acc (seq snapshot))
;;

let diffs ~from ~to_ =
  let threshold = newest_seq from in
  List.filter to_ ~f:(fun snapshot -> seq snapshot > threshold)
;;

let update from appended =
  let combined = from @ appended in
  let overflow =
    Int.max 0 (List.length combined - Dashboard_state.max_window)
  in
  List.drop combined overflow
;;
