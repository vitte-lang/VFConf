(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/lexer/keyword.mli
 *
 * Public interface for the canonical VFConf keyword table.
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

val to_string :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Classification                                             *)
(* ---------------------------------------------------------- *)

val of_string :
  string ->
  t option

val of_string_case_insensitive :
  string ->
  t option

val is_keyword :
  string ->
  bool

val is_keyword_case_insensitive :
  string ->
  bool

(* ---------------------------------------------------------- *)
(* Keyword categories                                         *)
(* ---------------------------------------------------------- *)

val is_control :
  t ->
  bool

val is_boolean :
  t ->
  bool

val is_null :
  t ->
  bool

val is_color_function :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Literal conversion                                         *)
(* ---------------------------------------------------------- *)

val boolean_value :
  t ->
  bool option

val is_true :
  t ->
  bool

val is_false :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Canonical forms                                            *)
(* ---------------------------------------------------------- *)

val canonical :
  t ->
  t

val canonical_string :
  t ->
  string

val is_canonical :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Collections                                                *)
(* ---------------------------------------------------------- *)

val all :
  t list

val control_keywords :
  t list

val boolean_keywords :
  t list

val null_keywords :
  t list

val color_keywords :
  t list

val strings :
  string list

(* ---------------------------------------------------------- *)
(* Ordering                                                   *)
(* ---------------------------------------------------------- *)

val rank :
  t ->
  int

val compare :
  t ->
  t ->
  int

val equal :
  t ->
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp :
  Format.formatter ->
  t ->
  unit