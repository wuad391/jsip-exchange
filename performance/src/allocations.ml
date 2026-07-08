open! Core

module Build_list = struct
  (* [acc @ [ x ]] copies the whole accumulator each step -> O(n^2)
     allocation. *)
  let silly xs =
    let rec silly_rec acc ys =
      match ys with l :: ls -> silly_rec (acc @ [ l ]) ls | [] -> acc
    in
    silly_rec [] xs
  ;;

  (* Prepend (O(1) per step) then reverse once -> O(n) allocation. Same
     result. *)
  let non_silly xs =
    let rec non_silly_rec acc xs =
      match xs with
      | x :: xs -> non_silly_rec (x :: acc) xs
      | [] -> List.rev acc
    in
    non_silly_rec [] xs
  ;;
end

module First_match = struct
  (* Allocate a fresh list of *every* match, then throw all but the head
     away. *)
  let silly xs ~f =
    let all_matches = List.filter xs ~f in
    match all_matches with x :: _ -> Some x | [] -> None
  ;;

  (* Stop at the first match; allocate nothing but the returned [Some]. *)
  let non_silly xs ~f = List.find xs ~f
  (* let rec non_silly xs = match xs with | x :: xs -> if f x then Some x
     else non_silly xs | [] -> None in non_silly xs ;; *)
end
