(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/formatter/printer.mli
 *
 * Public interface for low-level VFConf pretty-printing.
 *)

type style = {
  indent_width : int;
  newline : string;
  space_after_comma : bool;
  space_after_colon : bool;
  space_around_operators : bool;
}

val default_style : style

type t

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val create :
  ?capacity:int ->
  ?style:style ->
  unit ->
  t

val clear :
  t ->
  unit

val reset :
  t ->
  unit

val contents :
  t ->
  string

val length :
  t ->
  int

val is_empty :
  t ->
  bool

val style :
  t ->
  style

val level :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Indentation                                                *)
(* ---------------------------------------------------------- *)

val indentation :
  t ->
  string

val write_indentation :
  t ->
  unit

val indent :
  t ->
  unit

val dedent :
  t ->
  unit

val with_indent :
  t ->
  (t -> 'a) ->
  'a

(* ---------------------------------------------------------- *)
(* Raw output                                                 *)
(* ---------------------------------------------------------- *)

val raw :
  t ->
  string ->
  unit

val char :
  t ->
  char ->
  unit

val text :
  t ->
  string ->
  unit

val space :
  t ->
  unit

val newline :
  t ->
  unit

val blank_line :
  t ->
  unit

(* ---------------------------------------------------------- *)
(* Tokens                                                     *)
(* ---------------------------------------------------------- *)

val comma :
  t ->
  unit

val colon :
  t ->
  unit

val semicolon :
  t ->
  unit

val dot :
  t ->
  unit

val operator :
  t ->
  string ->
  unit

(* ---------------------------------------------------------- *)
(* Strings                                                    *)
(* ---------------------------------------------------------- *)

val escape_string :
  string ->
  string

val quoted :
  t ->
  string ->
  unit

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val path :
  t ->
  string list ->
  unit

val reference :
  t ->
  string list ->
  unit

(* ---------------------------------------------------------- *)
(* Delimiters                                                 *)
(* ---------------------------------------------------------- *)

val delimited :
  t ->
  left:string ->
  right:string ->
  (t -> 'a) ->
  'a

val parentheses :
  t ->
  (t -> 'a) ->
  'a

val brackets :
  t ->
  (t -> 'a) ->
  'a

val braces :
  t ->
  (t -> 'a) ->
  'a

(* ---------------------------------------------------------- *)
(* Lists                                                      *)
(* ---------------------------------------------------------- *)

val separated :
  t ->
  separator:(t -> unit) ->
  (t -> 'a -> unit) ->
  'a list ->
  unit

val comma_separated :
  t ->
  (t -> 'a -> unit) ->
  'a list ->
  unit

val newline_separated :
  t ->
  (t -> 'a -> unit) ->
  'a list ->
  unit

(* ---------------------------------------------------------- *)
(* Primitive values                                           *)
(* ---------------------------------------------------------- *)

val integer :
  t ->
  int64 ->
  unit

val float :
  t ->
  float ->
  unit

val boolean :
  t ->
  bool ->
  unit

val null :
  t ->
  unit

val color :
  t ->
  Value.color ->
  unit

val duration :
  t ->
  float ->
  Value.duration_unit ->
  unit

val size :
  t ->
  float ->
  Value.size_unit ->
  unit

(* ---------------------------------------------------------- *)
(* VFConf values                                              *)
(* ---------------------------------------------------------- *)

val value :
  t ->
  Value.t Node.t ->
  unit

val array :
  t ->
  Value.t Node.t list ->
  unit

val object_entry :
  t ->
  Value.object_entry ->
  unit

val object_ :
  t ->
  Value.object_entry list ->
  unit

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

val assignment_operator :
  t ->
  Statement.assignment_operator ->
  unit

val comparison_operator :
  t ->
  Statement.comparison_operator ->
  unit

val logical_operator :
  t ->
  Statement.logical_operator ->
  unit

val condition :
  t ->
  Statement.condition Node.t ->
  unit

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

val statement :
  t ->
  Statement.t Node.t ->
  unit

val section_statement :
  t ->
  Statement.section ->
  unit

val conditional_statement :
  t ->
  Statement.conditional ->
  unit

val block :
  t ->
  Statement.t Node.t list ->
  unit

(* ---------------------------------------------------------- *)
(* Documents                                                  *)
(* ---------------------------------------------------------- *)

val document :
  t ->
  Statement.t Node.t list ->
  unit

val print_value :
  ?style:style ->
  Value.t Node.t ->
  string

val print_condition :
  ?style:style ->
  Statement.condition Node.t ->
  string

val print_statement :
  ?style:style ->
  Statement.t Node.t ->
  string

val print_document :
  ?style:style ->
  Statement.t Node.t list ->
  string