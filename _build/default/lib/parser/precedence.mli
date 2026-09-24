(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/parser/precedence.mli
 *
 * Public interface for canonical operator precedence
 * and associativity definitions.
 *)

type associativity =
  | Left
  | Right
  | Non_associative

type operator =
  | Logical_or
  | Logical_and
  | Logical_not
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign

type info = {
  precedence : int;
  associativity : associativity;
}

(* ---------------------------------------------------------- *)
(* Precedence levels                                          *)
(* ---------------------------------------------------------- *)

val assignment_precedence :
  int

val logical_or_precedence :
  int

val logical_and_precedence :
  int

val comparison_precedence :
  int

val logical_not_precedence :
  int

val primary_precedence :
  int

val info :
  operator ->
  info

val precedence :
  operator ->
  int

val associativity :
  operator ->
  associativity

(* ---------------------------------------------------------- *)
(* Conversion from AST operators                              *)
(* ---------------------------------------------------------- *)

val of_assignment_operator :
  Statement.assignment_operator ->
  operator

val of_comparison_operator :
  Statement.comparison_operator ->
  operator

val of_logical_operator :
  Statement.logical_operator ->
  operator

(* ---------------------------------------------------------- *)
(* Condition precedence                                       *)
(* ---------------------------------------------------------- *)

val condition_precedence :
  Statement.condition Node.t ->
  int

val condition_associativity :
  Statement.condition Node.t ->
  associativity

(* ---------------------------------------------------------- *)
(* Parentheses decisions                                      *)
(* ---------------------------------------------------------- *)

val needs_parentheses :
  parent_precedence:int ->
  child_precedence:int ->
  bool

val needs_parentheses_for_side :
  parent:operator ->
  child:operator ->
  right_side:bool ->
  bool

val condition_needs_parentheses :
  parent:Statement.condition Node.t ->
  child:Statement.condition Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Ordering                                                   *)
(* ---------------------------------------------------------- *)

val compare :
  operator ->
  operator ->
  int

val lower_than :
  operator ->
  operator ->
  bool

val higher_than :
  operator ->
  operator ->
  bool

val same_precedence :
  operator ->
  operator ->
  bool

(* ---------------------------------------------------------- *)
(* Source representation                                      *)
(* ---------------------------------------------------------- *)

val operator_string :
  operator ->
  string

val associativity_string :
  associativity ->
  string

(* ---------------------------------------------------------- *)
(* Classification                                             *)
(* ---------------------------------------------------------- *)

val is_assignment :
  operator ->
  bool

val is_comparison :
  operator ->
  bool

val is_logical :
  operator ->
  bool

val is_binary :
  operator ->
  bool

val is_unary :
  operator ->
  bool

(* ---------------------------------------------------------- *)
(* Collections                                                *)
(* ---------------------------------------------------------- *)

val all :
  operator list

val sorted_by_precedence :
  operator list

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_associativity :
  Format.formatter ->
  associativity ->
  unit

val pp_operator :
  Format.formatter ->
  operator ->
  unit

val pp_info :
  Format.formatter ->
  operator ->
  unit