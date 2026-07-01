(** Per-participant, per-symbol profit-and-loss (P&L) tracking.

    A [t] accumulates, for every {!Jsip_types.Participant.t} trading a
    {!Jsip_types.Symbol.t}, three running quantities:

    - {b inventory}: the signed share position (positive = long, negative =
      short);
    - {b cost basis}: the total cost of the currently-open position, from
      which the average entry price is derived;
    - {b realized P&L}: cash locked in by closing (fully or partially) a
      position, under average-cost accounting.

    Feeding the exchange event stream through {!apply_fill} and
    {!apply_trade_report} maintains a live P&L that {!summary} reports per
    symbol and in total. A single {!Jsip_types.Fill.t} touches {b both} of
    its participants (aggressor and resting), so [apply_fill] updates the two
    of them. [apply_trade_report] refreshes the reference (mark) price used
    to value still-open positions.

    {2 P&L conventions}

    Realized P&L is measured against the average entry price of the shares
    being closed. Unrealized P&L marks the open position to the most recent
    trade print:
    {[
      unrealized = inventory * (reference_price - average_entry_price)
    ]}
    Every monetary value is an integer number of cents, matching
    {!Jsip_types.Price}.

    {2 Example}
    {[
      let pnl =
        Pnl.empty
        |> Fn.flip Pnl.apply_fill alice_buys_100_at_150
        |> Fn.flip Pnl.apply_fill alice_sells_100_at_155
        |> Fn.flip Pnl.apply_trade_report (Trade_report { ... })
      in
      print_string (Pnl.Summary.to_string_hum (Pnl.summary pnl alice))
    ]} *)

open! Core
open Jsip_types

(** A snapshot of every participant's positions plus the latest reference
    prices. Immutable — the [apply_*] functions return an updated copy. *)
type t

(** P&L with no positions and no reference prices. *)
val empty : t

(** Apply an execution to {b both} participants named in [fill] (the
    aggressor on [aggressor_side], the resting order on the flipped side).
    Growing a position rolls the fill into its average entry price; reducing
    or flipping it realizes P&L on the shares that close. *)
val apply_fill : t -> Fill.t -> t

(** Refresh the reference price used to mark open positions. Only
    {!Jsip_types.Exchange_event.Trade_report} events carry a public price;
    every other event leaves [t] unchanged. *)
val apply_trade_report : t -> Exchange_event.t -> t

(** A participant's P&L report: one {!Summary.Per_symbol.t} per symbol they
    have traded, plus totals across symbols. *)
module Summary : sig
  (** One symbol's line in a {!t}. *)
  module Per_symbol : sig
    type t =
      { symbol : Symbol.t
      ; inventory : int
      (** Signed share position: positive long, negative short, zero flat. *)
      ; average_entry_price : Price.t option
      (** Average price of the open position; [None] when flat. *)
      ; reference_price : Price.t option
      (** Latest trade print for [symbol]; [None] until one arrives. *)
      ; realized_cents : int (** Cash from positions closed so far. *)
      ; unrealized_cents : int (** Mark-to-market of the open position. *)
      }
    [@@deriving sexp_of]
  end

  type t =
    { per_symbol : Per_symbol.t list
    ; realized_cents : int (** Sum of the per-symbol realized P&L. *)
    ; unrealized_cents : int (** Sum of the per-symbol unrealized P&L. *)
    ; total_cents : int (** [realized_cents + unrealized_cents]. *)
    }
  [@@deriving sexp_of]

  (** A compact one-line-per-symbol dollar rendering with a trailing [TOTAL]
      row. Convenient in expect tests and monitors. *)
  val to_string_hum : t -> string
end

(** [summary t participant] reports [participant]'s P&L. A symbol whose
    position is now flat still appears when it carries realized P&L. *)
val summary : t -> Participant.t -> Summary.t
