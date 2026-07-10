(** Central event-routing component for the gateway.

    Owns subscription registries:

    - **Market-data subscribers**, keyed by [Symbol_id.t]. Each subscriber
      gets a pipe of [Best_bid_offer_update] and [Trade_report] events for
      the symbol they asked about. This is the public market-data feed.

    - **Audit subscribers**, an unfiltered firehose of every event the
      matching engine produces. Intended for the exchange operator's monitor;
      not appropriate to expose to ordinary clients.

    - **Sessions**, table mapping each participant to their session

    [dispatch] is the single place that decides "for each event, who gets
    it". *)

open! Core
open! Async
open Jsip_types

type t

(** Create a dispatcher with no subscribers and no sessions. *)
val create : unit -> t

(** Subscribe to public market data for one or more [symbols]. The same pipe
    receives events for every requested symbol; the dispatcher avoids
    duplicates so a subscriber listed against multiple symbols only sees each
    event once. The pipe is removed from the dispatcher when its reader is
    closed. *)
val subscribe_market_data
  :  t
  -> Symbol_id.t list
  -> Exchange_event.t Pipe.Reader.t

(** Subscribe to the full unfiltered event firehose. Intended for the monitor
    / admin tools. *)
val subscribe_audit : t -> Exchange_event.t Pipe.Reader.t

(** Route each event to every interested subscriber:

    - Every event is pushed to every audit subscriber.
    - [Best_bid_offer_update] and [Trade_report] are pushed to the
      market-data subscribers that asked for the event's symbol.
    - [Order_accept], [Order_cancel], and [Order_reject] are pushed to the
      session of the order's owning participant (if logged in).
    - [Fill] is pushed to both the aggressor's and the resting party's
      session (if either is logged in).
    - [Session_status] goes to the audit subscribers only (which every event
      already reaches) — operator telemetry, deliberately not echoed to the
      participant's own session feed or to market data.

    Each session lookup is O(1) and independent of subscriber count. *)
val dispatch : t -> Exchange_event.t list -> unit

(** Whether [participant] currently has a live session. *)
val is_active : t -> Participant.t -> Bool.t

(** Register a session for [participant] (cleaning up any stale one first)
    and announce it: a [Session_status Connected] event reaches the audit
    subscribers. The gateway calls this from [login_rpc]. *)
val set_up_session : t -> Participant.t -> unit Deferred.t

(** The live session for [participant], if any. *)
val lookup_session : t -> Participant.t -> Session.t Option.t

(** Remove [session] from the registry and close its outbound pipe, then
    announce a [Session_status Disconnected] to the audit subscribers. The
    gateway calls this when a logged-in connection closes. *)
val clean_up_session : t -> Session.t -> unit Deferred.t

(** Current queue length of every audit-subscriber pipe. Used by {!Metrics}
    to report audit-feed occupancy; a large value means an audit consumer
    (e.g. the monitor) is falling behind. *)
val audit_queue_lengths : t -> int list

(** Current queue length of every per-symbol market-data pipe. A subscriber
    listening to several symbols is counted once per symbol. *)
val market_data_queue_lengths : t -> int list

(** Current queue length of every logged-in participant's session pipe. *)
val session_queue_lengths : t -> int list

module For_testing : sig
  val audit_subscriber_count : t -> int
end
