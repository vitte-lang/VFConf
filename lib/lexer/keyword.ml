(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/lexer/keyword.ml
 *
 * Canonical VFConf keyword table.
 *
 * This module is intentionally independent from the generated
 * Menhir parser token type. The lexer can classify an identifier
 * here first and then map the resulting keyword to Parser tokens.
 *)

type t =
  | Include
  | Define
  | When
  | Else
  | True
  | False
  | On
  | Off
  | Null
  | None
  | Rgb
  | Rgba

(* ---------------------------------------------------------- *)
(* Canonical spelling                                         *)
(* ---------------------------------------------------------- *)

let to_string = function
  | Include ->
      "include"

  | Define ->
      "define"

  | When ->
      "when"

  | Else ->
      "else"

  | True ->
      "true"

  | False ->
      "false"

  | On ->
      "on"

  | Off ->
      "off"

  | Null ->
      "null"

  | None ->
      "none"

  | Rgb ->
      "rgb"

  | Rgba ->
      "rgba"

(* ---------------------------------------------------------- *)
(* Classification                                             *)
(* ---------------------------------------------------------- *)

let of_string = function
  | "include" ->
      Some Include

  | "define" ->
      Some Define

  | "when" ->
      Some When

  | "else" ->
      Some Else

  | "true" ->
      Some True

  | "false" ->
      Some False

  | "on" ->
      Some On

  | "off" ->
      Some Off

  | "null" ->
      Some Null

  | "none" ->
      Some None

  | "rgb" ->
      Some Rgb

  | "rgba" ->
      Some Rgba

  | _ ->
      None

let of_string_case_insensitive value =
  of_string
    (String.lowercase_ascii value)

let is_keyword value =
  match of_string value with
  | Some _ ->
      true

  | None ->
      false

let is_keyword_case_insensitive value =
  match of_string_case_insensitive value with
  | Some _ ->
      true

  | None ->
      false

(* ---------------------------------------------------------- *)
(* Keyword categories                                         *)
(* ---------------------------------------------------------- *)

let is_control = function
  | Include
  | Define
  | When
  | Else ->
      true

  | True
  | False
  | On
  | Off
  | Null
  | None
  | Rgb
  | Rgba ->
      false

let is_boolean = function
  | True
  | False
  | On
  | Off ->
      true

  | Include
  | Define
  | When
  | Else
  | Null
  | None
  | Rgb
  | Rgba ->
      false

let is_null = function
  | Null
  | None ->
      true

  | Include
  | Define
  | When
  | Else
  | True
  | False
  | On
  | Off
  | Rgb
  | Rgba ->
      false

let is_color_function = function
  | Rgb
  | Rgba ->
      true

  | Include
  | Define
  | When
  | Else
  | True
  | False
  | On
  | Off
  | Null
  | None ->
      false

(* ---------------------------------------------------------- *)
(* Literal conversion                                         *)
(* ---------------------------------------------------------- *)

let boolean_value = function
  | True
  | On ->
      Some true

  | False
  | Off ->
      Some false

  | Include
  | Define
  | When
  | Else
  | Null
  | None
  | Rgb
  | Rgba ->
      None

let is_true keyword =
  boolean_value keyword = Some true

let is_false keyword =
  boolean_value keyword = Some false

(* ---------------------------------------------------------- *)
(* Canonical forms                                            *)
(* ---------------------------------------------------------- *)

let canonical = function
  | On ->
      True

  | Off ->
      False

  | None ->
      Null

  | keyword ->
      keyword

let canonical_string keyword =
  keyword
  |> canonical
  |> to_string

let is_canonical keyword =
  canonical keyword = keyword

(* ---------------------------------------------------------- *)
(* Collections                                                *)
(* ---------------------------------------------------------- *)

let all =
  [
    Include;
    Define;
    When;
    Else;
    True;
    False;
    On;
    Off;
    Null;
    None;
    Rgb;
    Rgba;
  ]

let control_keywords =
  List.filter
    is_control
    all

let boolean_keywords =
  List.filter
    is_boolean
    all

let null_keywords =
  List.filter
    is_null
    all

let color_keywords =
  List.filter
    is_color_function
    all

let strings =
  List.map
    to_string
    all

(* ---------------------------------------------------------- *)
(* Ordering                                                   *)
(* ---------------------------------------------------------- *)

let rank = function
  | Include -> 0
  | Define -> 1
  | When -> 2
  | Else -> 3
  | True -> 4
  | False -> 5
  | On -> 6
  | Off -> 7
  | Null -> 8
  | None -> 9
  | Rgb -> 10
  | Rgba -> 11

let compare left right =
  Int.compare
    (rank left)
    (rank right)

let equal left right =
  compare left right = 0

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp formatter keyword =
  Format.pp_print_string
    formatter
    (to_string keyword)