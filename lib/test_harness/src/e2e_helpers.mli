(** Shared helpers for end-to-end tests that use a real server and RPC
    clients. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway

(** Start a server on an OS-assigned port, run [f], then shut down. Defaults
    to [Exchange_server.Plaintext]; pass [~transport:(Tls ...)] for tests
    that need a TLS-terminated server. *)
val with_server
  :  ?transport:Exchange_server.transport
  -> symbols:Symbol.t list
  -> (server:Exchange_server.t -> port:int -> 'a Deferred.t)
  -> 'a Deferred.t

(** A test client: an open RPC connection to the server. A future revision
    (once the session-feed RPC and login flow exist) will extend this with a
    buffered session feed so [rpc_submit] can return the events produced by
    the just-submitted request. *)
type client

(** Connect a client to [port]. The participant argument is used to print
    per-participant events when an expect test binds. *)
val connect_as
  :  port:int
  -> ?login:Bool.t
  -> Participant.t
  -> client Deferred.t

(** Connect to [port] over mutual TLS using the given cert/key/CA files,
    presenting [crt_file]/[key_file] as this client's identity. There is no
    [login_rpc] call: the server establishes the session directly from the
    cert. [participant] is only used to label printed session events; it is
    not sent to the server, so a mismatch between it and the cert's actual CN
    doesn't affect the connection, only test output labeling. Raises if the
    handshake or connection setup fails -- callers testing a rejection path
    should wrap the call in [Monitor.try_with_or_error]. *)
val connect_as_tls
  :  port:int
  -> crt_file:string
  -> key_file:string
  -> ca_file:string
  -> Participant.t
  -> client Deferred.t

(** The raw RPC connection, useful for tests that exercise unusual RPC paths
    (audit log subscriptions, second clients on the same connection, etc.). *)
val connection : client -> Rpc.Connection.t

(** Submit an order via RPC. The RPC is one-way: this returns once the server
    has enqueued the request. Participant-targeted events (acceptance, fills,
    rejection) are currently printed on the server's stdout via the
    dispatcher's session stub. *)
val rpc_submit : client -> Order.Request.t -> unit Deferred.t

(** Query the book via RPC. *)
val rpc_book : client -> Symbol.t -> Book.t option Deferred.t

val rpc_cancel : client -> Client_order_id.t -> unit Deferred.t
val rpc_subscribe : client -> Symbol.t list -> string -> unit Deferred.t
