open! Core
open Jsip_types

module Config = struct
  type t =
    { num_symbols : int
    ; num_participants : int
    ; cancel_fraction : float
    ; marketable_fraction : float
    ; ioc_fraction : float
    ; min_size : int
    ; max_size : int
    ; reference_price_cents : int
    ; drift_cents : int
    ; resting_offset_cents : int
    ; cancel_pool_size : int
    }
  [@@deriving sexp_of]

  let balanced =
    { num_symbols = 16
    ; num_participants = 8
    ; cancel_fraction = 0.45
    ; marketable_fraction = 0.35
    ; ioc_fraction = 0.5
    ; min_size = 1
    ; max_size = 10
    ; reference_price_cents = 10_000
    ; drift_cents = 2
    ; resting_offset_cents = 5
    ; cancel_pool_size = 4096
    }
  ;;

  let churn =
    { balanced with cancel_fraction = 0.70; marketable_fraction = 0.20 }
  ;;

  let book_heavy =
    { balanced with
      cancel_fraction = 0.15
    ; marketable_fraction = 0.15
    ; ioc_fraction = 0.30
    ; drift_cents = 1
    ; cancel_pool_size = 8192
    }
  ;;

  let all =
    [ "balanced", balanced; "churn", churn; "book-heavy", book_heavy ]
  ;;
end

type action =
  | Submit of Order.Request.t
  | Cancel of Order.Cancel.t
[@@deriving sexp_of]

type t =
  { config : Config.t
  ; rng : Splittable_random.t
  ; participants : Participant.t array
  ; generators : Client_order_id.Generator.t array
  ; mids : float array
      (* per-symbol fair value in cents, indexed by symbol id *)
      (* The cancel pool is a fixed-capacity ring over two parallel arrays: a
         new resting submit overwrites the oldest slot, and a cancel draws a
         uniformly random occupied slot. Preallocated so pushing never
         allocates. *)
  ; pool_participant : Participant.t array
  ; pool_cid : Client_order_id.t array
  ; mutable pool_len : int
  ; mutable pool_next : int
  }

let config t = t.config

let create ~(config : Config.t) ~seed =
  let rng = Splittable_random.of_int seed in
  let participants =
    Array.init config.num_participants ~f:(fun i ->
      Participant.of_string [%string "participant-%{i#Int}"])
  in
  let generators =
    Array.init config.num_participants ~f:(fun _ ->
      Client_order_id.Generator.create ())
  in
  { config
  ; rng
  ; participants
  ; generators
  ; mids =
      Array.create
        ~len:config.num_symbols
        (Float.of_int config.reference_price_cents)
  ; pool_participant =
      Array.create ~len:config.cancel_pool_size participants.(0)
  ; pool_cid =
      Array.create ~len:config.cancel_pool_size (Client_order_id.of_int 1)
  ; pool_len = 0
  ; pool_next = 0
  }
;;

let chance t probability =
  Float.( < ) (Splittable_random.float t.rng ~lo:0. ~hi:1.) probability
;;

let uniform_int t ~lo ~hi = Splittable_random.int t.rng ~lo ~hi

let push_pool t ~participant ~client_order_id =
  let slot = t.pool_next in
  t.pool_participant.(slot) <- participant;
  t.pool_cid.(slot) <- client_order_id;
  t.pool_next <- (t.pool_next + 1) % t.config.cancel_pool_size;
  if t.pool_len < t.config.cancel_pool_size then t.pool_len <- t.pool_len + 1
;;

(* Random-walk the chosen symbol's fair value by up to +/- [drift_cents],
   clamped so it stays high enough that a resting order priced
   [resting_offset_cents] below it is still a positive price. *)
let advance_mid t ~symbol_idx =
  let drift = t.config.drift_cents in
  if drift > 0
  then (
    let step = uniform_int t ~lo:(-drift) ~hi:drift in
    let floor_cents = Float.of_int (t.config.resting_offset_cents + 1) in
    t.mids.(symbol_idx)
    <- Float.max floor_cents (t.mids.(symbol_idx) +. Float.of_int step))
;;

(* choose_price: translate a symbol's current fair value —
   [t.mids.(symbol_idx)], in cents — into an actual limit [Price.t] for an
   order on [side].

   The constraint that makes or breaks a preset:

   - A *resting* order (not [marketable]) should sit BEHIND the fair value so
     it adds depth without trading: a resting buy below the mid, a resting
     sell above it, by about [t.config.resting_offset_cents].
   - A *marketable* order must be priced to CROSS the resting orders on the
     opposite side — i.e. reach at least to where that side is resting (mid
     +/- the offset). If marketable buys don't reach the resting asks,
     nothing trades, the book only grows, and "balanced" silently degrades
     into "book-heavy" — the driver's realized-fill-rate check exists to
     catch exactly this.

   Return a [Price.t] via [Price.of_int_cents]; keep it >= 1 cent. This
   function should be deterministic from the mid (it needs no RNG). *)
let choose_price t ~symbol_idx ~(side : Side.t) ~marketable : Price.t =
  let mid = Int.of_float t.mids.(symbol_idx) in
  let offset = t.config.resting_offset_cents in
  let cents =
    match side, marketable with
    | Buy, false -> mid - offset
    | Sell, false -> mid + offset
    | Buy, true -> mid + offset
    | Sell, true -> mid - offset
  in
  Price.of_int_cents (Int.max 1 cents)
;;

let next_action t =
  (* Cancel only when there's something to cancel; otherwise submit. *)
  if t.pool_len > 0 && chance t t.config.cancel_fraction
  then (
    let slot = uniform_int t ~lo:0 ~hi:(t.pool_len - 1) in
    let cancel : Order.Cancel.t =
      { participant = t.pool_participant.(slot)
      ; client_order_id = t.pool_cid.(slot)
      }
    in
    Cancel cancel)
  else (
    let participant_idx =
      uniform_int t ~lo:0 ~hi:(t.config.num_participants - 1)
    in
    let participant = t.participants.(participant_idx) in
    let client_order_id =
      Client_order_id.Generator.next t.generators.(participant_idx)
    in
    let symbol_idx = uniform_int t ~lo:0 ~hi:(t.config.num_symbols - 1) in
    let symbol = Symbol_id.of_int symbol_idx in
    let side = if chance t 0.5 then Side.Buy else Side.Sell in
    let size =
      Size.of_int (uniform_int t ~lo:t.config.min_size ~hi:t.config.max_size)
    in
    let marketable = chance t t.config.marketable_fraction in
    (* A resting IOC would cancel itself immediately, so only marketable
       orders are ever IOC; everything placed to rest is a Day order. *)
    let time_in_force : Time_in_force.t =
      if marketable && chance t t.config.ioc_fraction then Ioc else Day
    in
    advance_mid t ~symbol_idx;
    let price = choose_price t ~symbol_idx ~side ~marketable in
    let request : Order.Request.t =
      { symbol
      ; participant
      ; side
      ; price
      ; size
      ; time_in_force
      ; client_order_id
      }
    in
    (* Only orders placed to rest are worth remembering for a future cancel;
       marketable orders usually trade away, so tracking them would just
       breed Cancel_rejects. *)
    if not marketable then push_pool t ~participant ~client_order_id;
    Submit request)
;;

let%expect_test "deterministic, seed-sensitive, prices bracket the mid" =
  let stream ~seed ~n =
    let g = create ~config:Config.balanced ~seed in
    (* Not [List.init]: it applies [f] from [n-1] downto [0], which reverses
       a stateful generator's output. Build the list front-to-back instead. *)
    let rec take i acc =
      if i <= 0 then List.rev acc else take (i - 1) (next_action g :: acc)
    in
    take n []
  in
  (* The exact head of the stream locks sequencing and pricing, not just
     reproducibility: any change to next_action or choose_price surfaces
     here. Balanced starts every mid at 10000c; resting orders sit 5c off it,
     and marketable orders cross to the far side. *)
  List.iter (stream ~seed:0 ~n:6) ~f:(fun a -> print_s [%sexp (a : action)]);
  [%expect
    {|
    (Submit
     ((symbol 7) (participant participant-2) (side Sell) (price 9994) (size 5)
      (time_in_force Ioc) (client_order_id 1)))
    (Submit
     ((symbol 6) (participant participant-2) (side Sell) (price 10006) (size 2)
      (time_in_force Day) (client_order_id 2)))
    (Cancel ((participant participant-2) (client_order_id 2)))
    (Submit
     ((symbol 14) (participant participant-2) (side Sell) (price 9994) (size 10)
      (time_in_force Ioc) (client_order_id 3)))
    (Submit
     ((symbol 10) (participant participant-4) (side Sell) (price 10005) (size 7)
      (time_in_force Day) (client_order_id 1)))
    (Cancel ((participant participant-4) (client_order_id 1)))
    |}];
  (* Two independent generators built from the same seed emit the same
     stream; a different seed diverges. Compared over a long horizon, not
     just the head. *)
  let digest ~seed =
    stream ~seed ~n:2000
    |> List.map ~f:(fun a -> Sexp.to_string [%sexp (a : action)])
    |> String.concat ~sep:"|"
  in
  printf
    "same_seed=%b diff_seed=%b\n"
    (String.equal (digest ~seed:0) (digest ~seed:0))
    (not (String.equal (digest ~seed:0) (digest ~seed:1)));
  [%expect {| same_seed=true diff_seed=true |}]
;;
