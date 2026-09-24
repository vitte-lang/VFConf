(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/statement.mli
 *
 * Public interface for VFConf statements.
 *)

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
(* Values                                                     *)
(* ---------------------------------------------------------- *)

type value = Value.t

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

type condition =
  | Reference of reference
  | Boolean of bool
  | Not of condition Node.t
  | Logical of {
      left : condition Node.t;
      operator : logical_operator;
      right : condition Node.t;
    }
  | Compare of {
      reference : reference;
      operator : comparison_operator;
      value : value Node.t;
    }

(* ---------------------------------------------------------- *)
(* Assignments                                                *)
(* ---------------------------------------------------------- *)

type assignment = {
  key : key;
  operator : assignment_operator;
  value : value Node.t;
}

(* ---------------------------------------------------------- *)
(* Include                                                    *)
(* ---------------------------------------------------------- *)

type include_statement = {
  path : string;
}

(* ---------------------------------------------------------- *)
(* Definition                                                 *)
(* ---------------------------------------------------------- *)

type define_statement = {
  name : identifier;
  value : value Node.t;
}

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

type t =
  | Assignment of assignment
  | Include of include_statement
  | Define of define_statement
  | Section of section
  | Conditional of conditional

and section = {
  name : section_name;
  body : t Node.t list;
}

and conditional = {
  condition : condition Node.t;
  then_branch : t Node.t list;
  else_branch : t Node.t list option;
}

(* ---------------------------------------------------------- *)
(* Constructors                                               *)
(* ---------------------------------------------------------- *)

val assignment :
  ?operator:assignment_operator ->
  key ->
  value Node.t ->
  t

val include_ :
  string ->
  t

val define :
  identifier ->
  value Node.t ->
  t

val section :
  section_name ->
  t Node.t list ->
  t

val conditional :
  condition Node.t ->
  t Node.t list ->
  t Node.t list option ->
  t

(* ---------------------------------------------------------- *)
(* Located constructors                                       *)
(* ---------------------------------------------------------- *)

val located_assignment :
  Node.span ->
  ?operator:assignment_operator ->
  key ->
  value Node.t ->
  t Node.t

val located_include :
  Node.span ->
  string ->
  t Node.t

val located_define :
  Node.span ->
  identifier ->
  value Node.t ->
  t Node.t

val located_section :
  Node.span ->
  section_name ->
  t Node.t list ->
  t Node.t

val located_conditional :
  Node.span ->
  condition Node.t ->
  t Node.t list ->
  t Node.t list option ->
  t Node.t

(* ---------------------------------------------------------- *)
(* Condition constructors                                     *)
(* ---------------------------------------------------------- *)

val condition_reference :
  reference ->
  condition

val condition_boolean :
  bool ->
  condition

val condition_not :
  condition Node.t ->
  condition

val condition_and :
  condition Node.t ->
  condition Node.t ->
  condition

val condition_or :
  condition Node.t ->
  condition Node.t ->
  condition

val condition_compare :
  reference ->
  comparison_operator ->
  value Node.t ->
  condition

(* ---------------------------------------------------------- *)
(* Predicates                                                 *)
(* ---------------------------------------------------------- *)

val is_assignment :
  t ->
  bool

val is_include :
  t ->
  bool

val is_define :
  t ->
  bool

val is_section :
  t ->
  bool

val is_conditional :
  t ->
  bool

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

val string_of_path :
  path ->
  string

(* ---------------------------------------------------------- *)
(* Traversal                                                  *)
(* ---------------------------------------------------------- *)

val iter :
  (t Node.t -> unit) ->
  t Node.t ->
  unit

val fold :
  ('a -> t Node.t -> 'a) ->
  'a ->
  t Node.t ->
  'a

(* ---------------------------------------------------------- *)
(* Counting                                                   *)
(* ---------------------------------------------------------- *)

val count :
  t Node.t list ->
  int

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_path :
  Format.formatter ->
  path ->
  unit

val pp_condition :
  Format.formatter ->
  condition ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit

val pp_located :
  Format.formatter ->
  t Node.t ->
  unit

(* ---------------------------------------------------------- *)
(* Debug dump                                                 *)
(* ---------------------------------------------------------- *)

val dump :
  Format.formatter ->
  int ->
  t Node.t ->
  unit