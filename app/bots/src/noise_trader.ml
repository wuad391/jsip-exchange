(* CR claude for robyn: this whole module (and its .mli) is committed as one big
   commented-out WIP blob ("LEFT OFF HERE TODO"). A comment-only .ml compiles to
   an empty module, so it just adds noise. Either finish it, make it a real stub
   in the house style ([let on_tick _ _ = failwith "TODO: implement
   Noise_trader.on_tick"]), or drop the files until you start Ex4. *)
(* open! Core open! Async open Jsip_types open Jsip_gateway open
   Jsip_bot_runtime module Context = Bot_runtime.Context

   module Config = struct type t =
   [{ symbol_state : Bbo.t Symbol.Table.t ; avg_size : int ; tick_chance : float ; aggressiveness_pct : int ; ioc_pct : int }]
   [@@deriving sexp_of] end

   let name = "Noise trader"

   (* ...................Internal helper function
   start........................ *)

   (* ....................................................... *)

   (* This function dummy sets fair value for ecah symbol at 0 bc on_start
   will be called to make it nice and pretty yay *) let create_config = ()
   let on_start _config _context = return ()

   let pick_random_from_list rng list = let rnd_int = Splittable_random.int
   rng ~lo:0 ~hi:(List.length list - 1) in List.nth list rnd_int ;;

   let on_tick (config : Config.t) (context : Context.t) = return ()

   let _ = let rng = Context.random context in let should_trade = Float.( <=
   ) (Splittable_random.float rng ~lo:0.0 ~hi:1.0) config.tick_chance in if
   not should_trade then return () else ( let symbol_list = Hashtbl.keys
   config.symbol_state in let random_symbol = pick_random_from_list rng
   symbol_list in let random_side = if Splittable_random.bool rng then
   Side.Buy else Sell in let random_size = Splittable_random.int rng
   ~lo:(config.avg_size - 100) ~hi:(config.avg_size + 100) in let
   is_aggressive = Splittable_random.int rng in let random_price = 1 in (*
   LEFT OFF HERE TODO *) let random_ioc = if Splittable_random.bool rng then
   Time_in_force.Ioc else Day in return ()) ;;

   let on_event config context event = return () *)
