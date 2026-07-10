(** TLS configuration and cert-derived identity for the exchange's RPC
    connections.

    Builds {!Async_ssl.Config.Server.t} / {!Async_ssl.Config.Client.t} from
    cert/key/CA file paths, and turns a verified peer certificate into the
    {!Jsip_types.Participant.t} it belongs to. Used by {!Exchange_server} on
    the server side, and by the client-side connection setup in [app/client]
    and [app/server] on the other. *)

open! Core
open! Async

(** Server-side TLS config: presents [crt_file]/[key_file] as the server's
    own identity, and requires every connecting client to present a
    certificate signed by [ca_file]
    ([Verify_peer]/[Verify_fail_if_no_peer_cert]). A client that connects
    without a certificate, or with one signed by a different CA, never
    completes the handshake -- {!participant_of_peer_cert} only ever runs on
    connections that already passed this check. *)
val server_config
  :  crt_file:string
  -> key_file:string
  -> ca_file:string
  -> Async_ssl.Config.Server.t

(** Client-side TLS config: presents [crt_file]/[key_file] as this client's
    own identity, and trusts a server certificate signed by [ca_file]. *)
val client_config
  :  crt_file:string
  -> key_file:string
  -> ca_file:string
  -> Async_ssl.Config.Client.t

(** The participant a verified TLS connection belongs to, read from the peer
    certificate's CN field. Errors if the peer presented no certificate
    (unexpected on a connection built from {!server_config}, which requires
    one) or if the certificate has no CN. *)
val participant_of_peer_cert
  :  Async_ssl.Ssl.Connection.t
  -> Jsip_types.Participant.t Or_error.t
