open! Core
open! Async
open Jsip_types

let server_config ~crt_file ~key_file ~ca_file =
  Async_ssl.Config.Server.create
    ~verify_modes:
      Async_ssl.Verify_mode.[ Verify_peer; Verify_fail_if_no_peer_cert ]
    ~crt_file
    ~key_file
    ~ca_file:(Some ca_file)
    ~ca_path:None
    ()
;;

let client_config ~crt_file ~key_file ~ca_file =
  Async_ssl.Config.Client.create
    ~crt_file
    ~key_file
    ~remote_hostname:None
    ~ca_file:(Some ca_file)
    ~ca_path:None
    ~verify_callback:(fun (_ : Async_ssl.Ssl.Connection.t) ->
      (* [Async_ssl] already checked the server certificate's signature chain
         against [ca_file] before this callback runs; nothing extra to check
         yet. *)
      Deferred.return (Ok ()))
    ()
;;

let participant_of_peer_cert (conn : Async_ssl.Ssl.Connection.t)
  : Participant.t Or_error.t
  =
  match Async_ssl.Ssl.Connection.peer_certificate conn with
  | None ->
    Or_error.error_string
      "TLS connection has no peer certificate (unexpected under \
       Verify_fail_if_no_peer_cert)"
  | Some (Error error) -> Error error
  | Some (Ok cert) ->
    let subject = Async_ssl.Ssl.Certificate.subject cert in
    (match List.Assoc.find subject "CN" ~equal:String.equal with
     | Some cn -> Ok (Participant.of_string cn)
     | None ->
       Or_error.error_s
         [%message
           "Peer certificate has no CN field"
             (subject : (string * string) list)])
;;
