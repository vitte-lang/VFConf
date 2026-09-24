{
(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/lexer/lexer.mll
 *
 * Canonical VFConf lexer.
 *)

open Parser

exception Error of {
  message : string;
  start_pos : Lexing.position;
  end_pos : Lexing.position;
}

let error lexbuf message =
  raise
    (Error
       {
         message;
         start_pos = Lexing.lexeme_start_p lexbuf;
         end_pos = Lexing.lexeme_end_p lexbuf;
       })

let newline lexbuf =
  Lexing.new_line lexbuf

let buffer = Buffer.create 128

let reset_buffer () =
  Buffer.clear buffer

let buffer_contents () =
  Buffer.contents buffer

let add_char character =
  Buffer.add_char buffer character

let add_string string =
  Buffer.add_string buffer string

let hex_value character =
  match character with
  | '0' .. '9' ->
      Char.code character - Char.code '0'
  | 'a' .. 'f' ->
      10 + Char.code character - Char.code 'a'
  | 'A' .. 'F' ->
      10 + Char.code character - Char.code 'A'
  | _ ->
      invalid_arg "hex_value"

let unicode_scalar_to_utf8 code =
  let result = Buffer.create 4 in

  let add value =
    Buffer.add_char result (Char.chr value)
  in

  if code < 0 || code > 0x10FFFF
     || (code >= 0xD800 && code <= 0xDFFF)
  then
    invalid_arg "unicode_scalar_to_utf8"
  else if code <= 0x7F then
    add code
  else if code <= 0x7FF then begin
    add (0xC0 lor (code lsr 6));
    add (0x80 lor (code land 0x3F))
  end
  else if code <= 0xFFFF then begin
    add (0xE0 lor (code lsr 12));
    add (0x80 lor ((code lsr 6) land 0x3F));
    add (0x80 lor (code land 0x3F))
  end
  else begin
    add (0xF0 lor (code lsr 18));
    add (0x80 lor ((code lsr 12) land 0x3F));
    add (0x80 lor ((code lsr 6) land 0x3F));
    add (0x80 lor (code land 0x3F))
  end;

  Buffer.contents result

let parse_unicode_escape lexbuf value =
  try
    let code =
      int_of_string ("0x" ^ value)
    in
    unicode_scalar_to_utf8 code
  with
  | Invalid_argument _
  | Failure _ ->
      error lexbuf
        ("invalid Unicode escape '\\u" ^ value ^ "'")

let remove_underscores value =
  String.concat "" (String.split_on_char '_' value)

let parse_integer lexbuf value =
  try
    Int64.of_string (remove_underscores value)
  with Failure _ ->
    error lexbuf ("invalid integer literal '" ^ value ^ "'")

let parse_float lexbuf value =
  try
    float_of_string (remove_underscores value)
  with Failure _ ->
    error lexbuf ("invalid floating-point literal '" ^ value ^ "'")

let parse_hex_integer lexbuf value =
  try
    Int64.of_string (remove_underscores value)
  with Failure _ ->
    error lexbuf ("invalid hexadecimal integer literal '" ^ value ^ "'")

let parse_binary_integer lexbuf value =
  try
    Int64.of_string (remove_underscores value)
  with Failure _ ->
    error lexbuf ("invalid binary integer literal '" ^ value ^ "'")

let parse_octal_integer lexbuf value =
  try
    Int64.of_string (remove_underscores value)
  with Failure _ ->
    error lexbuf ("invalid octal integer literal '" ^ value ^ "'")

let keyword_or_identifier value =
  match Keyword.of_string value with
  | Some Keyword.Include -> INCLUDE
  | Some Keyword.Define -> DEFINE
  | Some Keyword.When -> WHEN
  | Some Keyword.Else -> ELSE

  | Some Keyword.True
  | Some Keyword.On ->
      BOOLEAN true

  | Some Keyword.False
  | Some Keyword.Off ->
      BOOLEAN false

  | Some Keyword.Null
  | Some Keyword.None ->
      NULL

  | Some Keyword.Rgb ->
      RGB

  | Some Keyword.Rgba ->
      RGBA

  | None ->
      IDENTIFIER value

let parse_color lexbuf value =
  let length = String.length value in

  if
    length = 4
    || length = 5
    || length = 7
    || length = 9
  then
    COLOR value
  else
    error lexbuf ("invalid color literal '" ^ value ^ "'")

let parse_duration lexbuf number unit_ =
  let amount =
    parse_float lexbuf number
  in
  DURATION (amount, unit_)

let parse_size lexbuf number unit_ =
  let amount =
    parse_float lexbuf number
  in
  SIZE (amount, unit_)

let comment_depth = ref 0
}

let digit = ['0'-'9']
let nonzero = ['1'-'9']
let hex_digit = ['0'-'9' 'a'-'f' 'A'-'F']
let oct_digit = ['0'-'7']
let bin_digit = ['0' '1']

let digits = digit (digit | '_')*
let hex_digits = hex_digit (hex_digit | '_')*
let oct_digits = oct_digit (oct_digit | '_')*
let bin_digits = bin_digit (bin_digit | '_')*

let sign = ['+' '-']

let exponent =
  ['e' 'E'] sign? digits

let decimal_float =
    digits '.' digits? exponent?
  | '.' digits exponent?
  | digits exponent

let decimal_integer = digits
let hexadecimal_integer = "0x" hex_digits | "0X" hex_digits
let binary_integer = "0b" bin_digits | "0B" bin_digits
let octal_integer = "0o" oct_digits | "0O" oct_digits

let identifier_start =
  ['A'-'Z' 'a'-'z' '_']

let identifier_continue =
  ['A'-'Z' 'a'-'z' '0'-'9' '_' '-']

let identifier =
  identifier_start identifier_continue*

let whitespace =
  [' ' '\t' '\012']

let newline_sequence =
    "\r\n"
  | '\n'
  | '\r'

let color_literal =
    '#' hex_digit hex_digit hex_digit
  | '#' hex_digit hex_digit hex_digit hex_digit
  | '#' hex_digit hex_digit hex_digit hex_digit hex_digit hex_digit
  | '#' hex_digit hex_digit hex_digit hex_digit hex_digit hex_digit
      hex_digit hex_digit

let number =
    decimal_float
  | decimal_integer

rule token = parse
  | whitespace+
      {
        token lexbuf
      }

  | newline_sequence
      {
        newline lexbuf;
        NEWLINE
      }

  | '#' [^ '\n' '\r']*
      {
        token lexbuf
      }

  | "//" [^ '\n' '\r']*
      {
        token lexbuf
      }

  | "/*"
      {
        comment_depth := 1;
        block_comment lexbuf;
        token lexbuf
      }

  | "=="
      {
        EQEQ
      }

  | "!="
      {
        NEQ
      }

  | "<="
      {
        LTE
      }

  | ">="
      {
        GTE
      }

  | "&&"
      {
        AND
      }

  | "||"
      {
        OR
      }

  | ":="
      {
        DEFINE_ASSIGN
      }

  | "+="
      {
        ADD_ASSIGN
      }

  | "-="
      {
        SUB_ASSIGN
      }

  | '='
      {
        ASSIGN
      }

  | '<'
      {
        LT
      }

  | '>'
      {
        GT
      }

  | '!'
      {
        NOT
      }

  | '['
      {
        LBRACKET
      }

  | ']'
      {
        RBRACKET
      }

  | '{'
      {
        LBRACE
      }

  | '}'
      {
        RBRACE
      }

  | '('
      {
        LPAREN
      }

  | ')'
      {
        RPAREN
      }

  | ','
      {
        COMMA
      }

  | ':'
      {
        COLON
      }

  | ';'
      {
        SEMICOLON
      }

  | '.'
      {
        DOT
      }

  | '$'
      {
        DOLLAR
      }

  | '"'
      {
        reset_buffer ();
        string_literal lexbuf
      }

  | color_literal as value
      {
        parse_color lexbuf value
      }

  | hexadecimal_integer as value
      {
        INTEGER (parse_hex_integer lexbuf value)
      }

  | binary_integer as value
      {
        INTEGER (parse_binary_integer lexbuf value)
      }

  | octal_integer as value
      {
        INTEGER (parse_octal_integer lexbuf value)
      }

  | number "ns" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 2) in
        parse_duration lexbuf number Value.Nanosecond
      }

  | number "us" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 2) in
        parse_duration lexbuf number Value.Microsecond
      }

  | number "ms" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 2) in
        parse_duration lexbuf number Value.Millisecond
      }

  | number "min" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 3) in
        parse_duration lexbuf number Value.Minute
      }

  | number "h" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 1) in
        parse_duration lexbuf number Value.Hour
      }

  | number "s" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 1) in
        parse_duration lexbuf number Value.Second
      }

  | number "KiB" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 3) in
        parse_size lexbuf number Value.Kibibyte
      }

  | number "MiB" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 3) in
        parse_size lexbuf number Value.Mebibyte
      }

  | number "GiB" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 3) in
        parse_size lexbuf number Value.Gibibyte
      }

  | number "KB" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 2) in
        parse_size lexbuf number Value.Kilobyte
      }

  | number "MB" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 2) in
        parse_size lexbuf number Value.Megabyte
      }

  | number "GB" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 2) in
        parse_size lexbuf number Value.Gigabyte
      }

  | number "B" as value
      {
        let length = String.length value in
        let number = String.sub value 0 (length - 1) in
        parse_size lexbuf number Value.Byte
      }

  | decimal_float as value
      {
        FLOAT (parse_float lexbuf value)
      }

  | decimal_integer as value
      {
        INTEGER (parse_integer lexbuf value)
      }

  | identifier as value
      {
        keyword_or_identifier value
      }

  | eof
      {
        EOF
      }

  | _ as character
      {
        error
          lexbuf
          (Printf.sprintf
             "unexpected character '%c'"
             character)
      }

and string_literal = parse
  | '"'
      {
        STRING (buffer_contents ())
      }

  | "\\\""
      {
        add_char '"';
        string_literal lexbuf
      }

  | "\\\\"
      {
        add_char '\\';
        string_literal lexbuf
      }

  | "\\n"
      {
        add_char '\n';
        string_literal lexbuf
      }

  | "\\r"
      {
        add_char '\r';
        string_literal lexbuf
      }

  | "\\t"
      {
        add_char '\t';
        string_literal lexbuf
      }

  | "\\b"
      {
        add_char '\b';
        string_literal lexbuf
      }

  | "\\f"
      {
        add_char '\012';
        string_literal lexbuf
      }

  | "\\/" 
      {
        add_char '/';
        string_literal lexbuf
      }

  | "\\u" (hex_digit hex_digit hex_digit hex_digit as value)
      {
        add_string
          (parse_unicode_escape lexbuf value);
        string_literal lexbuf
      }

  | '\\' (_ as character)
      {
        error
          lexbuf
          (Printf.sprintf
             "invalid escape sequence '\\%c'"
             character)
      }

  | newline_sequence
      {
        error lexbuf
          "unterminated string literal"
      }

  | eof
      {
        error lexbuf
          "unterminated string literal"
      }

  | [^ '"' '\\' '\n' '\r']+ as value
      {
        add_string value;
        string_literal lexbuf
      }

and block_comment = parse
  | "/*"
      {
        incr comment_depth;
        block_comment lexbuf
      }

  | "*/"
      {
        decr comment_depth;

        if !comment_depth > 0 then
          block_comment lexbuf
      }

  | newline_sequence
      {
        newline lexbuf;
        block_comment lexbuf
      }

  | eof
      {
        error lexbuf
          "unterminated block comment"
      }

  | _
      {
        block_comment lexbuf
      }