(** RPC definitions for client-server communication.

    Defines the RPCs that clients use to interact with the exchange server.
    Each RPC has a query type (what the client sends) and a response type
    (what the server returns).

    We use Async RPCs, but on a production exchange, clients would connect
    over a binary protocol like FIX or a proprietary format. *)

open! Core
open! Async
open Jsip_types
open Jsip_exchange_stats

(** Submit an order to the exchange.

    This is a one-way RPC. The server enqueues the order and returns as soon
    as possible. The matching engine processes the queued request on a
    background worker and hands the resulting [Exchange_event.t]s to the
    [Dispatcher], which routes participant-targeted events (acceptance,
    fills, rejection) to the owning participant's [Session]; the client reads
    them from its {!session_feed_rpc} pipe.

    The error case covers connection-level failures only — connection closed,
    server shutting down, etc. — not domain errors like unknown symbols
    (those arrive as [Order_reject] events on the session feed). *)
val submit_order_rpc : (Order.Request.t, unit Or_error.t) Rpc.Rpc.t

(** Query the order book for a given symbol. Returns a structured snapshot of
    all resting orders on both sides, if a book for that symbol exists. *)
val book_query_rpc : (Symbol_id.t, Book.t option) Rpc.Rpc.t

(** Fetch the exchange's symbol directory: the [(id, name)] pairs mapping
    each wire {!Jsip_types.Symbol_id.t} to its human-readable
    {!Jsip_types.Symbol.t}. A client fetches this once at connect and mirrors
    it locally (see {!Jsip_gateway.Symbol_directory}) so it can show [AAPL]
    instead of [0]; the wire itself stays int-only. *)
val symbol_directory_rpc : (unit, (Symbol_id.t * Symbol.t) list) Rpc.Rpc.t

(** Subscribe to market data for one or more symbols. The server pushes BBO
    updates and trade reports as they happen via a single pipe. The query is
    the list of symbols to subscribe to; using one RPC for the whole list
    avoids the overhead of opening a separate pipe per symbol when a client
    cares about several. *)
val market_data_rpc
  : (Symbol_id.t list, Exchange_event.t, Error.t) Rpc.Pipe_rpc.t

(** Subscribe to the full audit log: every [Exchange_event.t] the matching
    engine produces, across every symbol and participant.

    This RPC is intended for the exchange operator's monitoring and audit
    tools (e.g. the bonsai_term monitor in [app/monitor]) only. Ordinary
    participants — automated bots, human-driven clients — should use
    [market_data_rpc] for public events, and {!session_feed_rpc} for their
    own order-lifecycle events. A production exchange would gate this RPC
    behind operator-level credentials; this simulator does not, but the same
    intent applies. *)
val audit_log_rpc : (unit, Exchange_event.t, Error.t) Rpc.Pipe_rpc.t

(** Establish the connection's identity: the query is the participant name,
    and every subsequent order operation on this connection acts as that
    participant. Rejects empty names and names that already have a live
    session. Logging in announces a [Session_status Connected] on the audit
    log; the connection closing announces the [Disconnected] twin. *)
val login_rpc : (String.t, Participant.t Or_error.t) Rpc.Rpc.t

(** The logged-in participant's own event stream: acceptances, fills,
    cancellations, and rejections for their orders. One stream per session. *)
val session_feed_rpc : (unit, Exchange_event.t, Error.t) Rpc.Pipe_rpc.t

(** Cancel one resting order, identified by the client-supplied id the
    logged-in participant submitted it under. The outcome ([Order_cancel] or
    [Cancel_reject]) arrives on the session feed. *)
val cancel_order_rpc : (Client_order_id.t, unit Or_error.t) Rpc.Rpc.t

(** Cancel every resting order the logged-in participant has, in one request.
    It travels the same ordered request queue as submits and cancels, so it
    strictly follows anything this session already enqueued; and unlike those
    one-way RPCs, the response — the number of orders cancelled — is returned
    only after the engine has processed the sweep and dispatched its events
    (one [Order_cancel] per order with reason [Mass_cancel], on the session
    feed). The interactive console uses this to flatten a bot before
    disconnecting it ([kill]). *)
val cancel_all_rpc : (unit, int Or_error.t) Rpc.Rpc.t

(** Subscribe to the exchange's per-second health telemetry: memory, submit
    and cancel latency percentiles, pipe occupancy, per-participant order
    rates, and matching-engine load. One {!Exchange_stats.t} is pushed per
    second.

    This is operator-facing infrastructure monitoring, deliberately separate
    from {!audit_log_rpc}: the audit log carries
    {!Jsip_types.Exchange_event.t} (what the engine did), while this carries
    resource metrics (how the process is coping). The [app/dashboard]
    monitoring UI is the intended consumer. *)
val exchange_stats_rpc : (unit, Exchange_stats.t, Error.t) Rpc.Pipe_rpc.t
