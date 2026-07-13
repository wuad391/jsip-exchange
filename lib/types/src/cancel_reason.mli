(** Why an order was cancelled.

    A production exchange would have more granular cancellation reasons --
    risk limit breaches, trading halts, self-trade prevention, etc. *)

open! Core

type t =
  | Participant_requested
  (** The participant explicitly asked to cancel their order. *)
  | Ioc_remainder
  (** The unfilled portion of an IOC order was automatically cancelled. *)
  | End_of_day (** Day orders are cancelled when the trading session ends. *)
  | Mass_cancel
  (** Swept up by a cancel-all: every resting order the participant had was
      cancelled in one request — e.g. an interactive bot being killed. *)
[@@deriving sexp, bin_io, compare, equal, hash, string]
