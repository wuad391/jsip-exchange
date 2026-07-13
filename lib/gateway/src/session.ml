open! Core
open! Async
open Jsip_types

type t =
  { participant : Participant.t
  ; reader : Exchange_event.t Pipe.Reader.t
  ; writer : Exchange_event.t Pipe.Writer.t
  ; limit : Bounded_pipe.Limit.t
  }

let create participant ~limit =
  let reader, writer = Pipe.create () in
  { participant; reader; writer; limit }
;;

let participant t = t.participant
let reader t = t.reader
let push t event = Bounded_pipe.push t.writer ~limit:t.limit event
let close t = Pipe.close t.writer
let is_closed t = Pipe.is_closed t.writer
let queue_length t = Pipe.length t.writer
