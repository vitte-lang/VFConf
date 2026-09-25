(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/analyzer.mli
 *
 * Public interface for VFConf semantic analysis.
 *)

module String_map : Map.S with type key = String.t
module String_set : Set.S with type elt = String.t

type symbol_kind =
  | Definition
  | Configuration

type symbol = {
  name : string;
  path : Config.path;
  kind : symbol_kind;
  value : Value.t Node.t;
  span : Node.span;
}

type state = {
  symbols : symbol String_map.t;
  definitions : symbol String_map.t;
  schema_fields : String_set.t;
  diagnostics : Diagnostic.t list;
}

type result = {
  document : Statement.t Node.t list;
  symbols : symbol list;
  diagnostics : Diagnostic.t list;
}

val empty_state :
  state

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val path_key :
  Config.path ->
  string

val qualify :
  Config.path ->
  Config.path ->
  Config.path

val definition_key :
  string ->
  string

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val add_diagnostic :
  Diagnostic.t ->
  state ->
  state

val add_error :
  ?span:Node.span ->
  Error.kind ->
  state ->
  state

val duplicate_key :
  Config.path ->
  Node.span ->
  state ->
  state

val duplicate_definition :
  string ->
  Node.span ->
  state ->
  state

val undefined_reference :
  Statement.reference ->
  Node.span ->
  state ->
  state

(* ---------------------------------------------------------- *)
(* Symbols                                                    *)
(* ---------------------------------------------------------- *)

val add_configuration_symbol :
  Config.path ->
  Value.t Node.t ->
  Node.span ->
  state ->
  state

val add_definition_symbol :
  string ->
  Value.t Node.t ->
  Node.span ->
  state ->
  state

val find_configuration_symbol :
  state ->
  Config.path ->
  symbol option

val find_definition_symbol :
  state ->
  string ->
  symbol option

(* ---------------------------------------------------------- *)
(* Reference analysis                                         *)
(* ---------------------------------------------------------- *)

val reference_exists :
  state ->
  Statement.reference ->
  bool

val analyze_value :
  string list ->
  state ->
  Value.t Node.t ->
  state

val analyze_condition :
  string list ->
  state ->
  Statement.condition Node.t ->
  state

(* ---------------------------------------------------------- *)
(* Declaration pass                                           *)
(* ---------------------------------------------------------- *)

val declare_statement :
  Config.path ->
  state ->
  Statement.t Node.t ->
  state

val declare_document :
  Statement.t Node.t list ->
  state

(* ---------------------------------------------------------- *)
(* Reference pass                                             *)
(* ---------------------------------------------------------- *)

val analyze_statement :
  Config.path ->
  state ->
  Statement.t Node.t ->
  state

(* ---------------------------------------------------------- *)
(* Assignment semantics                                       *)
(* ---------------------------------------------------------- *)

val validate_statement :
  Config.path ->
  state ->
  Statement.t Node.t ->
  state

(* ---------------------------------------------------------- *)
(* Analysis                                                   *)
(* ---------------------------------------------------------- *)

val analyze :
  Statement.t Node.t list ->
  result

(* ---------------------------------------------------------- *)
(* Result inspection                                          *)
(* ---------------------------------------------------------- *)

val has_errors :
  result ->
  bool

val is_valid :
  result ->
  bool

val diagnostics :
  result ->
  Diagnostic.t list

val symbols :
  result ->
  symbol list

val document :
  result ->
  Statement.t Node.t list

val find_symbol :
  result ->
  Config.path ->
  symbol option

val find_definition :
  result ->
  string ->
  symbol option

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val string_of_symbol_kind :
  symbol_kind ->
  string

val pp_symbol_kind :
  Format.formatter ->
  symbol_kind ->
  unit

val pp_symbol :
  Format.formatter ->
  symbol ->
  unit

val pp :
  Format.formatter ->
  result ->
  unit