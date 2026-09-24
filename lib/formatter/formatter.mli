(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/formatter/formatter.mli
 *
 * Public interface for the canonical VFConf formatter.
 *)

type options = {
  indent_width : int;
  final_newline : bool;
  space_around_operators : bool;
  multiline_arrays : bool;
  multiline_objects : bool;
  sort_object_keys : bool;
}

val default_options : options

(* ---------------------------------------------------------- *)
(* Basic helpers                                              *)
(* ---------------------------------------------------------- *)

val spaces :
  int ->
  string

val indentation :
  options ->
  int ->
  string

val string_of_path :
  string list ->
  string

val string_of_reference :
  string list ->
  string

val assignment_operator :
  Statement.assignment_operator ->
  string

val comparison_operator :
  Statement.comparison_operator ->
  string

val logical_operator :
  Statement.logical_operator ->
  string

val operator_spacing :
  options ->
  string ->
  string

(* ---------------------------------------------------------- *)
(* String formatting                                          *)
(* ---------------------------------------------------------- *)

val escape_string :
  string ->
  string

val quote_string :
  string ->
  string

(* ---------------------------------------------------------- *)
(* Primitive value formatting                                 *)
(* ---------------------------------------------------------- *)

val string_of_float :
  float ->
  string

val string_of_duration_unit :
  Value.duration_unit ->
  string

val string_of_size_unit :
  Value.size_unit ->
  string

val clamp_byte :
  int ->
  int

val string_of_color :
  Value.color ->
  string

(* ---------------------------------------------------------- *)
(* Value formatting                                           *)
(* ---------------------------------------------------------- *)

val format_value :
  ?options:options ->
  ?level:int ->
  Value.t Node.t ->
  string

val format_array :
  options:options ->
  level:int ->
  Value.t Node.t list ->
  string

val format_object :
  options:options ->
  level:int ->
  Value.object_entry list ->
  string

(* ---------------------------------------------------------- *)
(* Condition formatting                                       *)
(* ---------------------------------------------------------- *)

val condition_precedence :
  Statement.condition Node.t ->
  int

val format_condition :
  ?options:options ->
  ?parent_precedence:int ->
  Statement.condition Node.t ->
  string

(* ---------------------------------------------------------- *)
(* Statement formatting                                       *)
(* ---------------------------------------------------------- *)

val format_statement :
  ?options:options ->
  ?level:int ->
  Statement.t Node.t ->
  string

val format_section :
  options:options ->
  level:int ->
  Statement.section ->
  string

val format_conditional :
  options:options ->
  level:int ->
  Statement.conditional ->
  string

val format_block :
  options:options ->
  level:int ->
  Statement.t Node.t list ->
  string

val format_statements :
  ?options:options ->
  ?level:int ->
  Statement.t Node.t list ->
  string

(* ---------------------------------------------------------- *)
(* Document formatting                                        *)
(* ---------------------------------------------------------- *)

val format_document :
  ?options:options ->
  Statement.t Node.t list ->
  string

val format :
  ?options:options ->
  Statement.t Node.t list ->
  string

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_value :
  ?options:options ->
  Format.formatter ->
  Value.t Node.t ->
  unit

val pp_condition :
  ?options:options ->
  Format.formatter ->
  Statement.condition Node.t ->
  unit

val pp_statement :
  ?options:options ->
  Format.formatter ->
  Statement.t Node.t ->
  unit

val pp :
  ?options:options ->
  Format.formatter ->
  Statement.t Node.t list ->
  unit