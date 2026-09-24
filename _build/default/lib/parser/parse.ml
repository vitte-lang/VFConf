(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/parser/parse.ml
 *
 * High-level parsing entry points.
 *
 * This module connects:
 *   source -> Lexing.lexbuf -> Lexer -> Menhir Parser -> AST
 *
 * It also normalizes lexer/parser failures into a stable VFConf
 * parsing error representation.
 *)

type error_kind =
  | Lexical_error
  | Syntax_error

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

let node_position_of_lexing_position
    (position : Lexing.position) : Node.position =
  {
    offset = position.Lexing.pos_cnum;
    line = position.Lexing.pos_lnum;
    column =
      position.Lexing.pos_cnum
      - position.Lexing.pos_bol;
  }

let span_of_lexing_positions
    ~filename
    start_position
    end_position =
  Node.span
    ~filename
    (node_position_of_lexing_position start_position)
    (node_position_of_lexing_position end_position)

let error_of_positions
    ~kind
    ~filename
    ~message
    start_position
    end_position =
  let start =
    node_position_of_lexing_position start_position
  in

  {
    kind;
    filename;
    line = start.Node.line;
    column = start.Node.column;
    offset = start.Node.offset;
    message;
    span =
      span_of_lexing_positions
        ~filename
        start_position
        end_position;
  }

(* ---------------------------------------------------------- *)
(* Lexbuf setup                                               *)
(* ---------------------------------------------------------- *)

let initialize_lexbuf
    ~filename
    lexbuf =

  lexbuf.Lexing.lex_curr_p <-
    {
      Lexing.pos_fname = filename;
      pos_lnum = 1;
      pos_bol = 0;
      pos_cnum = 0;
    }

let lexbuf_from_string
    ~filename
    source =
  let lexbuf =
    Lexing.from_string source
  in

  initialize_lexbuf
    ~filename
    lexbuf;

  lexbuf

let lexbuf_from_channel
    ~filename
    channel =
  let lexbuf =
    Lexing.from_channel channel
  in

  initialize_lexbuf
    ~filename
    lexbuf;

  lexbuf

(* ---------------------------------------------------------- *)
(* Error messages                                             *)
(* ---------------------------------------------------------- *)

let string_of_error_kind = function
  | Lexical_error ->
      "lexical error"

  | Syntax_error ->
      "syntax error"

let parser_error_message lexbuf =
  let lexeme =
    Lexing.lexeme lexbuf
  in

  if lexeme = "" then
    "unexpected end of input"
  else if lexeme = "\n" || lexeme = "\r" || lexeme = "\r\n" then
    "newline"
  else
    lexeme

(* ---------------------------------------------------------- *)
(* Core parser                                                *)
(* ---------------------------------------------------------- *)

let parse_lexbuf
    ~filename
    lexbuf =
  try
    Parser.document
      Lexer.token
      lexbuf
  with
  | Lexer.Error
      {
        message;
        start_pos;
        end_pos;
      } ->
      raise
        (Parse_error
           (error_of_positions
              ~kind:Lexical_error
              ~filename
              ~message
              start_pos
              end_pos))

  | Parser.Error ->
      let start_position =
        Lexing.lexeme_start_p lexbuf
      in

      let end_position =
        Lexing.lexeme_end_p lexbuf
      in

      let message =
        parser_error_message lexbuf
      in

      raise
        (Parse_error
           (error_of_positions
              ~kind:Syntax_error
              ~filename
              ~message
              start_position
              end_position))

(* ---------------------------------------------------------- *)
(* String parsing                                             *)
(* ---------------------------------------------------------- *)

let string
    ?(filename = "<string>")
    source =
  let lexbuf =
    lexbuf_from_string
      ~filename
      source
  in

  parse_lexbuf
    ~filename
    lexbuf

let from_string =
  string

(* ---------------------------------------------------------- *)
(* Channel parsing                                            *)
(* ---------------------------------------------------------- *)

let channel
    ?(filename = "<channel>")
    input =
  let lexbuf =
    lexbuf_from_channel
      ~filename
      input
  in

  parse_lexbuf
    ~filename
    lexbuf

let from_channel =
  channel

(* ---------------------------------------------------------- *)
(* File parsing                                               *)
(* ---------------------------------------------------------- *)

let file filename =
  let channel =
    try
      open_in_bin filename
    with Sys_error message ->
      let position =
        Node.position
          ~offset:0
          ~line:1
          ~column:0
          ()
      in

      let span =
        Node.span
          ~filename
          position
          position
      in

      raise
        (Parse_error
           {
             kind = Lexical_error;
             filename;
             line = 1;
             column = 0;
             offset = 0;
             message;
             span;
           })
  in

  Fun.protect
    ~finally:(fun () ->
      close_in_noerr channel)
    (fun () ->
      from_channel
        ~filename
        channel)

let from_file =
  file

(* ---------------------------------------------------------- *)
(* Safe parsing                                               *)
(* ---------------------------------------------------------- *)

let string_result
    ?(filename = "<string>")
    source =
  try
    Ok
      (string
         ~filename
         source)
  with
  | Parse_error error ->
      Error error

let channel_result
    ?(filename = "<channel>")
    input =
  try
    Ok
      (channel
         ~filename
         input)
  with
  | Parse_error error ->
      Error error

let file_result filename =
  try
    Ok (file filename)
  with
  | Parse_error error ->
      Error error

(* ---------------------------------------------------------- *)
(* Validation helpers                                         *)
(* ---------------------------------------------------------- *)

let is_valid_string
    ?(filename = "<string>")
    source =
  match
    string_result
      ~filename
      source
  with
  | Ok _ ->
      true

  | Error _ ->
      false

let is_valid_file filename =
  match file_result filename with
  | Ok _ ->
      true

  | Error _ ->
      false

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let diagnostic_of_error error =
  let diagnostic =
    match error.kind with
    | Lexical_error ->
        Error.make
          ~span:error.span
          (Error.Invalid_token error.message)

    | Syntax_error ->
        Error.make
          ~span:error.span
          (Error.Unexpected_token error.message)
  in

  Error.to_diagnostic diagnostic

let parse_with_diagnostics
    ?(filename = "<string>")
    source =
  match
    string_result
      ~filename
      source
  with
  | Ok document ->
      Ok document

  | Error error ->
      Error [diagnostic_of_error error]

let file_with_diagnostics filename =
  match file_result filename with
  | Ok document ->
      Ok document

  | Error error ->
      Error [diagnostic_of_error error]

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error error =
  Printf.sprintf
    "%s:%d:%d: %s: %s"
    error.filename
    error.line
    error.column
    (string_of_error_kind error.kind)
    error.message

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

let pp_document formatter document =
  Formatter.pp
    formatter
    document
