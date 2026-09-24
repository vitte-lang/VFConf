(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/evaluator/reference.mli
 *
 * Public interface for VFConf reference resolution.
 *)

module String_set : Set.S with type elt = string

type path = Statement.reference

type source =
  | Configuration
  | Definition

type resolved = {
  path : path;
  value : Value.t Node.t;
  source : source;
}

type error =
  | Empty_reference
  | Undefined_reference of path
  | Invalid_definition_reference of path
  | Reference_cycle of path list
  | Maximum_depth_exceeded of {
      maximum : int;
      path : path;
    }

exception Reference_error of error

type context = {
  config : Config.t;
  definitions : Value.t Node.t Evaluator.String_map.t;
  stack : path list;
  visited : String_set.t;
  maximum_depth : int;
}

val default_maximum_depth : int

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val string_of_path :
  path ->
  string

val key_of_path :
  path ->
  string

val valid_path :
  path ->
  bool

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

val create :
  ?maximum_depth:int ->
  config:Config.t ->
  definitions:Value.t Node.t Evaluator.String_map.t ->
  unit ->
  context

val of_environment :
  ?maximum_depth:int ->
  config:Config.t ->
  Evaluator.environment ->
  context

val depth :
  context ->
  int

val current_path :
  context ->
  path option

(* ---------------------------------------------------------- *)
(* Stack                                                      *)
(* ---------------------------------------------------------- *)

val cycle_from_stack :
  path ->
  path list ->
  path list

val push :
  path ->
  context ->
  context

val pop :
  context ->
  context

(* ---------------------------------------------------------- *)
(* Direct lookup                                              *)
(* ---------------------------------------------------------- *)

val find_config :
  context ->
  path ->
  resolved option

val find_definition :
  context ->
  path ->
  resolved option

val find_direct :
  context ->
  path ->
  resolved option

val exists :
  context ->
  path ->
  bool

(* ---------------------------------------------------------- *)
(* Resolution                                                 *)
(* ---------------------------------------------------------- *)

val resolve_value :
  context ->
  Value.t Node.t ->
  Value.t Node.t

val resolve :
  context ->
  path ->
  resolved

val resolve_opt :
  context ->
  path ->
  resolved option

val resolve_value_opt :
  context ->
  Value.t Node.t ->
  Value.t Node.t option

(* ---------------------------------------------------------- *)
(* Bulk resolution                                            *)
(* ---------------------------------------------------------- *)

val resolve_entry :
  context ->
  Config.entry ->
  Config.entry

val resolve_config :
  context ->
  Config.t

val resolve_all :
  ?maximum_depth:int ->
  config:Config.t ->
  environment:Evaluator.environment ->
  unit ->
  Config.t

(* ---------------------------------------------------------- *)
(* Dependency inspection                                      *)
(* ---------------------------------------------------------- *)

val references_of_value :
  Value.t Node.t ->
  path list

val references_of_entry :
  Config.entry ->
  path list

val dependencies :
  Config.t ->
  (Config.path * path list) list

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

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