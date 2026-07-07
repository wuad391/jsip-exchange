(** The feed poll response — a bounded, oldest-first buffer of the exchange's
    most recent audit events, each tagged with a server-assigned monotonic
    [id] — packaged as a diffable value for {!Jsip_dashboard_protocol}'s
    [Polling_state_rpc].

    Mirrors {!Jsip_dashboard.Window} (only the element type differs): the
    buffer is the last {!max_events} entries, so a diff carries only the
    entries newer than the client's, and {!update} reconstructs the exact
    buffer by appending and re-capping. The client holds every symbol's
    events and filters locally, so the feed's per-symbol tabs switch
    instantly. Implements (duck-typed, so it needs no RPC dependency) the
    [Polling_state_rpc.Response] signature. *)

open! Core
open Jsip_types

(** How many of the most recent events the buffer retains. *)
val max_events : int

type t = (int * Exchange_event.t) list [@@deriving bin_io]

(** The entries appended since a client's last buffer. *)
module Update : sig
  type t = (int * Exchange_event.t) list [@@deriving bin_io, sexp_of]
end

(** [diffs ~from ~to_] is the entries in [to_] with an [id] newer than any in
    [from] — the ones the client is missing. *)
val diffs : from:t -> to_:t -> Update.t

(** [update from appended] appends the new entries and re-caps to
    {!max_events}, reproducing the server's buffer exactly. The server also
    uses it to admit a single new event: [update buffer [ id, event ]]. *)
val update : t -> Update.t -> t
