(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/lexer/token.mli
 *
 * Public token representation used by VFConf tooling.
 *)

type t =
  (* Keywords *)
  | Include
  | Define
  | When
  | Else

  (* Literals *)
  | Identifier of string
  | String of string
  | Integer of int64
  | Float of float
  | Boolean of bool
  | Null
  | Color of string
  | Duration of float * Value.duration_unit
  | Size of float * Value.size_unit

  (* Color constructors *)
  | Rgb
  | Rgba

  (* Assignment operators *)
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign

  (* Comparison operators *)
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal

  (* Logical operators *)
  | And
  | Or
  | Not

  (* Delimiters *)
  | Left_bracket
  | Right_bracket
  | Left_brace
  | Right_brace
  | Left_parenthesis
  | Right_parenthesis

  (* Punctuation *)
  | Comma
  | Colon
  | Semicolon
  | Dot
  | Dollar

  (* Layout *)
  | Newline

  (* End of input *)
  | Eof

type located = t Node.t

(* ---------------------------------------------------------- *)
(* Classification                                             *)
(* ---------------------------------------------------------- *)

val is_keyword :
  t ->
  bool

val is_literal :
  t ->
  bool

val is_assignment_operator :
  t ->
  bool

val is_comparison_operator :
  t ->
  bool

val is_logical_operator :
  t ->
  bool

val is_operator :
  t ->
  bool

val is_delimiter :
  t ->
  bool

val is_punctuation :
  t ->
  bool

val is_layout :
  t ->
  bool

val is_eof :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Token names                                                *)
(* ---------------------------------------------------------- *)

val name :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Source spelling                                            *)
(* ---------------------------------------------------------- *)

val string_of_duration_unit :
  Value.duration_unit ->
  string

val string_of_size_unit :
  Value.size_unit ->
  string

val to_string :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Descriptions                                               *)
(* ---------------------------------------------------------- *)

val description :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Literal accessors                                          *)
(* ---------------------------------------------------------- *)

val identifier_value :
  t ->
  string option

val string_value :
  t ->
  string option

val integer_value :
  t ->
  int64 option

val float_value :
  t ->
  float option

val boolean_value :
  t ->
  bool option

val color_value :
  t ->
  string option

val duration_value :
  t ->
  (float * Value.duration_unit) option

val size_value :
  t ->
  (float * Value.size_unit) option

(* ---------------------------------------------------------- *)
(* Equality                                                   *)
(* ---------------------------------------------------------- *)

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

val pp_debug :
  Format.formatter ->
  t ->
  unit

(* ---------------------------------------------------------- *)
(* Located tokens                                             *)
(* ---------------------------------------------------------- *)

val located :
  t ->
  Node.span ->
  located

val value :
  located ->
  t

val span :
  located ->
  Node.span