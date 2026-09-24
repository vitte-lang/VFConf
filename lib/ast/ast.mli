(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/ast.mli
 *
 * Public interface for the canonical VFConf AST.
 *)

(* ---------------------------------------------------------- *)
(* Source locations                                           *)
(* ---------------------------------------------------------- *)

type position = {
  offset : int;
  line : int;
  column : int;
}

type span = {
  filename : string;
  start_pos : position;
  end_pos : position;
}

type 'a located = {
  value : 'a;
  span : span;
}

val located : span -> 'a -> 'a located

(* ---------------------------------------------------------- *)
(* Names                                                      *)
(* ---------------------------------------------------------- *)

type identifier = string

type path = identifier list

type key = path

type section_name = path

type reference = path

(* ---------------------------------------------------------- *)
(* Operators                                                  *)
(* ---------------------------------------------------------- *)

type assignment_operator =
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign

type comparison_operator =
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal

type logical_operator =
  | And
  | Or

(* ---------------------------------------------------------- *)
(* Units                                                      *)
(* ---------------------------------------------------------- *)

type duration_unit =
  | Nanosecond
  | Microsecond
  | Millisecond
  | Second
  | Minute
  | Hour

type size_unit =
  | Byte
  | Kilobyte
  | Megabyte
  | Gigabyte
  | Kibibyte
  | Mebibyte
  | Gibibyte

(* ---------------------------------------------------------- *)
(* Colors                                                     *)
(* ---------------------------------------------------------- *)

type color =
  | Hex of string
  | Rgb of {
      red : int;
      green : int;
      blue : int;
    }
  | Rgba of {
      red : int;
      green : int;
      blue : int;
      alpha : float;
    }

(* ---------------------------------------------------------- *)
(* Values                                                     *)
(* ---------------------------------------------------------- *)

type value =
  | String of string
  | Integer of int64
  | Float of float
  | Boolean of bool
  | Null
  | Array of value located list
  | Object of object_entry list
  | Reference of reference
  | Color of color
  | Duration of float * duration_unit
  | Size of float * size_unit

and object_entry = {
  object_key : key;
  object_value : value located;
  object_span : span;
}

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

type condition =
  | Condition_reference of reference
  | Condition_boolean of bool
  | Condition_not of condition located
  | Condition_logical of {
      left : condition located;
      operator : logical_operator;
      right : condition located;
    }
  | Condition_compare of {
      reference : reference;
      operator : comparison_operator;
      value : value located;
    }

(* ---------------------------------------------------------- *)
(* Assignments                                                *)
(* ---------------------------------------------------------- *)

type assignment = {
  key : key;
  operator : assignment_operator;
  value : value located;
}

(* ---------------------------------------------------------- *)
(* Includes                                                   *)
(* ---------------------------------------------------------- *)

type include_statement = {
  path : string;
}

(* ---------------------------------------------------------- *)
(* Definitions                                                *)
(* ---------------------------------------------------------- *)

type define_statement = {
  name : identifier;
  value : value located;
}

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

type statement =
  | Assignment of assignment
  | Include of include_statement
  | Define of define_statement
  | Section of section
  | Conditional of conditional

and section = {
  name : section_name;
  body : statement located list;
}

and conditional = {
  condition : condition located;
  then_branch : statement located list;
  else_branch : statement located list option;
}

(* ---------------------------------------------------------- *)
(* Document                                                   *)
(* ---------------------------------------------------------- *)

type document = {
  statements : statement located list;
  filename : string;
}

val empty_document :
  ?filename:string ->
  unit ->
  document

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

val path_of_string :
  string ->
  path

val string_of_path :
  path ->
  string

(* ---------------------------------------------------------- *)
(* Operator conversion                                        *)
(* ---------------------------------------------------------- *)

val string_of_assignment_operator :
  assignment_operator ->
  string

val string_of_comparison_operator :
  comparison_operator ->
  string

val string_of_logical_operator :
  logical_operator ->
  string

(* ---------------------------------------------------------- *)
(* Unit conversion                                            *)
(* ---------------------------------------------------------- *)

val string_of_duration_unit :
  duration_unit ->
  string

val string_of_size_unit :
  size_unit ->
  string

(* ---------------------------------------------------------- *)
(* Pretty printers                                            *)
(* ---------------------------------------------------------- *)

val pp_position :
  Format.formatter ->
  position ->
  unit

val pp_span :
  Format.formatter ->
  span ->
  unit

val pp_path :
  Format.formatter ->
  path ->
  unit

val pp_color :
  Format.formatter ->
  color ->
  unit

val pp_value :
  Format.formatter ->
  value ->
  unit

(* ---------------------------------------------------------- *)
(* AST debugging                                              *)
(* ---------------------------------------------------------- *)

val dump_condition :
  Format.formatter ->
  int ->
  condition located ->
  unit

val dump_statement :
  Format.formatter ->
  int ->
  statement located ->
  unit

val dump :
  Format.formatter ->
  document ->
  unit

val dump_stdout :
  document ->
  unit