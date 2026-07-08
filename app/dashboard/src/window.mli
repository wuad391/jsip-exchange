(** The dashboard poll response — the rolling window of per-second snapshots,
    oldest first — packaged as a diffable value for
    {!Jsip_dashboard_protocol}'s [Polling_state_rpc].

    Snapshots carry a monotonic [seq] and the window is the last
    {!Dashboard_state.max_window} of them, so a diff carries only the
    snapshots newer than the client's, and {!update} reconstructs the exact
    window by appending and re-capping. Implements (duck-typed, so it needs
    no RPC dependency) the [Polling_state_rpc.Response] signature. *)

open! Core
open Jsip_exchange_stats

type t = Exchange_stats.t list [@@deriving bin_io]

(** The snapshots appended since a client's last window. *)
module Update : sig
  type t = Exchange_stats.t list [@@deriving bin_io, sexp_of]
end

(** [diffs ~from ~to_] is the snapshots in [to_] with a [seq] newer than any
    in [from] — the ones the client is missing. *)
val diffs : from:t -> to_:t -> Update.t

(** [update from appended] appends the new snapshots and re-caps to the
    window length, reproducing the server's window exactly. *)
val update : t -> Update.t -> t
