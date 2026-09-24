(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/environment.mli
 *
 * Public interface for the semantic environment.
 *)

module String_map : Map.S with type key = String.t

type binding_kind =
  | Definition
  | Configuration

type binding = {
  name : string;
  path : Config.path;
  kind : binding_kind;
  value : Value.t Node.t;
  span : Node.span;
}

type scope = {
  name : string option;
  bindings : binding String_map.t;
}

type t = {
  scopes : scope list;
}

type error =
  | Duplicate_binding of string
  | Undefined_binding of string
  | Invalid_scope
  | Cannot_pop_root_scope

exception Environment_error of error

(* ---------------------------------------------------------- *)
(* Paths / keys                                               *)
(* ---------------------------------------------------------- *)

val path_key :
  Config.path ->
  string

val key_of_binding :
  binding ->
  string

val key_of_definition :
  string ->
  string

val key_of_configuration :
  Config.path ->
  string

(* ---------------------------------------------------------- *)
(* Scopes                                                     *)
(* ---------------------------------------------------------- *)

val root_scope :
  scope

val empty :
  t

val create :
  unit ->
  t

val depth :
  t ->
  int

val current_scope :
  t ->
  scope

val root :
  t ->
  scope

val push_scope :
  ?name:string ->
  t ->
  t

val pop_scope :
  t ->
  t

val with_scope :
  ?name:string ->
  t ->
  (t -> 'a) ->
  'a

(* ---------------------------------------------------------- *)
(* Binding construction                                       *)
(* ---------------------------------------------------------- *)

val definition :
  name:string ->
  value:Value.t Node.t ->
  span:Node.span ->
  binding

val configuration :
  path:Config.path ->
  value:Value.t Node.t ->
  span:Node.span ->
  binding

(* ---------------------------------------------------------- *)
(* Scope mutation                                             *)
(* ---------------------------------------------------------- *)

val replace_current_scope :
  scope ->
  t ->
  t

val add_binding :
  binding ->
  t ->
  t

val set_binding :
  binding ->
  t ->
  t

val remove_binding :
  string ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Lookup                                                     *)
(* ---------------------------------------------------------- *)

val find_in_scopes :
  string ->
  scope list ->
  binding option

val find_binding :
  t ->
  string ->
  binding option

val find_binding_exn :
  t ->
  string ->
  binding

val mem_binding :
  t ->
  string ->
  bool

val find_definition :
  t ->
  string ->
  binding option

val find_configuration :
  t ->
  Config.path ->
  binding option

val mem_definition :
  t ->
  string ->
  bool

val mem_configuration :
  t ->
  Config.path ->
  bool

(* ---------------------------------------------------------- *)
(* Current-scope lookup                                       *)
(* ---------------------------------------------------------- *)

val find_current :
  t ->
  string ->
  binding option

val mem_current :
  t ->
  string ->
  bool

val find_current_definition :
  t ->
  string ->
  binding option

val find_current_configuration :
  t ->
  Config.path ->
  binding option

(* ---------------------------------------------------------- *)
(* Definitions                                                *)
(* ---------------------------------------------------------- *)

val add_definition :
  name:string ->
  value:Value.t Node.t ->
  span:Node.span ->
  t ->
  t

val set_definition :
  name:string ->
  value:Value.t Node.t ->
  span:Node.span ->
  t ->
  t

val remove_definition :
  string ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Configuration bindings                                     *)
(* ---------------------------------------------------------- *)

val add_configuration :
  path:Config.path ->
  value:Value.t Node.t ->
  span:Node.span ->
  t ->
  t

val set_configuration :
  path:Config.path ->
  value:Value.t Node.t ->
  span:Node.span ->
  t ->
  t

val remove_configuration :
  Config.path ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Enumeration                                                *)
(* ---------------------------------------------------------- *)

val scope_bindings :
  scope ->
  binding list

val current_bindings :
  t ->
  binding list

val bindings :
  t ->
  binding list

val definitions :
  t ->
  binding list

val configurations :
  t ->
  binding list

(* ---------------------------------------------------------- *)
(* Folding / iteration                                        *)
(* ---------------------------------------------------------- *)

val iter :
  (binding -> unit) ->
  t ->
  unit

val fold :
  ('a -> binding -> 'a) ->
  t ->
  'a ->
  'a

(* ---------------------------------------------------------- *)
(* Import                                                     *)
(* ---------------------------------------------------------- *)

val of_config :
  Config.t ->
  t

val add_config :
  Config.t ->
  t ->
  t

val of_analyzer_result :
  Analyzer.result ->
  t

(* ---------------------------------------------------------- *)
(* Resolution                                                 *)
(* ---------------------------------------------------------- *)

val resolve_reference :
  t ->
  Statement.reference ->
  binding option

val resolve_reference_exn :
  t ->
  Statement.reference ->
  binding

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val string_of_binding_kind :
  binding_kind ->
  string

val string_of_error :
  error ->
  string

val pp_binding_kind :
  Format.formatter ->
  binding_kind ->
  unit

val pp_binding :
  Format.formatter ->
  binding ->
  unit

val pp_scope :
  Format.formatter ->
  scope ->
  unit

val pp_error :
  Format.formatter ->
  error ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit