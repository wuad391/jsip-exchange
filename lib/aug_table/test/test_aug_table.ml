open! Core
open Jsip_aug_table
open Jsip_types

(* A commutative monoid: measure = sum of the data. *)
module Sum = struct
  type key = int
  type data = int
  type measure = int

  let compare_key = Int.compare
  let identity = 0
  let combine = ( + )
  let measure_of_entry ~key:_ ~data = data
end

(* A non-commutative monoid: measure = the data concatenated in key order. A
   wrong [combine] order inside [create] would reverse this, so it pins down
   that entries are folded left-to-right. *)
module Concat = struct
  type key = int
  type data = string
  type measure = string

  let compare_key = Int.compare
  let identity = ""
  let combine = ( ^ )
  let measure_of_entry ~key:_ ~data = data
end

let sum_of entries =
  List.fold
    entries
    ~init:(Aug_table.empty (module Sum))
    ~f:(fun t (key, data) -> Aug_table.set t ~key ~data)
;;

let%expect_test "measure sums data regardless of insertion order" =
  let t = sum_of [ 3, 30; 1, 10; 2, 20; 5, 50; 4, 40 ] in
  printf "length  = %d\n" (Aug_table.length t);
  printf "measure = %d\n" (Aug_table.measure t);
  print_s [%sexp (Aug_table.to_alist t : (int * int) list)];
  [%expect
    {|
    length  = 5
    measure = 150
    ((1 10) (2 20) (3 30) (4 40) (5 50))
    |}]
;;

let%expect_test "set replaces an existing binding and updates measure" =
  let t = sum_of [ 1, 10; 2, 20; 3, 30 ] in
  let t = Aug_table.set t ~key:2 ~data:200 in
  printf "measure = %d\n" (Aug_table.measure t);
  print_s [%sexp (Aug_table.to_alist t : (int * int) list)];
  [%expect {|
    measure = 240
    ((1 10) (2 200) (3 30))
    |}]
;;

let%expect_test "remove drops a binding and updates measure" =
  let t = sum_of [ 1, 10; 2, 20; 3, 30; 4, 40 ] in
  let t = Aug_table.remove t 2 in
  printf "length  = %d\n" (Aug_table.length t);
  printf "measure = %d\n" (Aug_table.measure t);
  print_s [%sexp (Aug_table.to_alist t : (int * int) list)];
  (* removing a key that is not present leaves the table unchanged *)
  let t = Aug_table.remove t 99 in
  printf "length after removing absent key = %d\n" (Aug_table.length t);
  [%expect
    {|
    length  = 3
    measure = 80
    ((1 10) (3 30) (4 40))
    length after removing absent key = 3
    |}]
;;

let%expect_test "measure concatenates data in key order (pins combine order)"
  =
  let t =
    List.fold
      [ 4, "d"; 2, "b"; 5, "e"; 1, "a"; 3, "c" ]
      ~init:(Aug_table.empty (module Concat))
      ~f:(fun t (key, data) -> Aug_table.set t ~key ~data)
  in
  printf "measure = %s\n" (Aug_table.measure t);
  printf
    "brute   = %s\n"
    (Aug_table.to_alist t |> List.map ~f:snd |> String.concat);
  [%expect {|
    measure = abcde
    brute   = abcde
    |}]
;;

let%expect_test "cached measure matches a brute-force fold under many \
                 rotations"
  =
  let n = 200 in
  (* [(i * 97) mod 200] is a permutation of 0..199 (97 and 200 are coprime),
     so this inserts every key once in a scrambled order that forces the tree
     through many rebalancing rotations. *)
  let keys = List.init n ~f:(fun i -> i * 97 mod n) in
  let t =
    List.fold
      keys
      ~init:(Aug_table.empty (module Sum))
      ~f:(fun t k -> Aug_table.set t ~key:k ~data:k)
  in
  let brute = List.sum (module Int) (Aug_table.to_alist t) ~f:snd in
  let all_found = List.for_all keys ~f:(Aug_table.mem t) in
  let sorted =
    List.is_sorted
      (List.map (Aug_table.to_alist t) ~f:fst)
      ~compare:Int.compare
  in
  printf "length    = %d\n" (Aug_table.length t);
  printf "measure   = %d\n" (Aug_table.measure t);
  printf "brute     = %d\n" brute;
  printf "all_found = %b\n" all_found;
  printf "sorted    = %b\n" sorted;
  [%expect
    {|
    length    = 200
    measure   = 19900
    brute     = 19900
    all_found = true
    sorted    = true
    |}]
;;

(* [Key_monoid_table]'s measure is a monoid over the keys. Using [(+)] here
   (sum of the distinct keys) instead of the [max] that [Key_aug_table] pins
   down demonstrates that the choice of monoid is free. *)
module Key_sum = struct
  type key = int

  let compare_key = Int.compare
  let identity = 0
  let combine = ( + )
end

let%expect_test "key_monoid_table: measure is any monoid over the keys" =
  let t =
    List.fold
      [ 3; 1; 4; 1; 5; 9; 2; 6 ]
      ~init:(Key_monoid_table.empty (module Key_sum))
      ~f:(fun t k -> Key_monoid_table.set t ~key:k ~data:k)
  in
  (* keys form a set (the duplicate 1 collapses), so the cached sum must
     match a brute-force sum of the alist keys *)
  let brute = List.sum (module Int) (Key_monoid_table.to_alist t) ~f:fst in
  printf
    "length=%d sum_of_keys=%d brute=%d\n"
    (Key_monoid_table.length t)
    (Key_monoid_table.measure t)
    brute;
  let t = Key_monoid_table.remove t 9 in
  printf "after remove 9: sum_of_keys=%d\n" (Key_monoid_table.measure t);
  [%expect
    {|
    length=7 sum_of_keys=30 brute=30
    after remove 9: sum_of_keys=21
    |}]
;;

let%expect_test "key_aug_table: max_key / min_elt / max_elt across \
                 set/remove"
  =
  let price = Price.of_int_cents in
  let t =
    List.fold
      [ 3; 1; 4; 1; 5; 9; 2; 6 ]
      ~init:Key_aug_table.empty
      ~f:(fun t k -> Key_aug_table.set t ~key:(price k) ~data:k)
  in
  let show label = function
    | None -> printf "%s=none\n" label
    | Some (p, d) -> printf "%s=(%d,%d)\n" label (Price.to_int_cents p) d
  in
  printf
    "length=%d max_key=%d\n"
    (Key_aug_table.length t)
    (Key_aug_table.max_key t |> Price.to_int_cents);
  print_s [%sexp (Key_aug_table.to_alist t : (Price.t * int) list)];
  show "min_elt" (Key_aug_table.min_elt t);
  show "max_elt" (Key_aug_table.max_elt t);
  let t = Key_aug_table.remove t (price 9) in
  (* the cached max_key and the max_elt spine walk must both track the actual
     maximum key after a removal *)
  let brute_max =
    List.fold
      (Key_aug_table.to_alist t)
      ~init:Price.zero
      ~f:(fun acc (k, _) -> Price.max acc k)
  in
  printf
    "after remove 9: length=%d max_key=%d brute=%d\n"
    (Key_aug_table.length t)
    (Key_aug_table.max_key t |> Price.to_int_cents)
    (Price.to_int_cents brute_max);
  show "min_elt" (Key_aug_table.min_elt t);
  show "max_elt" (Key_aug_table.max_elt t);
  [%expect
    {|
    length=7 max_key=9
    ((1 1) (2 2) (3 3) (4 4) (5 5) (6 6) (9 9))
    min_elt=(1,1)
    max_elt=(9,9)
    after remove 9: length=6 max_key=6 brute=6
    min_elt=(1,1)
    max_elt=(6,6)
    |}]
;;
