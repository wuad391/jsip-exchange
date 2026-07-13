(** Exchange server for production use and testing.

    Bundles the matching engine, market data bus, and RPC implementations
    into a single server that can be started on any port. Used by the server
    binary, the market maker binary, and integration tests. *)

open! Core
open! Async
open Jsip_symbol_directory

type t

(** Start a server on the given port trading the symbols in [directory]
    (which fixes both the count and the id<->name mapping; the engine runs on
    ids [0 .. num_symbols - 1] and the server serves [directory] over
    {!Rpc_protocol.symbol_directory_rpc}). Returns the server handle and the
    port it is actually listening on (useful when you pass port 0 to get an
    OS-assigned port).

    [dispatcher_config] sets the per-subscriber pipe bounds — how much a slow
    market-data, audit, or session consumer may buffer before its policy
    (drop or disconnect) takes effect. See {!Dispatcher.Config}. *)
val start
  :  directory:Symbol_directory.t
  -> dispatcher_config:Dispatcher.Config.t
  -> port:int
  -> unit
  -> t Deferred.t

(** The port the server is listening on. *)
val port : t -> int

(** Stop the server and close all connections. *)
val close : t -> unit Deferred.t

(** Wait until the server's TCP listener is closed. *)
val close_finished : t -> unit Deferred.t
