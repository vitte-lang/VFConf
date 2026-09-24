(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/error.mli
 *
 * Public interface for canonical VFConf errors.
 *)

type category =
  | Lexical
  | Syntax
  | Semantic
  | Configuration
  | Include
  | Schema
  | Evaluation
  | Io
  | Internal

type kind =
  | Unexpected_character of char
  | Invalid_token of string
  | Unterminated_string
  | Unterminated_comment
  | Invalid_escape of string
  | Invalid_number of string
  | Invalid_color of string
  | Invalid_duration of string
  | Invalid_size of string
  | Unexpected_token of string
  | Expected_token of {
      expected : string;
      found : string option;
    }
  | Unexpected_end_of_file
  | Duplicate_key of string
  | Undefined_reference of string
  | Invalid_reference of string
  | Type_mismatch of {
      expected : string;
      found : string;
    }
  | Invalid_assignment of {
      key : string;
      operator : string;
    }
  | Invalid_value of string
  | Invalid_condition of string
  | Include_not_found of string
  | Include_cycle of string list
  | Include_depth_exceeded of {
      maximum : int;
      path : string;
    }
  | Invalid_include of string
  | Schema_violation of string
  | Missing_required_field of string
  | Unknown_field of string
  | Evaluation_failed of string
  | Division_by_zero
  | File_not_found of string
  | Cannot_read_file of {
      path : string;
      message : string;
    }
  | Internal_error of string

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

val message_of_kind :
  kind ->
  string

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val category_of_kind :
  kind ->
  category

val make :
  ?span:Node.span ->
  kind ->
  t

(* ---------------------------------------------------------- *)
(* Conversion to canonical diagnostic                         *)
(* ---------------------------------------------------------- *)

val to_diagnostic :
  t ->
  Diagnostic.t

val to_diagnostic_with_notes :
  ?notes:string list ->
  t ->
  Diagnostic.t

(* ---------------------------------------------------------- *)
(* Lexical errors                                             *)
(* ---------------------------------------------------------- *)

val unexpected_character :
  ?span:Node.span ->
  char ->
  t

val invalid_token :
  ?span:Node.span ->
  string ->
  t

val unterminated_string :
  ?span:Node.span ->
  unit ->
  t

val unterminated_comment :
  ?span:Node.span ->
  unit ->
  t

val invalid_escape :
  ?span:Node.span ->
  string ->
  t

val invalid_number :
  ?span:Node.span ->
  string ->
  t

val invalid_color :
  ?span:Node.span ->
  string ->
  t

val invalid_duration :
  ?span:Node.span ->
  string ->
  t

val invalid_size :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Syntax errors                                              *)
(* ---------------------------------------------------------- *)

val unexpected_token :
  ?span:Node.span ->
  string ->
  t

val expected_token :
  ?span:Node.span ->
  ?found:string ->
  string ->
  t

val unexpected_end_of_file :
  ?span:Node.span ->
  unit ->
  t

(* ---------------------------------------------------------- *)
(* Semantic errors                                            *)
(* ---------------------------------------------------------- *)

val duplicate_key :
  ?span:Node.span ->
  string ->
  t

val undefined_reference :
  ?span:Node.span ->
  string ->
  t

val invalid_reference :
  ?span:Node.span ->
  string ->
  t

val type_mismatch :
  ?span:Node.span ->
  expected:string ->
  found:string ->
  unit ->
  t

val invalid_assignment :
  ?span:Node.span ->
  key:string ->
  operator:string ->
  unit ->
  t

val invalid_value :
  ?span:Node.span ->
  string ->
  t

val invalid_condition :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Include errors                                             *)
(* ---------------------------------------------------------- *)

val include_not_found :
  ?span:Node.span ->
  string ->
  t

val include_cycle :
  ?span:Node.span ->
  string list ->
  t

val include_depth_exceeded :
  ?span:Node.span ->
  maximum:int ->
  string ->
  t

val invalid_include :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Schema errors                                              *)
(* ---------------------------------------------------------- *)

val schema_violation :
  ?span:Node.span ->
  string ->
  t

val missing_required_field :
  ?span:Node.span ->
  string ->
  t

val unknown_field :
  ?span:Node.span ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Evaluation errors                                          *)
(* ---------------------------------------------------------- *)

val evaluation_failed :
  ?span:Node.span ->
  string ->
  t

val division_by_zero :
  ?span:Node.span ->
  unit ->
  t

(* ---------------------------------------------------------- *)
(* I/O errors                                                 *)
(* ---------------------------------------------------------- *)

val file_not_found :
  ?span:Node.span ->
  string ->
  t

val cannot_read_file :
  ?span:Node.span ->
  path:string ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Internal errors                                            *)
(* ---------------------------------------------------------- *)

val internal_error :
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