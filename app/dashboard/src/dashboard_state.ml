open! Core
open Jsip_exchange_stats

let max_window = 60

module Gc_rate = struct
  type t =
    { minor_per_sec : int
    ; major_per_sec : int
    }
  [@@deriving sexp, equal]

  let zero = { minor_per_sec = 0; major_per_sec = 0 }
end

(* Snapshots are held newest-first so [add] is a cheap prepend + truncate.
   The public [snapshots] reverses to oldest-first, the order charts want. *)
type t = { newest_first : Exchange_stats.t list }

let empty = { newest_first = [] }

let add t snapshot =
  { newest_first = List.take (snapshot :: t.newest_first) max_window }
;;

let snapshots t = List.rev t.newest_first
let latest t = List.hd t.newest_first

(* Cumulative counters differenced across the last second give a rate,
   because snapshots arrive once per second. *)
let minor_collections (s : Exchange_stats.t) = s.gc.minor_collections
let major_collections (s : Exchange_stats.t) = s.gc.major_collections

let gc_rate t =
  match t.newest_first with
  | current :: previous :: _ ->
    { Gc_rate.minor_per_sec =
        minor_collections current - minor_collections previous
    ; major_per_sec = major_collections current - major_collections previous
    }
  | [] | [ _ ] -> Gc_rate.zero
;;
