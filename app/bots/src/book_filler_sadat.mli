(** A pathological bot that floods the book with resting orders it never
    intends to trade: each tick it posts [orders_per_tick] non-marketable
    [Day] orders (buys far below fair value, sells far above), so the book
    grows without bound and everything that walks it — the matching engine,
    the book snapshot — gets slower. Reads no market data, reacts to no
    events. *)

open! Core
open Jsip_types

module Config : sig
  type t =
    { symbols : Symbol.t list
    (** Books to flood, round-robined across. Must be non-empty. *)
    ; orders_per_tick : int
    (** Resting orders added per tick — the primary intensity knob. Positive. *)
    ; order_size : int (** Shares per order (the orders never trade). *)
    ; price_offset_cents : int
    (** Min cents from fair value, kept large enough to stay non-marketable. *)
    ; level_spacing_cents : int
    (** Cents between successive orders; [0] stacks them all on one level. *)
    ; next_client_order_id : int ref
    (** Mutable fresh-id counter (ids can't repeat). Initialize to [0]. *)
    }
  [@@deriving sexp_of]
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
