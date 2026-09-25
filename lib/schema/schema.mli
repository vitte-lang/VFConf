(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/schema/schema.mli
 *
 * Public interface for schema definition, composition
 * and configuration validation.
 *)

module String_map : Map.S with type key = String.t

type path = Config.path

type section = {
  path : path;
  description : string option;
  fields : Field.t String_map.t;
  allow_unknown_fields : bool;
}

type t = {
  name : string;
  version : string option;
  description : string option;
  sections : section String_map.t;
  rules : Rule.t list;
  allow_unknown_sections : bool;
}

type validation_result = {
  config : Config.t;
  violations : Rule.violation list;
  diagnostics : Diagnostic.t list;
}

type error =
  | Duplicate_section of path
  | Duplicate_field of {
      section : path;
      field : string;
    }
  | Unknown_section of path
  | Unknown_field of {
      section : path;
      field : string;
    }
  | Invalid_schema of string

exception Schema_error of error

val diagnostic_of_error :
  error ->
  Diagnostic.t

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

val root_key :
  string

val path_key :
  path ->
  string

val field_path :
  path ->
  string ->
  path

val split_field_path :
  path ->
  (path * string) option

val path_starts_with :
  path ->
  path ->
  bool

(* ---------------------------------------------------------- *)
(* Sections                                                   *)
(* ---------------------------------------------------------- *)

val make_section :
  ?description:string ->
  ?allow_unknown_fields:bool ->
  path ->
  section

val section_path :
  section ->
  path

val section_description :
  section ->
  string option

val section_allows_unknown_fields :
  section ->
  bool

val section_fields :
  section ->
  Field.t list

val find_field :
  section ->
  string ->
  Field.t option

val mem_field :
  section ->
  string ->
  bool

val add_field :
  Field.t ->
  section ->
  section

val add_fields :
  Field.t list ->
  section ->
  section

val set_field :
  Field.t ->
  section ->
  section

val remove_field :
  string ->
  section ->
  section

val with_unknown_fields :
  bool ->
  section ->
  section

val with_section_description :
  string ->
  section ->
  section

(* ---------------------------------------------------------- *)
(* Schema construction                                        *)
(* ---------------------------------------------------------- *)

val make :
  ?version:string ->
  ?description:string ->
  ?allow_unknown_sections:bool ->
  string ->
  t

val empty :
  t

val name :
  t ->
  string

val version :
  t ->
  string option

val description :
  t ->
  string option

val allows_unknown_sections :
  t ->
  bool

val with_version :
  string ->
  t ->
  t

val with_description :
  string ->
  t ->
  t

val with_unknown_sections :
  bool ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Schema sections                                            *)
(* ---------------------------------------------------------- *)

val find_section :
  t ->
  path ->
  section option

val mem_section :
  t ->
  path ->
  bool

val sections :
  t ->
  section list

val add_section :
  section ->
  t ->
  t

val add_sections :
  section list ->
  t ->
  t

val set_section :
  section ->
  t ->
  t

val remove_section :
  path ->
  t ->
  t

val ensure_section :
  path ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Schema fields                                              *)
(* ---------------------------------------------------------- *)

val find_schema_field :
  t ->
  path ->
  Field.t option

val mem_schema_field :
  t ->
  path ->
  bool

val add_schema_field :
  path ->
  Field.t ->
  t ->
  t

val set_schema_field :
  path ->
  Field.t ->
  t ->
  t

val remove_schema_field :
  path ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Rules                                                      *)
(* ---------------------------------------------------------- *)

val rules :
  t ->
  Rule.t list

val add_rule :
  Rule.t ->
  t ->
  t

val add_rules :
  Rule.t list ->
  t ->
  t

val clear_rules :
  t ->
  t

(* ---------------------------------------------------------- *)
(* Field validation                                           *)
(* ---------------------------------------------------------- *)

val violation_of_field_error :
  path ->
  Node.span option ->
  Field.validation_error ->
  Rule.violation

val validate_field :
  Config.t ->
  section ->
  Field.t ->
  Rule.violation list

val validate_section_fields :
  Config.t ->
  section ->
  Rule.violation list

(* ---------------------------------------------------------- *)
(* Unknown path validation                                    *)
(* ---------------------------------------------------------- *)

val section_for_entry :
  t ->
  Config.entry ->
  section option

val relative_field_name :
  section ->
  Config.entry ->
  string option

val unknown_entry_violation :
  t ->
  Config.entry ->
  Rule.violation option

val validate_unknown_entries :
  t ->
  Config.t ->
  Rule.violation list

(* ---------------------------------------------------------- *)
(* Defaults                                                   *)
(* ---------------------------------------------------------- *)

val apply_field_default :
  section ->
  Config.t ->
  Field.t ->
  Config.t

val apply_section_defaults :
  section ->
  Config.t ->
  Config.t

val apply_defaults :
  t ->
  Config.t ->
  Config.t

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

val validate_without_defaults :
  t ->
  Config.t ->
  validation_result

val validate :
  t ->
  Config.t ->
  validation_result

val is_valid :
  t ->
  Config.t ->
  bool

val violations :
  t ->
  Config.t ->
  Rule.violation list

val diagnostics :
  t ->
  Config.t ->
  Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Schema validation                                          *)
(* ---------------------------------------------------------- *)

val validate_field_definition :
  section ->
  Field.t ->
  error list

val validate_definition :
  t ->
  error list

val definition_is_valid :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Composition                                                *)
(* ---------------------------------------------------------- *)

val merge_section :
  section ->
  section ->
  section

val merge :
  t ->
  t ->
  t

val merge_many :
  t list ->
  t

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
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_section :
  Format.formatter ->
  section ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit