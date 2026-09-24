(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/validator.mli
 *
 * Public interface for the high-level semantic validation pipeline.
 *)

type options = {
  resolve_references : bool;
  validate_schema : bool;
  allow_warnings : bool;
  maximum_reference_depth : int;
}

type result = {
  document : Statement.t Node.t list;
  config : Config.t option;
  environment : Environment.t;
  diagnostics : Diagnostic.t list;
}

type error =
  | Semantic_analysis_failed
  | Reference_resolution_failed
  | Schema_validation_failed
  | Configuration_unavailable

exception Validation_error of error

val default_options :
  options

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val is_error :
  Diagnostic.t ->
  bool

val is_warning :
  Diagnostic.t ->
  bool

val errors :
  Diagnostic.t list ->
  Diagnostic.t list

val warnings :
  Diagnostic.t list ->
  Diagnostic.t list

val has_errors :
  Diagnostic.t list ->
  bool

val has_warnings :
  Diagnostic.t list ->
  bool

val diagnostic_equal :
  Diagnostic.t ->
  Diagnostic.t ->
  bool

val unique_diagnostics :
  Diagnostic.t list ->
  Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Configuration construction                                 *)
(* ---------------------------------------------------------- *)

val config_of_environment :
  Environment.t ->
  Config.t

val config_of_analyzer_result :
  Analyzer.result ->
  Config.t

(* ---------------------------------------------------------- *)
(* Semantic analysis                                          *)
(* ---------------------------------------------------------- *)

val analyze_document :
  Statement.t Node.t list ->
  Analyzer.result * Environment.t

(* ---------------------------------------------------------- *)
(* Reference resolution                                       *)
(* ---------------------------------------------------------- *)

val resolve_environment :
  options ->
  Environment.t ->
  Environment.t * Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Schema validation                                          *)
(* ---------------------------------------------------------- *)

val validate_schema :
  options ->
  Schema.t option ->
  Config.t ->
  Config.t * Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Pipeline                                                   *)
(* ---------------------------------------------------------- *)

val validate :
  ?options:options ->
  ?schema:Schema.t ->
  Statement.t Node.t list ->
  result

val validate_config :
  ?options:options ->
  ?schema:Schema.t ->
  Config.t ->
  result

(* ---------------------------------------------------------- *)
(* Result inspection                                          *)
(* ---------------------------------------------------------- *)

val diagnostics :
  result ->
  Diagnostic.t list

val config :
  result ->
  Config.t option

val environment :
  result ->
  Environment.t

val document :
  result ->
  Statement.t Node.t list

val result_errors :
  result ->
  Diagnostic.t list

val result_warnings :
  result ->
  Diagnostic.t list

val error_count :
  result ->
  int

val warning_count :
  result ->
  int

val result_has_errors :
  result ->
  bool

val result_has_warnings :
  result ->
  bool

val is_valid :
  ?allow_warnings:bool ->
  result ->
  bool

val config_exn :
  result ->
  Config.t

(* ---------------------------------------------------------- *)
(* Option helpers                                             *)
(* ---------------------------------------------------------- *)

val with_reference_resolution :
  bool ->
  options ->
  options

val with_schema_validation :
  bool ->
  options ->
  options

val with_warnings :
  bool ->
  options ->
  options

val with_maximum_reference_depth :
  int ->
  options ->
  options

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
(* Result formatting                                          *)
(* ---------------------------------------------------------- *)

val pp_summary :
  Format.formatter ->
  result ->
  unit

val pp :
  Format.formatter ->
  result ->
  unit