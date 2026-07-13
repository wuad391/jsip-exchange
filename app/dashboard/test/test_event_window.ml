open! Core
open Jsip_types
open Jsip_dashboard

(* [Event_window] is the diffable feed poll response: a diff carries only the
   entries newer than the client already holds (by monotonic id), and
   [update] must reconstruct the server's buffer exactly. These pin that
   round-trip — both while the buffer is still filling and once it is full
   and slides, dropping the oldest. The event payload is irrelevant to the
   diffing, so we tag one fixed event with a sequence of ids. *)

let event : Exchange_event.t =
  Trade_report
    { symbol = Symbol_id.of_int 0
    ; price = Price.of_int_cents 15000
    ; size = Size.of_int 1
    }
;;

let buffer ids = List.map ids ~f:(fun id -> id, event)
let ids buffer = List.map buffer ~f:fst

let%expect_test "still filling: diff is the new entries, update appends them"
  =
  let from = buffer [ 3; 4; 5 ] in
  let to_ = buffer [ 3; 4; 5; 6; 7 ] in
  let diff = Event_window.diffs ~from ~to_ in
  print_s [%sexp (ids diff : int list)];
  [%expect {| (6 7) |}];
  print_s [%sexp (ids (Event_window.update from diff) : int list)];
  [%expect {| (3 4 5 6 7) |}]
;;

let%expect_test "full buffer slides: update drops the oldest to match to_" =
  (* A full 200-buffer that advanced by two events: ids 1,2 age out, 201,202
     arrive. The diff still carries only 201,202; [update] re-caps to 200. *)
  let from = buffer (List.range 1 201) in
  let to_ = buffer (List.range 3 203) in
  let diff = Event_window.diffs ~from ~to_ in
  print_s [%message "" ~appended:(ids diff : int list)];
  [%expect {| (appended (201 202)) |}];
  let reconstructed = ids (Event_window.update from diff) in
  print_s
    [%message
      ""
        ~count:(List.length reconstructed : int)
        ~first:(List.hd_exn reconstructed : int)
        ~last:(List.last_exn reconstructed : int)];
  [%expect {| ((count 200) (first 3) (last 202)) |}]
;;

let%expect_test "admitting one event at a time caps at max_events" =
  (* The server admits events via [update buffer [ id, event ]]. Feed 250 and
     confirm only the last 200 ids remain. *)
  let final =
    List.fold (List.range 1 251) ~init:[] ~f:(fun buffer id ->
      Event_window.update buffer [ id, event ])
  in
  let seqs = ids final in
  print_s
    [%message
      ""
        ~count:(List.length seqs : int)
        ~first:(List.hd_exn seqs : int)
        ~last:(List.last_exn seqs : int)];
  [%expect {| ((count 200) (first 51) (last 250)) |}]
;;
