open! Core
open! Async
open Jsip_types
open Jsip_symbol_directory

let help_text =
  String.concat
    ~sep:"\n"
    [ "commands:"
    ; "  spawn <kind> [<name>] [<SYMBOL>...] [key=value ...]"
    ; "      start a bot. Omitted name -> auto (e.g. mm-1); omitted"
    ; "      symbols -> every symbol; knobs are integers (see `kinds`)."
    ; "  kill <name>    cancel all the bot's orders, then disconnect it"
    ; "  crash <name>   disconnect WITHOUT cancelling — ghost orders stay"
    ; "  list           live bots with kind, symbols, and uptime"
    ; "  kinds          spawnable kinds and their knobs"
    ; "  help           this text"
    ; "  quit           kill every bot and shut the exchange down"
    ; ""
    ; "note: a crashed bot's ghost orders keep its old client order ids"
    ; "registered, so a respawn under the same name gets duplicate-id"
    ; "rejects until its counter passes them — kill avoids this."
    ]
;;

let kinds_text menu =
  List.map menu ~f:(fun (entry : Bot_menu.Entry.t) ->
    let knobs =
      List.map entry.knobs ~f:(fun { Bot_menu.Knob.name; doc; default } ->
        [%string "      %{name}=%{default#Int}  %{doc}"])
    in
    String.concat
      ~sep:"\n"
      ([%string "  %{entry.kind}: %{entry.doc}"] :: knobs))
  |> String.concat ~sep:"\n"
;;

(* Smallest N such that [kind-N] is not a live bot. A crashed bot's name is
   reused (it is gone from the registry), which is exactly the
   duplicate-client-order-id teaching moment [help_text] warns about. *)
let auto_name registry ~kind =
  let rec try_n n =
    let candidate = Participant.of_string [%string "%{kind}-%{n#Int}"] in
    if Bot_registry.mem registry candidate then try_n (n + 1) else candidate
  in
  try_n 1
;;

(* The server reaps a dying session asynchronously (off [close_finished]), so
   respawning a just-killed name can race the cleanup and be told the name is
   taken. Retry briefly before surfacing that. Matching on the error STRING
   is brittle-but-contained: the message lives in [Exchange_server]'s login
   handler. *)
let is_session_race_error error =
  String.is_substring
    (Error.to_string_hum error)
    ~substring:"already has a session active"
;;

let rec spawn_with_retry ~spawn ~attempts spec =
  match%bind spawn spec with
  | Ok handle -> return (Ok handle)
  | Error error when attempts > 1 && is_session_race_error error ->
    let%bind () = Clock_ns.after (Time_ns.Span.of_ms 100.) in
    spawn_with_retry ~spawn ~attempts:(attempts - 1) spec
  | Error _ as error -> return error
;;

let all_symbols directory =
  List.init (Symbol_directory.num_symbols directory) ~f:Symbol_id.of_int
;;

let do_spawn
  ~registry
  ~menu
  ~directory
  ~spawn
  ~rng_seed
  ~kind
  ~name
  ~symbols
  ~knobs
  =
  let spec_or_error =
    let open Or_error.Let_syntax in
    let%bind entry = Bot_menu.Entry.find menu ~kind in
    let%bind resolved =
      Bot_menu.Entry.resolve_knobs entry ~overrides:knobs
    in
    let participant =
      match name with
      | Some name -> Participant.of_string name
      | None -> auto_name registry ~kind:entry.kind
    in
    let symbols =
      match symbols with
      | [] -> all_symbols directory
      | _ :: _ as symbols -> symbols
    in
    let%bind () =
      if Bot_registry.mem registry participant
      then
        Or_error.error_s
          [%message
            "a bot with this name is already running"
              ~name:(participant : Participant.t)]
      else Ok ()
    in
    let%bind spec =
      entry.make ~participant ~symbols ~knobs:resolved ~rng_seed
    in
    Ok (participant, spec)
  in
  match spec_or_error with
  | Error error ->
    print_s [%sexp (error : Error.t)];
    return ()
  | Ok (participant, spec) ->
    (match%bind spawn_with_retry ~spawn ~attempts:5 spec with
     | Error error ->
       print_s [%sexp (error : Error.t)];
       return ()
     | Ok handle ->
       (match Bot_registry.add registry handle with
        | Ok () ->
          print_endline [%string "spawned %{participant#Participant}"];
          return ()
        | Error error ->
          (* Unreachable from a single console (we checked [mem] above), but
             if it ever races, don't leak a live unkillable bot. *)
          print_s [%sexp (error : Error.t)];
          let%map (_ : int Or_error.t) = Bot_handle.kill handle in
          ()))
;;

let list_bots registry ~directory =
  match Bot_registry.all registry with
  | [] -> print_endline "(no bots running)"
  | handles ->
    let now = Time_ns.now () in
    List.iter handles ~f:(fun (handle : Bot_handle.t) ->
      let symbols =
        List.map handle.symbols ~f:(Symbol_directory.name_or_id directory)
        |> String.concat ~sep:" "
      in
      let uptime =
        Time_ns.Span.to_short_string (Time_ns.diff now handle.started_at)
      in
      print_endline
        [%string
          "%{handle.participant#Participant}  [%{handle.kind}]  %{symbols} \
           up %{uptime}"])
;;

let take_down registry name ~mode =
  let participant = Participant.of_string name in
  match Bot_registry.remove registry participant with
  | None ->
    print_endline [%string "no bot named %{name} (see `list`)"];
    return ()
  | Some handle ->
    (match mode with
     | `Crash ->
       let%map () = Bot_handle.crash handle in
       print_endline
         [%string
           "crashed %{name} (its resting orders are still on the book)"]
     | `Kill ->
       (match%map Bot_handle.kill handle with
        | Ok count ->
          print_endline
            [%string "killed %{name} (cancelled %{count#Int} orders)"]
        | Error error ->
          print_endline [%string "killed %{name}, but cancel-all failed:"];
          print_s [%sexp (error : Error.t)]))
;;

let quit_all registry ~shutdown =
  let%bind () =
    Deferred.List.iter
      ~how:`Sequential
      (Bot_registry.all registry)
      ~f:(fun (handle : Bot_handle.t) ->
        take_down
          registry
          (Participant.to_string handle.participant)
          ~mode:`Kill)
  in
  print_endline "shutting down.";
  shutdown ()
;;

let start ~registry ~menu ~directory ~spawn ~shutdown =
  (* Console-spawned bots get seeds well away from the scenarios' hand-picked
     ones, ticking up per spawn so two spawned noise traders never mirror
     each other. *)
  let rng_seed =
    let counter = ref 9000 in
    fun () ->
      incr counter;
      !counter
  in
  print_endline
    "interactive console ready — `help` for commands, `kinds` for bots.";
  let rec loop () =
    print_string "> ";
    match%bind Reader.read_line (Lazy.force Reader.stdin) with
    | `Eof ->
      print_endline "\n(console detached; exchange still running)";
      return ()
    | `Ok line ->
      if String.is_empty (String.strip line)
      then loop ()
      else (
        match Console_command.parse ~directory line with
        | Error error ->
          print_s [%sexp (error : Error.t)];
          loop ()
        | Ok (Spawn { kind; name; symbols; knobs }) ->
          let%bind () =
            do_spawn
              ~registry
              ~menu
              ~directory
              ~spawn
              ~rng_seed:(rng_seed ())
              ~kind
              ~name
              ~symbols
              ~knobs
          in
          loop ()
        | Ok (Kill name) ->
          let%bind () = take_down registry name ~mode:`Kill in
          loop ()
        | Ok (Crash name) ->
          let%bind () = take_down registry name ~mode:`Crash in
          loop ()
        | Ok List_bots ->
          list_bots registry ~directory;
          loop ()
        | Ok Kinds ->
          print_endline (kinds_text menu);
          loop ()
        | Ok Help ->
          print_endline help_text;
          loop ()
        | Ok Quit -> quit_all registry ~shutdown)
  in
  loop ()
;;
