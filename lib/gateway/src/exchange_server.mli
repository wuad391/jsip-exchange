(** Exchange server for production use and testing.

    Bundles the matching engine, market data bus, and RPC implementations
    into a single server that can be started on any port. Used by the server
    binary, the market maker binary, and integration tests. *)

open! Core
open! Async
open Jsip_types

type t

(** How the server accepts incoming RPC connections.

    - [Plaintext]: today's unauthenticated TCP. Participant identity comes
      entirely from whatever name a client passes to [login_rpc].
    - [Tls]: connections are terminated in mutual TLS instead. Every client
      must present a certificate signed by the configured CA, and the
      participant is established directly from that certificate's CN --
      [login_rpc] is never called on a TLS connection. Build the
      {!Async_ssl.Config.Server.t} with {!Tls_config.server_config}. *)
type transport =
  | Plaintext
  | Tls of Async_ssl.Config.Server.t

(** Start a server on the given port with the given symbols. Returns the
    server handle and the port it is actually listening on (useful when you
    pass port 0 to get an OS-assigned port). Defaults to [Plaintext]. *)
val start
  :  ?transport:transport
  -> symbols:Symbol.t list
  -> port:int
  -> unit
  -> t Deferred.t

(** The port the server is listening on. *)
val port : t -> int

(** Stop the server and close all connections. *)
val close : t -> unit Deferred.t

(** Wait until the server's TCP listener is closed. *)
val close_finished : t -> unit Deferred.t
