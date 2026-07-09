open! Core
open Jsip_aug_table

(* A commutative monoid: measure = sum of the data. *)
module Sum = struct
  type key = int
  type data = int
  type measure = int

  let compare_key = Int.compare
  let identity = 0
  let combine = ( + )
  let of_entry _key data = data
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
  let of_entry _key data = data
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
