(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/evaluator/evaluator.mli
 *
 * Public interface for the main VFConf evaluator.
 *)

module String_map : Map.S with type key = string

type definition = Value.t Node.t

type environment = {
  definitions : definition String_map.t;
}

type state = {
  config : Config.t;
  environment : environment;
  diagnostics : Diagnostic.t list;
}

type error =
  | Duplicate_definition of string
  | Undefined_definition of string
  | Undefined_reference of Statement.reference
  | Invalid_assignment of {
      path : Config.path;
      operator : Statement.assignment_operator;
    }
  | Invalid_condition of Condition.error
  | Unsupported_statement of string

exception Evaluation_error of error

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val empty_environment :
  environment

val empty_state :
  ?filename:string ->
  unit ->
  state

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val path_to_string :
  string list ->
  string

val qualify :
  'a list ->
  'a list ->
  'a list

(* ---------------------------------------------------------- *)
(* Environment                                                *)
(* ---------------------------------------------------------- *)

val define :
  environment ->
  string ->
  definition ->
  environment

val set_definition :
  environment ->
  string ->
  definition ->
  environment

val find_definition_opt :
  environment ->
  string ->
  definition option

val find_definition :
  environment ->
  string ->
  definition

val mem_definition :
  environment ->
  string ->
  bool

val definitions :
  environment ->
  (string * definition) list

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val add_diagnostic :
  Diagnostic.t ->
  state ->
  state

val add_diagnostics :
  Diagnostic.t list ->
  state ->
  state

val diagnostics :
  state ->
  Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Reference resolution                                       *)
(* ---------------------------------------------------------- *)

val resolve_config_reference :
  Config.t ->
  Statement.reference ->
  Value.t Node.t option

val resolve_definition_reference :
  environment ->
  Statement.reference ->
  definition option

val resolve_reference :
  state ->
  Statement.reference ->
  Value.t Node.t

(* ---------------------------------------------------------- *)
(* Value evaluation                                           *)
(* ---------------------------------------------------------- *)

val evaluate_value :
  state ->
  Value.t Node.t ->
  Value.t Node.t

(* ---------------------------------------------------------- *)
(* Assignment operations                                      *)
(* ---------------------------------------------------------- *)

val append_value :
  Value.t Node.t ->
  Value.t Node.t ->
  Value.t Node.t option

val subtract_value :
  Value.t Node.t ->
  Value.t Node.t ->
  Value.t Node.t option

val apply_assignment :
  state ->
  Config.path ->
  Statement.assignment_operator ->
  Value.t Node.t ->
  state

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

val evaluate_condition :
  Config.path ->
  state ->
  Statement.condition Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

val evaluate_statements :
  Config.path ->
  state ->
  Statement.t Node.t list ->
  state

val evaluate_statement :
  Config.path ->
  state ->
  Statement.t Node.t ->
  state

(* ---------------------------------------------------------- *)
(* Document evaluation                                        *)
(* ---------------------------------------------------------- *)

val evaluate_document :
  ?filename:string ->
  Statement.t Node.t list ->
  state

val evaluate :
  ?filename:string ->
  Statement.t Node.t list ->
  Config.t

val evaluate_with_diagnostics :
  ?filename:string ->
  Statement.t Node.t list ->
  (Config.t * Diagnostic.t list, error) result

(* ---------------------------------------------------------- *)
(* Error conversion                                           *)
(* ---------------------------------------------------------- *)

val string_of_assignment_operator :
  Statement.assignment_operator ->
  string

val diagnostic_of_error :
  ?span:Node.span ->
  error ->
  Diagnostic.t

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

val string_of_error :
  error ->
  string

val pp_error :
  Format.formatter ->
  error ->
  unit

(* ---------------------------------------------------------- *)
(* State inspection                                           *)
(* ---------------------------------------------------------- *)

val config :
  state ->
  Config.t

val environment :
  state ->
  environment

val definition_count :
  environment ->
  int