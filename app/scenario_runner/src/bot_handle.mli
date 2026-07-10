(** A live, killable bot: everything {!Runner.start_bot} wires up for one
    {!Bot_spec.t}, retained so the interactive console can tear the bot down
    again mid-run (rather than leaking it into [don't_wait_for] with no way
    back, as the runner originally did).

    Teardown ordering is the point of this module. Both {!kill} and {!crash}
    first quiesce the strategy — stop its tick loop and sever its event feed,
    so it cannot re-quote in reaction to its own teardown — and only then
    touch the exchange. They differ in what the book is left holding: [kill]
    flattens the bot (cancel-all) before disconnecting; [crash] disconnects
    with its resting orders deliberately left behind, ghost quotes and all —
    the failure mode a real exchange's cancel-on-disconnect feature exists to
    prevent. *)

open! Core
open! Async
open Jsip_types

type t =
  { participant : Participant.t (** Identity the bot logged in with. *)
  ; kind : string (** Strategy label, e.g. ["Market Maker"]. *)
  ; symbols : Symbol_id.t list (** Symbols from the bot's spec. *)
  ; connection : Rpc.Connection.t (** The bot's own RPC connection. *)
  ; runtime : Jsip_bot_runtime.Bot_runtime.t
  ; tick_loop : unit Deferred.t
  (** [Bot_runtime.start]'s deferred; determined only after a stop. *)
  ; feed : Exchange_event.t Pipe.Reader.t
  (** Interleaved session + market-data events feeding [on_event]. *)
  ; feed_pump : unit Deferred.t
  (** The [Pipe.iter] draining [feed] into the bot; determined once [feed] is
      closed. *)
  ; started_at : Time_ns.t (** When the bot came up, for [list] uptime. *)
  }

(** Stop the bot and flatten it: stop ticks, await the loop, close [feed] and
    await the pump, cancel every resting order via the cancel-all RPC on the
    bot's own connection, then close the connection and await
    [close_finished] (so the server has observed the disconnect before this
    returns). Returns the number of orders cancelled. If the cancel-all
    dispatch fails, the connection is still closed and the error returned — a
    broken bot must not linger half-dead. *)
val kill : t -> int Deferred.Or_error.t

(** Like {!kill} but WITHOUT the cancel-all: the bot's resting orders are
    deliberately left on the book as ghosts, exactly as if its process had
    died mid-run. *)
val crash : t -> unit Deferred.t
