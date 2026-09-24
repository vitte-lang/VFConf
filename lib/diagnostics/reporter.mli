(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/reporter.mli
 *
 * Public interface for diagnostic collection and reporting.
 *)

type format =
  | Human
  | Compact
  | Json

type options = {
  format : format;
  show_codes : bool;
  show_notes : bool;
  show_fixes : bool;
  sort : bool;
  warnings_as_errors : bool;
}

type t

val default_options : options

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val create :
  ?options:options ->
  unit ->
  t

val clear :
  t ->
  unit

val options :
  t ->
  options

(* ---------------------------------------------------------- *)
(* Collection                                                 *)
(* ---------------------------------------------------------- *)

val emit :
  t ->
  Diagnostic.t ->
  unit

val emit_many :
  t ->
  Diagnostic.t list ->
  unit

val emit_error :
  t ->
  Error.t ->
  unit

val diagnostics :
  t ->
  Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

val count :
  t ->
  int

val is_empty :
  t ->
  bool

val error_count :
  t ->
  int

val warning_count :
  t ->
  int

val information_count :
  t ->
  int

val hint_count :
  t ->
  int

val has_errors :
  t ->
  bool

val has_warnings :
  t ->
  bool

val exit_code :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Filtering                                                  *)
(* ---------------------------------------------------------- *)

val filter :
  Diagnostic.severity ->
  t ->
  Diagnostic.t list

val errors :
  t ->
  Diagnostic.t list

val warnings :
  t ->
  Diagnostic.t list

val informations :
  t ->
  Diagnostic.t list

val hints :
  t ->
  Diagnostic.t list

(* ---------------------------------------------------------- *)
(* JSON helpers                                               *)
(* ---------------------------------------------------------- *)

val escape_json :
  string ->
  string

val json_string :
  string ->
  string

val json_option :
  ('a -> string) ->
  'a option ->
  string

val json_position :
  Node.position ->
  string

val json_span :
  Node.span ->
  string

val json_label :
  Diagnostic.label ->
  string

val json_fix :
  Diagnostic.fix ->
  string

val json_list :
  ('a -> string) ->
  'a list ->
  string

val diagnostic_to_json :
  Diagnostic.t ->
  string

(* ---------------------------------------------------------- *)
(* Diagnostic formatting                                      *)
(* ---------------------------------------------------------- *)

val pp_compact :
  Format.formatter ->
  Diagnostic.t ->
  unit

val pp_human :
  options ->
  Format.formatter ->
  Diagnostic.t ->
  unit

val pp_diagnostic :
  options ->
  Format.formatter ->
  Diagnostic.t ->
  unit

(* ---------------------------------------------------------- *)
(* Reporter formatting                                        *)
(* ---------------------------------------------------------- *)

val pp :
  t ->
  Format.formatter ->
  unit

val to_string :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Output                                                     *)
(* ---------------------------------------------------------- *)

val print :
  t ->
  unit

val print_error :
  t ->
  unit

(* ---------------------------------------------------------- *)
(* Summary                                                    *)
(* ---------------------------------------------------------- *)

val pp_summary :
  t ->
  Format.formatter ->
  unit

val summary :
  t ->
  string