(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/loader.mli
 *
 * Public interface for the VFConf configuration loader.
 *)

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

type error =
  | Io_error of {
      filename : string;
      message : string;
    }
  | Lexing_error of {
      filename : string;
      line : int;
      column : int;
      message : string;
    }
  | Parsing_error of {
      filename : string;
      line : int;
      column : int;
      message : string;
    }
  | Include_error of Include.error
  | Duplicate_key of Config.path
  | Invalid_assignment of {
      path : Config.path;
      operator : Statement.assignment_operator;
    }
  | Unsupported_statement of string

exception Load_error of error

(* ---------------------------------------------------------- *)
(* Result                                                     *)
(* ---------------------------------------------------------- *)

type result = {
  config : Config.t;
  files : string list;
}

(* ---------------------------------------------------------- *)
(* Position helpers                                           *)
(* ---------------------------------------------------------- *)

val line_column_of_lexbuf :
  Lexing.lexbuf ->
  int * int

val initialize_lexbuf :
  string ->
  string ->
  Lexing.lexbuf

(* ---------------------------------------------------------- *)
(* File reading                                               *)
(* ---------------------------------------------------------- *)

val read_file :
  string ->
  string

(* ---------------------------------------------------------- *)
(* Parsing                                                    *)
(* ---------------------------------------------------------- *)

val parse_source :
  filename:string ->
  string ->
  Statement.t Node.t list

val parse_file :
  string ->
  Statement.t Node.t list

(* ---------------------------------------------------------- *)
(* Value operations                                           *)
(* ---------------------------------------------------------- *)

val append_values :
  Value.t Node.t ->
  Value.t Node.t ->
  Value.t Node.t option

val subtract_values :
  Value.t Node.t ->
  Value.t Node.t ->
  Value.t Node.t option

(* ---------------------------------------------------------- *)
(* Assignment application                                     *)
(* ---------------------------------------------------------- *)

val apply_assignment :
  Config.t ->
  Config.path ->
  Statement.assignment_operator ->
  Value.t Node.t ->
  Config.t

(* ---------------------------------------------------------- *)
(* Condition evaluation                                       *)
(* ---------------------------------------------------------- *)

val compare_values :
  Statement.comparison_operator ->
  Value.t ->
  Value.t ->
  bool

val evaluate_condition :
  Config.path ->
  Config.t ->
  Statement.condition Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Statement loading                                          *)
(* ---------------------------------------------------------- *)

val load_statements :
  Include.context ->
  Config.path ->
  Config.t ->
  string list ->
  Statement.t Node.t list ->
  Config.t * string list

val load_statement :
  Include.context ->
  Config.path ->
  Config.t ->
  string list ->
  Statement.t Node.t ->
  Config.t * string list

(* ---------------------------------------------------------- *)
(* Document loading                                           *)
(* ---------------------------------------------------------- *)

val load_document :
  ?filename:string ->
  Statement.t Node.t list ->
  result

(* ---------------------------------------------------------- *)
(* Source loading                                             *)
(* ---------------------------------------------------------- *)

val load_source :
  ?filename:string ->
  string ->
  result

(* ---------------------------------------------------------- *)
(* File loading                                               *)
(* ---------------------------------------------------------- *)

val load_file :
  string ->
  result

(* ---------------------------------------------------------- *)
(* Convenience API                                            *)
(* ---------------------------------------------------------- *)

val config_of_file :
  string ->
  Config.t

val config_of_source :
  ?filename:string ->
  string ->
  Config.t

val files :
  result ->
  string list

val config :
  result ->
  Config.t

(* ---------------------------------------------------------- *)
(* Canonical diagnostics                                      *)
(* ---------------------------------------------------------- *)

val diagnostic_of_include_error :
  Include.error ->
  Diagnostic.t

val diagnostic_of_error :
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

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

val dump_result :
  Format.formatter ->
  result ->
  unit