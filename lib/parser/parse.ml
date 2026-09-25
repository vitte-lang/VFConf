(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/parser/parse.ml
 *
 * High-level parsing entry points.
 *
 * This module connects:
 *   source -> Lexing.lexbuf -> Lexer -> Menhir Parser -> AST
 *
 * It also normalizes lexer/parser/I/O failures into a stable
 * VFConf parsing error representation.
 *)

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

let initial_span filename =
  let position =
    Node.position
      ~offset:0
      ~line:1
      ~column:0
      ()
  in

  Node.span
    ~filename
    position
    position

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
  | Lexical_error _ ->
      "lexical error"

  | Syntax_error ->
      "syntax error"

  | Io_error File_not_found ->
      "file not found"

  | Io_error Cannot_read_file ->
      "I/O error"

let parser_error_message lexbuf =
  let lexeme =
    Lexing.lexeme lexbuf
  in

  if String.equal lexeme "" then
    "unexpected end of input"
  else if
    String.equal lexeme "\n"
    || String.equal lexeme "\r"
    || String.equal lexeme "\r\n"
  then
    "newline"
  else
    lexeme

(* ---------------------------------------------------------- *)
(* Core parser                                                *)
(* ---------------------------------------------------------- *)

let token_candidates =
  [
    ("include", Parser.INCLUDE);
    ("define", Parser.DEFINE);
    ("when", Parser.WHEN);
    ("else", Parser.ELSE);
    ("identifier", Parser.IDENTIFIER "");
    ("string", Parser.STRING "");
    ("integer", Parser.INTEGER 0L);
    ("float", Parser.FLOAT 0.0);
    ("boolean", Parser.BOOLEAN false);
    ("null", Parser.NULL);
    ("color", Parser.COLOR "#000000");
    ("duration", Parser.DURATION (0.0, Value.Millisecond));
    ("size", Parser.SIZE (0.0, Value.Byte));
    ("rgb", Parser.RGB);
    ("rgba", Parser.RGBA);
    ("=", Parser.ASSIGN);
    (":=", Parser.DEFINE_ASSIGN);
    ("+=", Parser.ADD_ASSIGN);
    ("-=", Parser.SUB_ASSIGN);
    ("==", Parser.EQEQ);
    ("!=", Parser.NEQ);
    ("<", Parser.LT);
    ("<=", Parser.LTE);
    (">", Parser.GT);
    (">=", Parser.GTE);
    ("&&", Parser.AND);
    ("||", Parser.OR);
    ("!", Parser.NOT);
    ("[", Parser.LBRACKET);
    ("]", Parser.RBRACKET);
    ("{", Parser.LBRACE);
    ("}", Parser.RBRACE);
    ("(", Parser.LPAREN);
    (")", Parser.RPAREN);
    (",", Parser.COMMA);
    (":", Parser.COLON);
    (";", Parser.SEMICOLON);
    (".", Parser.DOT);
    ("$", Parser.DOLLAR);
    ("newline", Parser.NEWLINE);
    ("end of file", Parser.EOF);
  ]

let expected_token checkpoint position =
  let acceptable =
    List.filter_map
      (fun (name, token) ->
        if
          Parser.MenhirInterpreter.acceptable
            checkpoint
            token
            position
        then
          Some name
        else
          None)
      token_candidates
  in

  match acceptable with
  | [expected] ->
      Some expected
  | _ ->
      prerr_endline
        ("VF0102 candidates: "
         ^ String.concat ", " acceptable);
      None

let expected_prefix =
  "__vfconf_expected__:"

let parse_lexbuf
    ~filename
    lexbuf =
  let module I = Parser.MenhirInterpreter in

  let rec drive checkpoint =
    match checkpoint with
    | I.InputNeeded _ ->
        let token =
          Lexer.token lexbuf
        in

        let start_position =
          Lexing.lexeme_start_p lexbuf
        in

        let end_position =
          Lexing.lexeme_end_p lexbuf
        in

        let next =
          I.offer
            checkpoint
            (token, start_position, end_position)
        in

        begin
          match next with
          | I.HandlingError _ ->
              let found =
                parser_error_message lexbuf
              in

              let expected =
                expected_token
                  checkpoint
                  start_position
              in

              let message =
                match token, expected with
                | Parser.EOF, _ ->
                    "unexpected end of input"

                | _, Some expected ->
                    expected_prefix
                    ^ expected
                    ^ "\n"
                    ^ found

                | _, None ->
                    found
              in

              raise
                (Parse_error
                   (error_of_positions
                      ~kind:Syntax_error
                      ~filename
                      ~message
                      start_position
                      end_position))

          | _ ->
              drive next
        end

    | I.Shifting _
    | I.AboutToReduce _ ->
        drive
          (I.resume checkpoint)

    | I.HandlingError _ ->
        let start_position =
          Lexing.lexeme_start_p lexbuf
        in

        let end_position =
          Lexing.lexeme_end_p lexbuf
        in

        raise
          (Parse_error
             (error_of_positions
                ~kind:Syntax_error
                ~filename
                ~message:(parser_error_message lexbuf)
                start_position
                end_position))

    | I.Accepted document ->
        document

    | I.Rejected ->
        let start_position =
          Lexing.lexeme_start_p lexbuf
        in

        let end_position =
          Lexing.lexeme_end_p lexbuf
        in

        raise
          (Parse_error
             (error_of_positions
                ~kind:Syntax_error
                ~filename
                ~message:(parser_error_message lexbuf)
                start_position
                end_position))
  in

  try
    drive
      (Parser.Incremental.document
         lexbuf.Lexing.lex_curr_p)
  with
  | Lexer.Error
      {
        kind;
        start_pos;
        end_pos;
      } ->
      raise
        (Parse_error
           (error_of_positions
              ~kind:(Lexical_error kind)
              ~filename
              ~message:(Lexer.message_of_error_kind kind)
              start_pos
              end_pos))

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
    with
    | Sys_error message ->
        let kind =
          if Sys.file_exists filename then
            Io_error Cannot_read_file
          else
            Io_error File_not_found
        in

        raise
          (Parse_error
             {
               kind;
               filename;
               line = 1;
               column = 0;
               offset = 0;
               message;
               span = initial_span filename;
             })
  in

  Fun.protect
    ~finally:(fun () ->
      close_in_noerr channel)
    (fun () ->
      try
        from_channel
          ~filename
          channel
      with
      | Sys_error message ->
          raise
            (Parse_error
               {
                 kind = Io_error Cannot_read_file;
                 filename;
                 line = 1;
                 column = 0;
                 offset = 0;
                 message;
                 span = initial_span filename;
               }))

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
    | Lexical_error kind ->
        let kind =
          match kind with
          | Lexer.Unexpected_character character ->
              Error.Unexpected_character character

          | Lexer.Invalid_token token ->
              Error.Invalid_token token

          | Lexer.Unterminated_string ->
              Error.Unterminated_string

          | Lexer.Unterminated_comment ->
              Error.Unterminated_comment

          | Lexer.Invalid_escape escape ->
              Error.Invalid_escape escape

          | Lexer.Invalid_number value ->
              Error.Invalid_number value

          | Lexer.Invalid_color value ->
              Error.Invalid_color value

          | Lexer.Invalid_duration value ->
              Error.Invalid_duration value

          | Lexer.Invalid_size value ->
              Error.Invalid_size value
        in

        Error.make
          ~span:error.span
          kind

    | Syntax_error ->
        if
          String.equal
            error.message
            "unexpected end of input"
        then
          Error.make
            ~span:error.span
            Error.Unexpected_end_of_file
        else if
          String.starts_with
            ~prefix:expected_prefix
            error.message
        then
          let payload =
            String.sub
              error.message
              (String.length expected_prefix)
              (String.length error.message
               - String.length expected_prefix)
          in

          let expected, found =
            match String.index_opt payload '\n' with
            | None ->
                payload, None

            | Some index ->
                let expected =
                  String.sub payload 0 index
                in

                let found =
                  String.sub
                    payload
                    (index + 1)
                    (String.length payload - index - 1)
                in

                expected, Some found
          in

          Error.make
            ~span:error.span
            (Error.Expected_token
               {
                 expected;
                 found;
               })
        else
          Error.make
            ~span:error.span
            (Error.Unexpected_token
               error.message)

    | Io_error File_not_found ->
        Error.make
          ~span:error.span
          (Error.File_not_found
             error.filename)

    | Io_error Cannot_read_file ->
        Error.make
          ~span:error.span
          (Error.Cannot_read_file
             {
               path = error.filename;
               message = error.message;
             })
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
      Error
        [diagnostic_of_error error]

let file_with_diagnostics filename =
  match file_result filename with
  | Ok document ->
      Ok document

  | Error error ->
      Error
        [diagnostic_of_error error]

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