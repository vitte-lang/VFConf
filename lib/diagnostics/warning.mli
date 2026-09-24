(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/warning.mli
 *
 * Public interface for canonical VFConf warnings.
 *)

type category =
  | Semantic
  | Configuration
  | Include
  | Schema
  | Evaluation
  | Style
  | Compatibility
  | Deprecation

type kind =
  | Duplicate_definition of string
  | Shadowed_definition of string
  | Unused_definition of string
  | Unused_section of string
  | Unused_value of string
  | Redundant_assignment of string
  | Overwritten_value of string
  | Empty_section of string
  | Empty_array of string
  | Empty_object of string
  | Deprecated_key of {
      key : string;
      replacement : string option;
    }
  | Deprecated_value of {
      value : string;
      replacement : string option;
    }
  | Deprecated_syntax of {
      syntax : string;
      replacement : string option;
    }
  | Unknown_key of string
  | Unknown_section of string
  | Suspicious_value of {
      key : string option;
      value : string;
    }
  | Implicit_conversion of {
      from_type : string;
      to_type : string;
    }
  | Include_repeated of string
  | Include_outside_root of string
  | Schema_default_used of string
  | Schema_additional_field of string
  | Condition_always_true
  | Condition_always_false
  | Unreachable_configuration
  | Non_canonical_boolean of string
  | Non_canonical_size of string
  | Non_canonical_duration of string
  | Non_canonical_color of string
  | Compatibility_issue of string
  | Style_issue of string

type t = {
  category : category;
  kind : kind;
  span : Node.span option;
}

(* ---------------------------------------------------------- *)
(* Categories                                                 *)
(* ---------------------------------------------------------- *)

val string_of_category :
  category ->
  string

(* ---------------------------------------------------------- *)
(* Diagnostic codes                                           *)
(* ---------------------------------------------------------- *)

val code_of_kind :
  kind ->
  string

(* ---------------------------------------------------------- *)
(* Messages                                                   *)
(* ---------------------------------------------------------- *)

val replacement_suffix :
  string option ->
  string

val message_of_kind :
  kind ->
  string

(* ---------------------------------------------------------- *)
(* Category inference                                         *)
(* ---------------------------------------------------------- *)

val category_of_kind :
  kind ->
  category

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val make :
  ?span:Node.span ->
  kind ->
  t

(* ---------------------------------------------------------- *)
(* Diagnostic conversion                                      *)
(* ---------------------------------------------------------- *)

val to_diagnostic :
  t ->
  Diagnostic.t

val to_diagnostic_with_notes :
  ?notes:string list ->
  t ->
  Diagnostic.t

val to_diagnostic_with_fix :
  ?message:string ->
  span:Node.span ->
  replacement:string ->
  t ->
  Diagnostic.t

(* ---------------------------------------------------------- *)
(* Semantic constructors                                      *)
(* ---------------------------------------------------------- *)

val duplicate_definition :
  ?span:Node.span ->
  string ->
  t

val shadowed_definition :
  ?span:Node.span ->
  string ->
  t

val unused_definition :
  ?span:Node.span ->
  string ->
  t

val unused_section :
  ?span:Node.span ->
  string ->
  t

val unused_value :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Configuration constructors                                 *)
(* ---------------------------------------------------------- *)

val redundant_assignment :
  ?span:Node.span ->
  string ->
  t

val overwritten_value :
  ?span:Node.span ->
  string ->
  t

val empty_section :
  ?span:Node.span ->
  string ->
  t

val empty_array :
  ?span:Node.span ->
  string ->
  t

val empty_object :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Deprecation constructors                                   *)
(* ---------------------------------------------------------- *)

val deprecated_key :
  ?span:Node.span ->
  ?replacement:string ->
  string ->
  t

val deprecated_value :
  ?span:Node.span ->
  ?replacement:string ->
  string ->
  t

val deprecated_syntax :
  ?span:Node.span ->
  ?replacement:string ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Schema constructors                                        *)
(* ---------------------------------------------------------- *)

val unknown_key :
  ?span:Node.span ->
  string ->
  t

val unknown_section :
  ?span:Node.span ->
  string ->
  t

val suspicious_value :
  ?span:Node.span ->
  ?key:string ->
  string ->
  t

val schema_default_used :
  ?span:Node.span ->
  string ->
  t

val schema_additional_field :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Evaluation constructors                                    *)
(* ---------------------------------------------------------- *)

val implicit_conversion :
  ?span:Node.span ->
  from_type:string ->
  to_type:string ->
  unit ->
  t

val condition_always_true :
  ?span:Node.span ->
  unit ->
  t

val condition_always_false :
  ?span:Node.span ->
  unit ->
  t

val unreachable_configuration :
  ?span:Node.span ->
  unit ->
  t

(* ---------------------------------------------------------- *)
(* Include constructors                                       *)
(* ---------------------------------------------------------- *)

val include_repeated :
  ?span:Node.span ->
  string ->
  t

val include_outside_root :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Style constructors                                         *)
(* ---------------------------------------------------------- *)

val non_canonical_boolean :
  ?span:Node.span ->
  string ->
  t

val non_canonical_size :
  ?span:Node.span ->
  string ->
  t

val non_canonical_duration :
  ?span:Node.span ->
  string ->
  t

val non_canonical_color :
  ?span:Node.span ->
  string ->
  t

val style_issue :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Compatibility constructors                                 *)
(* ---------------------------------------------------------- *)

val compatibility_issue :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

val code :
  t ->
  string

val message :
  t ->
  string

val category :
  t ->
  category

val span :
  t ->
  Node.span option

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp :
  Format.formatter ->
  t ->
  unit

val to_string :
  t ->
  string