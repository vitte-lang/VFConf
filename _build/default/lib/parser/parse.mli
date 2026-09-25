(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/parser/parse.mli
 *
 * Public high-level parsing interface.
 *)

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

type io_error_kind =
  | File_not_found
  | Cannot_read_file

type error_kind =
  | Lexical_error of Lexer.error_kind
  | Syntax_error
  | Io_error of io_error_kind

type error = {
  kind : error_kind;
  filename : string;
  line : int;
  column : int;
  offset : int;
  message : string;
  span : Node.span;
}

exception Parse_error of error

type document = Statement.t Node.t list

(* ---------------------------------------------------------- *)
(* Position / span conversion                                 *)
(* ---------------------------------------------------------- *)

val node_position_of_lexing_position :
  Lexing.position ->
  Node.position

val span_of_lexing_positions :
  filename:string ->
  Lexing.position ->
  Lexing.position ->
  Node.span

val error_of_positions :
  kind:error_kind ->
  filename:string ->
  message:string ->
  Lexing.position ->
  Lexing.position ->
  error

val initial_span :
  string ->
  Node.span

(* ---------------------------------------------------------- *)
(* Lexbuf setup                                               *)
(* ---------------------------------------------------------- *)

val initialize_lexbuf :
  filename:string ->
  Lexing.lexbuf ->
  unit

val lexbuf_from_string :
  filename:string ->
  string ->
  Lexing.lexbuf

val lexbuf_from_channel :
  filename:string ->
  in_channel ->
  Lexing.lexbuf

(* ---------------------------------------------------------- *)
(* Error messages                                             *)
(* ---------------------------------------------------------- *)

val string_of_error_kind :
  error_kind ->
  string

val parser_error_message :
  Lexing.lexbuf ->
  string

(* ---------------------------------------------------------- *)
(* Core parser                                                *)
(* ---------------------------------------------------------- *)

val parse_lexbuf :
  filename:string ->
  Lexing.lexbuf ->
  document

(* ---------------------------------------------------------- *)
(* String parsing                                             *)
(* ---------------------------------------------------------- *)

val string :
  ?filename:string ->
  string ->
  document

val from_string :
  ?filename:string ->
  string ->
  document

(* ---------------------------------------------------------- *)
(* Channel parsing                                            *)
(* ---------------------------------------------------------- *)

val channel :
  ?filename:string ->
  in_channel ->
  document

val from_channel :
  ?filename:string ->
  in_channel ->
  document

(* ---------------------------------------------------------- *)
(* File parsing                                               *)
(* ---------------------------------------------------------- *)

val file :
  string ->
  document

val from_file :
  string ->
  document

(* ---------------------------------------------------------- *)
(* Safe parsing                                               *)
(* ---------------------------------------------------------- *)

val string_result :
  ?filename:string ->
  string ->
  (document, error) result

val channel_result :
  ?filename:string ->
  in_channel ->
  (document, error) result

val file_result :
  string ->
  (document, error) result

(* ---------------------------------------------------------- *)
(* Validation helpers                                         *)
(* ---------------------------------------------------------- *)

val is_valid_string :
  ?filename:string ->
  string ->
  bool

val is_valid_file :
  string ->
  bool

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val diagnostic_of_error :
  error ->
  Diagnostic.t

val parse_with_diagnostics :
  ?filename:string ->
  string ->
  (document, Diagnostic.t list) result

val file_with_diagnostics :
  string ->
  (document, Diagnostic.t list) result

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

val pp_document :
  Format.formatter ->
  document ->
  unit