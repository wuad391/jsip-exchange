open! Core
open Jsip_exchange_stats

let max_window = 60

module Gc_rate = struct
  type t =
    { minor_per_sec : int
    ; major_per_sec : int
    }
  [@@deriving sexp, equal]

  let zero = { minor_per_sec = 0; major_per_sec = 0 }
end

(* Snapshots are held newest-first so [add] is a cheap prepend + truncate.
   The public [snapshots] reverses to oldest-first, the order charts want. *)
type t = { newest_first : Exchange_stats.t list }

let empty = { newest_first = [] }

let add t snapshot =
  { newest_first = List.take (snapshot :: t.newest_first) max_window }
;;

let snapshots t = List.rev t.newest_first
let latest t = List.hd t.newest_first

(* Cumulative counters differenced across the last second give a rate,
   because snapshots arrive once per second. *)
let minor_collections (s : Exchange_stats.t) = s.gc.minor_collections
let major_collections (s : Exchange_stats.t) = s.gc.major_collections

let gc_rate t =
  match t.newest_first with
  | current :: previous :: _ ->
    { Gc_rate.minor_per_sec =
        minor_collections current - minor_collections previous
    ; major_per_sec = major_collections current - major_collections previous
    }
  | [] | [ _ ] -> Gc_rate.zero
;;

let of_snapshots snapshots = List.fold snapshots ~init:empty ~f:add

(* Bytes per OCaml word on the 64-bit runtime; [Gc.Stat] counts are in words,
   which we render as megabytes. *)
let bytes_per_word = 8
let mb_of_words words = Float.of_int (words * bytes_per_word) /. 1_000_000.

(* Field accessors, annotated so the record type is unambiguous — the same
   pattern as [minor_collections] above. *)
let live_words (s : Exchange_stats.t) = s.gc.live_words
let heap_words (s : Exchange_stats.t) = s.gc.heap_words
let top_heap_words (s : Exchange_stats.t) = s.gc.top_heap_words
let submit_latency (s : Exchange_stats.t) = s.submit_latency
let cancel_latency (s : Exchange_stats.t) = s.cancel_latency
let audit_pipe (s : Exchange_stats.t) = s.audit_pipe
let market_data_pipe (s : Exchange_stats.t) = s.market_data_pipe
let session_pipe (s : Exchange_stats.t) = s.session_pipe
let loop_busy_us (s : Exchange_stats.t) = s.matching_loop_busy_us
let p50 (l : Exchange_stats.Latency_summary.t) = l.p50_us
let p90 (l : Exchange_stats.Latency_summary.t) = l.p90_us
let p99 (l : Exchange_stats.Latency_summary.t) = l.p99_us
let latency_max (l : Exchange_stats.Latency_summary.t) = l.max_us
let latency_count (l : Exchange_stats.Latency_summary.t) = l.count
let pipe_max (g : Exchange_stats.Pipe_group.t) = g.max_depth
let pipe_total (g : Exchange_stats.Pipe_group.t) = g.total_depth
let pipe_num (g : Exchange_stats.Pipe_group.t) = g.num_pipes

module Display = struct
  (* One RPC class's latency, projected for a pane: a line per percentile over
     the window (oldest first) plus the current second's readouts and
     throughput ([per_sec] = requests handled that second). *)
  type latency =
    { p50_series : float list
    ; p90_series : float list
    ; p99_series : float list
    ; max_series : float list
    ; p50_us : float
    ; p90_us : float
    ; p99_us : float
    ; max_us : float
    ; per_sec : int
    }
  [@@deriving sexp_of, equal]

  type participant_row =
    { name : string
    ; orders_per_sec : int
    ; resting_orders : int
    }
  [@@deriving sexp_of, equal]

  type occupancy_row =
    { label : string
    ; max_depth : int
    ; total_depth : int
    ; num_pipes : int
    ; max_depth_series : float list
    }
  [@@deriving sexp_of, equal]

  (* One symbol's top of book, formatted for display: best bid/ask as dollar
     strings with their sizes, and the spread. Each side is [None] when that
     side of the book is empty. The only pane showing market state rather than
     process health. *)
  type book_row =
    { symbol : string
    ; bid : string option
    ; bid_size : int option
    ; ask : string option
    ; ask_size : int option
    ; spread : string option
    }
  [@@deriving sexp_of, equal]

  type t =
    { seq : int
    ; live_mb_series : float list
    ; heap_mb_series : float list
    ; live_mb : float
    ; heap_mb : float
    ; peak_mb : float
    ; gc_minor_per_sec : int
    ; gc_major_per_sec : int
    ; submit : latency
    ; cancel : latency
    ; participants : participant_row list
    ; occupancy : occupancy_row list
    ; loop_busy_series : float list
    ; loop_busy_us : float
    ; books : book_row list
    }
  [@@deriving sexp_of, equal]
end

let latency_display window ~get : Display.latency =
  let vals = List.map window ~f:get in
  let series f = List.map vals ~f in
  let current = List.last vals in
  let cur f = Option.value_map current ~default:0. ~f in
  { Display.p50_series = series p50
  ; p90_series = series p90
  ; p99_series = series p99
  ; max_series = series latency_max
  ; p50_us = cur p50
  ; p90_us = cur p90
  ; p99_us = cur p99
  ; max_us = cur latency_max
  ; per_sec = Option.value_map current ~default:0 ~f:latency_count
  }
;;

let occupancy_display window ~label ~get : Display.occupancy_row =
  let groups = List.map window ~f:get in
  let current = List.last groups in
  let cur f = Option.value_map current ~default:0 ~f in
  { Display.label
  ; max_depth = cur pipe_max
  ; total_depth = cur pipe_total
  ; num_pipes = cur pipe_num
  ; max_depth_series =
      List.map groups ~f:(fun g -> Float.of_int (pipe_max g))
  }
;;

let participants_display window : Display.participant_row list =
  match List.last window with
  | None -> []
  | Some (current : Exchange_stats.t) ->
    current.per_participant
    |> List.map ~f:(fun (p : Exchange_stats.Participant_stats.t) ->
      { Display.name = Jsip_types.Participant.to_string p.participant
      ; orders_per_sec = p.orders_per_sec
      ; resting_orders = p.resting_orders
      })
    (* Busiest sender first (the flooding bot rises to the top); ties broken by
       name so the ordering is stable. *)
    |> List.sort ~compare:(fun a b ->
      match Int.compare b.Display.orders_per_sec a.Display.orders_per_sec with
      | 0 -> String.compare a.Display.name b.Display.name
      | c -> c)
;;

(* Market state from the newest snapshot: each traded symbol's best bid/ask as
   dollar strings with sizes, and the spread. Empty sides stay [None]. *)
let books_display window : Display.book_row list =
  match List.last window with
  | None -> []
  | Some (current : Exchange_stats.t) ->
    List.map current.top_of_book ~f:(fun (b : Exchange_stats.Top_of_book.t) ->
      let bbo : Jsip_types.Bbo.t = b.bbo in
      let price (level : Jsip_types.Level.t option) =
        Option.map level ~f:(fun l ->
          Jsip_types.Price.to_string_dollar l.price)
      in
      let size (level : Jsip_types.Level.t option) =
        Option.map level ~f:(fun l -> Jsip_types.Size.to_int l.size)
      in
      { Display.symbol = Jsip_types.Symbol.to_string b.symbol
      ; bid = price bbo.bid
      ; bid_size = size bbo.bid
      ; ask = price bbo.ask
      ; ask_size = size bbo.ask
      ; spread =
          Jsip_types.Bbo.spread bbo
          |> Option.map ~f:Jsip_types.Price.to_string_dollar
      })
;;

let display t : Display.t =
  let window = snapshots t in
  let current = latest t in
  let gc = gc_rate t in
  let cur_words f = mb_of_words (Option.value_map current ~default:0 ~f) in
  { Display.seq =
      Option.value_map current ~default:0 ~f:(fun (s : Exchange_stats.t) ->
        s.seq)
  ; live_mb_series = List.map window ~f:(fun s -> mb_of_words (live_words s))
  ; heap_mb_series = List.map window ~f:(fun s -> mb_of_words (heap_words s))
  ; live_mb = cur_words live_words
  ; heap_mb = cur_words heap_words
  ; peak_mb = cur_words top_heap_words
  ; gc_minor_per_sec = gc.minor_per_sec
  ; gc_major_per_sec = gc.major_per_sec
  ; submit = latency_display window ~get:submit_latency
  ; cancel = latency_display window ~get:cancel_latency
  ; participants = participants_display window
  ; occupancy =
      [ occupancy_display window ~label:"audit" ~get:audit_pipe
      ; occupancy_display window ~label:"market data" ~get:market_data_pipe
      ; occupancy_display window ~label:"session" ~get:session_pipe
      ]
  ; loop_busy_series = List.map window ~f:loop_busy_us
  ; loop_busy_us = Option.value_map current ~default:0. ~f:loop_busy_us
  ; books = books_display window
  }
;;
