(** Shared helpers for end-to-end tests that use a real server and RPC
    clients. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway

(** Start a server on an OS-assigned port trading [num_symbols] symbols (ids
    [0, 1, ..., num_symbols - 1]), run [f], then shut down. *)
val with_server
  :  num_symbols:int
  -> (server:Exchange_server.t -> port:int -> 'a Deferred.t)
  -> 'a Deferred.t

(** A test client: an open RPC connection to the server. {!connect_as} (with
    the default [?login]) also subscribes the session feed and prints each of
    its events as [[for <name>] <event>], which is how e2e expect tests
    observe the matching engine's responses. *)
type client

(** Connect a client to [port]. The participant argument is used to print
    per-participant events when an expect test binds. *)
val connect_as
  :  port:int
  -> ?login:Bool.t
  -> Participant.t
  -> client Deferred.t

(** The raw RPC connection, useful for tests that exercise unusual RPC paths
    (audit log subscriptions, second clients on the same connection, etc.). *)
val connection : client -> Rpc.Connection.t

(** Submit an order via RPC. The RPC is one-way: this returns once the server
    has enqueued the request. Participant-targeted events (acceptance, fills,
    rejection) then arrive on the client's session feed and are printed by
    the {!connect_as} drain. *)
val rpc_submit : client -> Order.Request.t -> unit Deferred.t

(** Query the book via RPC. *)
val rpc_book : client -> Symbol_id.t -> Book.t option Deferred.t

(** Cancel one order by client id; the outcome arrives on the session feed. *)
val rpc_cancel : client -> Client_order_id.t -> unit Deferred.t

(** Cancel every resting order the logged-in client has, via the cancel-all
    RPC. Returns the number of orders cancelled; the per-order [Mass_cancel]
    events arrive on the session feed. *)
val rpc_cancel_all : client -> int Or_error.t Deferred.t

(** Subscribe to market data for [symbols], printing each event as
    [[for <name>] <event>]. *)
val rpc_subscribe : client -> Symbol_id.t list -> string -> unit Deferred.t
