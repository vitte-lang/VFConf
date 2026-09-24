(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/diagnostic.mli
 *
 * Public interface for canonical VFConf diagnostics.
 *)

type severity =
  | Error
  | Warning
  | Information
  | Hint

type code = string

type category =
  | Lexical
  | Syntax
  | Semantic
  | Configuration
  | Include
  | Reference
  | Type
  | Schema
  | Evaluation
  | Formatting
  | Style
  | Compatibility
  | Deprecation
  | Io
  | Internal

type source =
  | Lexer
  | Parser
  | Analyzer
  | Resolver
  | Validator
  | Loader
  | Schema_validator
  | Evaluator
  | Formatter
  | Cli
  | Other of string

type applicability =
  | Machine_applicable
  | Maybe_incorrect
  | Has_placeholders
  | Unspecified

type related = {
  span : Node.span;
  message : string;
}

type label = {
  span : Node.span;
  message : string option;
  primary : bool;
}

type note = string

type fix = {
  span : Node.span;
  replacement : string;
  message : string option;
  applicability : applicability;
}

type t = {
  severity : severity;
  code : code option;
  message : string;
  span : Node.span option;
  labels : label list;
  notes : note list;
  fixes : fix list;

  category : category option;
  source : source option;
  help : string list;
  related : related list;
}

(* ---------------------------------------------------------- *)
(* Severity                                                   *)
(* ---------------------------------------------------------- *)

val severity_rank :
  severity ->
  int

val compare_severity :
  severity ->
  severity ->
  int

val string_of_severity :
  severity ->
  string

val short_string_of_severity :
  severity ->
  string

val severity_of_string :
  string ->
  severity option

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val make :
  ?code:code ->
  ?span:Node.span ->
  ?category:category ->
  ?source:source ->
  ?help:string list ->
  ?related:related list ->
  ?labels:label list ->
  ?notes:note list ->
  ?fixes:fix list ->
  severity ->
  string ->
  t

val error :
  ?code:code ->
  ?span:Node.span ->
  ?labels:label list ->
  ?notes:note list ->
  ?fixes:fix list ->
  string ->
  t

val warning :
  ?code:code ->
  ?span:Node.span ->
  ?labels:label list ->
  ?notes:note list ->
  ?fixes:fix list ->
  string ->
  t

val information :
  ?code:code ->
  ?span:Node.span ->
  ?labels:label list ->
  ?notes:note list ->
  ?fixes:fix list ->
  string ->
  t

val hint :
  ?code:code ->
  ?span:Node.span ->
  ?labels:label list ->
  ?notes:note list ->
  ?fixes:fix list ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Labels                                                     *)
(* ---------------------------------------------------------- *)

val label :
  ?message:string ->
  ?primary:bool ->
  Node.span ->
  label

val primary_label :
  ?message:string ->
  Node.span ->
  label

val secondary_label :
  ?message:string ->
  Node.span ->
  label

val add_label :
  label ->
  t ->
  t

val add_primary_label :
  ?message:string ->
  Node.span ->
  t ->
  t

val add_secondary_label :
  ?message:string ->
  Node.span ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Notes                                                      *)
(* ---------------------------------------------------------- *)

val add_note :
  note ->
  t ->
  t

val add_notes :
  note list ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Fixes                                                      *)
(* ---------------------------------------------------------- *)

val fix :
  ?message:string ->
  ?applicability:applicability ->
  Node.span ->
  string ->
  fix

val add_fix :
  fix ->
  t ->
  t

val add_replacement :
  ?message:string ->
  Node.span ->
  string ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Mutation-style helpers                                     *)
(* ---------------------------------------------------------- *)

val with_code :
  code ->
  t ->
  t

val without_code :
  t ->
  t

val with_span :
  Node.span ->
  t ->
  t

val without_span :
  t ->
  t

val with_severity :
  severity ->
  t ->
  t

val with_message :
  string ->
  t ->
  t


(* ---------------------------------------------------------- *)
(* Extended diagnostic metadata                               *)
(* ---------------------------------------------------------- *)

val with_category :
  category ->
  t ->
  t

val with_source :
  source ->
  t ->
  t

val add_help :
  string ->
  t ->
  t

val add_related :
  Node.span ->
  string ->
  t ->
  t

val string_of_category :
  category ->
  string

val string_of_source :
  source ->
  string

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

val is_error :
  t ->
  bool

val is_warning :
  t ->
  bool

val is_information :
  t ->
  bool

val is_hint :
  t ->
  bool

val has_code :
  t ->
  bool

val has_span :
  t ->
  bool

val has_fixes :
  t ->
  bool

val primary_span :
  t ->
  Node.span option

val filename :
  t ->
  string option

(* ---------------------------------------------------------- *)
(* Ordering                                                   *)
(* ---------------------------------------------------------- *)

val compare_position :
  Node.span ->
  Node.span ->
  int

val compare :
  t ->
  t ->
  int

val sort :
  t list ->
  t list

(* ---------------------------------------------------------- *)
(* Counting                                                   *)
(* ---------------------------------------------------------- *)

val count_severity :
  severity ->
  t list ->
  int

val error_count :
  t list ->
  int

val warning_count :
  t list ->
  int

val information_count :
  t list ->
  int

val hint_count :
  t list ->
  int

val has_errors :
  t list ->
  bool

val has_warnings :
  t list ->
  bool

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_code :
  Format.formatter ->
  code option ->
  unit

val pp_header :
  Format.formatter ->
  t ->
  unit

val pp_location :
  Format.formatter ->
  Node.span ->
  unit

val pp_label :
  Format.formatter ->
  label ->
  unit

val pp_fix :
  Format.formatter ->
  fix ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit

val to_string :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Collection printing                                        *)
(* ---------------------------------------------------------- *)

val pp_all :
  Format.formatter ->
  t list ->
  unit

val all_to_string :
  t list ->
  string