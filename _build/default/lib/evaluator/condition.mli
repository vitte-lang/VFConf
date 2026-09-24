(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/evaluator/condition.mli
 *
 * Public interface for VFConf conditional expression evaluation.
 *)

type error =
  | Undefined_reference of Statement.reference
  | Invalid_reference_value of Statement.reference
  | Invalid_comparison of {
      left : Value.t;
      operator : Statement.comparison_operator;
      right : Value.t;
    }

exception Condition_error of error

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val string_of_path :
  string list ->
  string

(* ---------------------------------------------------------- *)
(* Value helpers                                              *)
(* ---------------------------------------------------------- *)

val value_to_bool :
  Value.t ->
  bool option

val numeric_value :
  Value.t ->
  float option

val compare_numeric :
  Statement.comparison_operator ->
  float ->
  float ->
  bool

val compare_string :
  Statement.comparison_operator ->
  string ->
  string ->
  bool

val compare_bool :
  Statement.comparison_operator ->
  bool ->
  bool ->
  bool

(* ---------------------------------------------------------- *)
(* Value comparison                                           *)
(* ---------------------------------------------------------- *)

val compare_values :
  Statement.comparison_operator ->
  Value.t ->
  Value.t ->
  bool

(* ---------------------------------------------------------- *)
(* Reference resolution                                       *)
(* ---------------------------------------------------------- *)

val resolve_reference :
  Config.t ->
  Statement.reference ->
  Value.t Node.t

val resolve_reference_value :
  Config.t ->
  Statement.reference ->
  Value.t

val reference_exists :
  Config.t ->
  Statement.reference ->
  bool

val reference_truthy :
  Config.t ->
  Statement.reference ->
  bool

(* ---------------------------------------------------------- *)
(* Evaluation                                                 *)
(* ---------------------------------------------------------- *)

val evaluate :
  Config.t ->
  Statement.condition Node.t ->
  bool

val evaluate_opt :
  Config.t ->
  Statement.condition Node.t ->
  bool option

val evaluate_default :
  default:bool ->
  Config.t ->
  Statement.condition Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Static condition inspection                                *)
(* ---------------------------------------------------------- *)

val is_constant :
  Statement.condition Node.t ->
  bool

val constant_value :
  Statement.condition Node.t ->
  bool option

val is_always_true :
  Statement.condition Node.t ->
  bool

val is_always_false :
  Statement.condition Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val diagnostic_of_error :
  ?span:Node.span ->
  error ->
  Diagnostic.t

val evaluate_diagnostic :
  Config.t ->
  Statement.condition Node.t ->
  (bool, Diagnostic.t) result

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