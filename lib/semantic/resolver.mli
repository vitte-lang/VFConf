(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/resolver.mli
 *
 * Public interface for semantic reference resolution.
 *)

module String_set : Set.S with type elt = String.t

type path = Statement.reference

type source =
  | Definition
  | Configuration

type resolved = {
  path : path;
  value : Value.t Node.t;
  source : source;
  span : Node.span;
}

type error =
  | Empty_reference
  | Undefined_reference of path
  | Reference_cycle of path list
  | Maximum_depth_exceeded of {
      maximum : int;
      path : path;
    }

exception Resolution_error of error

type context = {
  environment : Environment.t;
  stack : path list;
  visited : String_set.t;
  maximum_depth : int;
}

type result = {
  environment : Environment.t;
  diagnostics : Diagnostic.t list;
}

val default_maximum_depth :
  int

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val path_key :
  path ->
  string

val path_is_empty :
  path ->
  bool

val path_equal :
  path ->
  path ->
  bool

val path_mem :
  path ->
  path list ->
  bool

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

val create_context :
  ?maximum_depth:int ->
  Environment.t ->
  context

val depth :
  context ->
  int

val current_path :
  context ->
  path option

val push :
  path ->
  context ->
  context

val pop :
  context ->
  context

(* ---------------------------------------------------------- *)
(* Binding conversion                                         *)
(* ---------------------------------------------------------- *)

val source_of_binding_kind :
  Environment.binding_kind ->
  source

val resolved_of_binding :
  path ->
  Environment.binding ->
  resolved

(* ---------------------------------------------------------- *)
(* Direct lookup                                              *)
(* ---------------------------------------------------------- *)

val resolve_direct :
  context ->
  path ->
  resolved

val resolve_direct_opt :
  context ->
  path ->
  resolved option

(* ---------------------------------------------------------- *)
(* Recursive value resolution                                 *)
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

(* ---------------------------------------------------------- *)
(* Dependency analysis                                        *)
(* ---------------------------------------------------------- *)

val value_dependencies :
  Value.t Node.t ->
  path list

val dependencies :
  context ->
  path ->
  path list

val transitive_dependencies :
  context ->
  path ->
  path list

(* ---------------------------------------------------------- *)
(* Environment resolution                                     *)
(* ---------------------------------------------------------- *)

val resolve_binding :
  context ->
  Environment.binding ->
  Environment.binding

val resolve_environment :
  ?maximum_depth:int ->
  Environment.t ->
  Environment.t

(* ---------------------------------------------------------- *)
(* Config resolution                                          *)
(* ---------------------------------------------------------- *)

val resolve_config :
  ?maximum_depth:int ->
  Environment.t ->
  Config.t ->
  Config.t

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val string_of_path :
  path ->
  string

val string_of_cycle :
  path list ->
  string

val string_of_error :
  error ->
  string

val diagnostic_of_error :
  ?span:Node.span ->
  error ->
  Diagnostic.t

val collect_diagnostics :
  ?maximum_depth:int ->
  Environment.t ->
  Diagnostic.t list

val analyze :
  ?maximum_depth:int ->
  Environment.t ->
  result

val has_errors :
  result ->
  bool

val is_valid :
  result ->
  bool

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val string_of_source :
  source ->
  string

val pp_source :
  Format.formatter ->
  source ->
  unit

val pp_resolved :
  Format.formatter ->
  resolved ->
  unit

val pp_error :
  Format.formatter ->
  error ->
  unit

val pp :
  Format.formatter ->
  result ->
  unit