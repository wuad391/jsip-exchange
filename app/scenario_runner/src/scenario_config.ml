open! Core
open Jsip_symbol_directory

type t =
  { name : string
  ; directory : Symbol_directory.t
      (* Name<->id map for this scenario's symbols. The exchange is booted on
         it, and it lets a scenario resolve its declared names to the wire
         ids the oracle/bots below are keyed on. *)
  ; oracle_config : Jsip_fundamental.Fundamental_oracle.Config.t
  ; news : Jsip_news_injector.News_injector.Event.t list
  ; bots : Bot_spec.t list
  }
