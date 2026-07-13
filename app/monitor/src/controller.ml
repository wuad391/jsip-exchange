open! Core
open Jsip_types
open Jsip_gateway
open Jsip_pnl

module Mode = struct
  type t =
    | Browsing
    | Editing_substring of { buffer : string }
  [@@deriving sexp_of, compare, equal]
end

module Chip = struct
  type t =
    { hotkey : char
    ; label : string
    ; enabled : bool
    }
  [@@deriving sexp_of, compare, equal]
end

module Display = struct
  type substring_field =
    { value : string
    ; editing : bool
    }
  [@@deriving sexp_of, compare, equal]

  module Participant_pnl = struct
    type t =
      { participant : string
      ; total_cents : int
      }
    [@@deriving sexp_of, compare, equal]
  end

  type t =
    { title : string
    ; counter : string
    ; bbo_panel : (string * Bbo.t) list
        (* Each symbol already rendered to its display label (name if the
           directory knows the id, else the raw id) so the view needs no
           directory of its own. *)
    ; participant_pnl : Participant_pnl.t list
        (* Net P&L per participant, biggest winner first (ties by name). *)
    ; category_chips : Chip.t list
    ; substring_field : substring_field
    ; visible_events : (Event_log.Color.t * string) list
    ; mode_indicator : string
    ; footer : string
    }
  [@@deriving sexp_of, compare, equal]
end

type t =
  { log : Event_log.t
  ; enabled_categories : Event_log.Category.t list
  ; committed_substring : string
  ; mode : Mode.t
  ; should_exit : bool
  ; directory : Symbol_directory.t
  ; pnl : Pnl.t
  ; traded : Participant.Set.t
  (* [Pnl.t] can summarize a given participant but does not enumerate the
     ones it knows, so we track the set seen in a fill ourselves — that is
     exactly who the P&L panel lists. *)
  }

let create ?(directory = Symbol_directory.empty) () =
  { log = Event_log.create ~directory ()
  ; enabled_categories = Event_log.Category.all
  ; committed_substring = ""
  ; mode = Browsing
  ; should_exit = false
  ; directory
  ; pnl = Pnl.empty
  ; traded = Participant.Set.empty
  }
;;

(* Fold the same audit stream the event log shows into live P&L. A [Fill]
   carries both sides, so it updates two participants and marks them both as
   seen; a [Trade_report] only refreshes the mark price used to value open
   positions; every other event leaves P&L untouched. *)
let feed_event t event =
  let log = Event_log.add_event t.log event in
  let pnl, traded =
    match (event : Exchange_event.t) with
    | Fill ({ aggressor_participant; resting_participant; _ } as fill) ->
      ( Pnl.apply_fill t.pnl fill
      , Set.add (Set.add t.traded aggressor_participant) resting_participant
      )
    | Trade_report _ -> Pnl.apply_trade_report t.pnl event, t.traded
    | Order_accept _ | Order_cancel _ | Order_reject _ | Cancel_reject _
    | Best_bid_offer_update _ ->
      t.pnl, t.traded
  in
  { t with log; pnl; traded }
;;

let should_exit t = t.should_exit

let is_editing_substring t =
  match t.mode with Editing_substring _ -> true | Browsing -> false
;;

(* Toggle [elt] in [list], preserving the canonical order in [all]. *)
let toggle_in_list ~equal ~all elt list =
  if List.mem list elt ~equal
  then List.filter list ~f:(fun x -> not (equal x elt))
  else List.filter all ~f:(fun x -> List.mem list x ~equal || equal x elt)
;;

let toggle_category t cat =
  let enabled_categories =
    toggle_in_list
      ~equal:Event_log.Category.equal
      ~all:Event_log.Category.all
      cat
      t.enabled_categories
  in
  { t with enabled_categories }
;;

let reset_filters t =
  { t with
    enabled_categories = Event_log.Category.all
  ; committed_substring = ""
  }
;;

let handle_browsing_char t = function
  | 'q' -> { t with should_exit = true }
  | 'r' -> reset_filters t
  | '/' -> { t with mode = Editing_substring { buffer = "" } }
  | '1' -> toggle_category t Order_lifecycle
  | '2' -> toggle_category t Trade
  | '3' -> toggle_category t Market_data
  | '4' -> toggle_category t Session
  | _ -> t
;;

let handle_editing_key t buffer (key : Bonsai_term.Event.Key.t) =
  match key with
  | Enter -> { t with mode = Browsing; committed_substring = buffer }
  | Escape -> { t with mode = Browsing }
  | Backspace ->
    let buffer = String.drop_suffix buffer 1 in
    { t with mode = Editing_substring { buffer } }
  | ASCII ch when Char.is_print ch ->
    let buffer = buffer ^ String.make 1 ch in
    { t with mode = Editing_substring { buffer } }
  | _ -> t
;;

let handle_key t (key : Bonsai_term.Event.Key.t) =
  match t.mode with
  | Editing_substring { buffer } -> handle_editing_key t buffer key
  | Browsing ->
    (match key with ASCII ch -> handle_browsing_char t ch | _ -> t)
;;

(* Build the effective [Event_log.Filter.t] from the controller's UI state.
   Filters that are at their defaults (all chips enabled, no substring) are
   omitted entirely so they don't masquerade as restrictive constraints. *)
let compile_filter t =
  let filter = Event_log.Filter.all in
  let filter =
    if List.equal
         Event_log.Category.equal
         t.enabled_categories
         Event_log.Category.all
    then filter
    else
      Event_log.Filter.combine
        filter
        (Event_log.Filter.by_categories t.enabled_categories)
  in
  let effective_substring =
    match t.mode with
    | Editing_substring { buffer } -> buffer
    | Browsing -> t.committed_substring
  in
  if String.is_empty effective_substring
  then filter
  else
    Event_log.Filter.combine
      filter
      (Event_log.Filter.by_substring effective_substring)
;;

let display t : Display.t =
  let filter = compile_filter t in
  let filtered_log = Event_log.set_filter t.log filter in
  let visible_events = Event_log.visible_styled_lines filtered_log in
  let total = Event_log.event_count t.log in
  let visible_count = List.length visible_events in
  let cat_chip hotkey cat : Chip.t =
    { hotkey
    ; label = Event_log.Category.to_string cat
    ; enabled =
        List.mem t.enabled_categories cat ~equal:Event_log.Category.equal
    }
  in
  let substring_field : Display.substring_field =
    match t.mode with
    | Browsing -> { value = t.committed_substring; editing = false }
    | Editing_substring { buffer } -> { value = buffer; editing = true }
  in
  let mode_indicator =
    match t.mode with
    | Browsing -> ""
    | Editing_substring _ -> "[editing substring]"
  in
  let footer =
    match t.mode with
    | Browsing -> "q=quit  r=reset  1-4=categories  /=substring"
    | Editing_substring _ ->
      "Enter=commit  ESC=cancel  Backspace=delete  (other keys append)"
  in
  let participant_pnl =
    Set.to_list t.traded
    |> List.map ~f:(fun participant ->
      let summary : Pnl.Summary.t = Pnl.summary t.pnl participant in
      { Display.Participant_pnl.participant =
          Participant.to_string participant
      ; total_cents = summary.total_cents
      })
    |> List.sort ~compare:(fun (a : Display.Participant_pnl.t) b ->
      match Int.descending a.total_cents b.total_cents with
      | 0 -> String.compare a.participant b.participant
      | c -> c)
  in
  { title = "JSIP Exchange Monitor"
  ; counter = [%string "%{visible_count#Int} of %{total#Int} events"]
  ; bbo_panel =
      List.map (Event_log.current_bbos t.log) ~f:(fun (id, bbo) ->
        Symbol_directory.name_or_id t.directory id, bbo)
  ; participant_pnl
  ; category_chips =
      [ cat_chip '1' Order_lifecycle
      ; cat_chip '2' Trade
      ; cat_chip '3' Market_data
      ; cat_chip '4' Session
      ]
  ; substring_field
  ; visible_events
  ; mode_indicator
  ; footer
  }
;;
