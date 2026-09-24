(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/lexer/token.ml
 *
 * Token representation used by VFConf tooling.
 *
 * The Menhir parser owns its generated Parser.token type. This module
 * provides an independent token representation suitable for diagnostics,
 * debugging, syntax tooling, tests and future LSP integration.
 *)

type t =
  (* Keywords *)
  | Include
  | Define
  | When
  | Else

  (* Literals *)
  | Identifier of string
  | String of string
  | Integer of int64
  | Float of float
  | Boolean of bool
  | Null
  | Color of string
  | Duration of float * Value.duration_unit
  | Size of float * Value.size_unit

  (* Color constructors *)
  | Rgb
  | Rgba

  (* Assignment operators *)
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign

  (* Comparison operators *)
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal

  (* Logical operators *)
  | And
  | Or
  | Not

  (* Delimiters *)
  | Left_bracket
  | Right_bracket
  | Left_brace
  | Right_brace
  | Left_parenthesis
  | Right_parenthesis

  (* Punctuation *)
  | Comma
  | Colon
  | Semicolon
  | Dot
  | Dollar

  (* Layout *)
  | Newline

  (* End of input *)
  | Eof

type located = t Node.t

(* ---------------------------------------------------------- *)
(* Classification                                             *)
(* ---------------------------------------------------------- *)

let is_keyword = function
  | Include
  | Define
  | When
  | Else
  | Rgb
  | Rgba ->
      true

  | _ ->
      false

let is_literal = function
  | Identifier _
  | String _
  | Integer _
  | Float _
  | Boolean _
  | Null
  | Color _
  | Duration _
  | Size _ ->
      true

  | _ ->
      false

let is_assignment_operator = function
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign ->
      true

  | _ ->
      false

let is_comparison_operator = function
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal ->
      true

  | _ ->
      false

let is_logical_operator = function
  | And
  | Or
  | Not ->
      true

  | _ ->
      false

let is_operator token =
  is_assignment_operator token
  || is_comparison_operator token
  || is_logical_operator token

let is_delimiter = function
  | Left_bracket
  | Right_bracket
  | Left_brace
  | Right_brace
  | Left_parenthesis
  | Right_parenthesis ->
      true

  | _ ->
      false

let is_punctuation = function
  | Comma
  | Colon
  | Semicolon
  | Dot
  | Dollar ->
      true

  | _ ->
      false

let is_layout = function
  | Newline ->
      true

  | _ ->
      false

let is_eof = function
  | Eof ->
      true

  | _ ->
      false

(* ---------------------------------------------------------- *)
(* Token names                                                *)
(* ---------------------------------------------------------- *)

let name = function
  | Include ->
      "INCLUDE"

  | Define ->
      "DEFINE"

  | When ->
      "WHEN"

  | Else ->
      "ELSE"

  | Identifier _ ->
      "IDENTIFIER"

  | String _ ->
      "STRING"

  | Integer _ ->
      "INTEGER"

  | Float _ ->
      "FLOAT"

  | Boolean _ ->
      "BOOLEAN"

  | Null ->
      "NULL"

  | Color _ ->
      "COLOR"

  | Duration _ ->
      "DURATION"

  | Size _ ->
      "SIZE"

  | Rgb ->
      "RGB"

  | Rgba ->
      "RGBA"

  | Assign ->
      "ASSIGN"

  | Define_assign ->
      "DEFINE_ASSIGN"

  | Add_assign ->
      "ADD_ASSIGN"

  | Sub_assign ->
      "SUB_ASSIGN"

  | Equal ->
      "EQEQ"

  | Not_equal ->
      "NEQ"

  | Less ->
      "LT"

  | Less_equal ->
      "LTE"

  | Greater ->
      "GT"

  | Greater_equal ->
      "GTE"

  | And ->
      "AND"

  | Or ->
      "OR"

  | Not ->
      "NOT"

  | Left_bracket ->
      "LBRACKET"

  | Right_bracket ->
      "RBRACKET"

  | Left_brace ->
      "LBRACE"

  | Right_brace ->
      "RBRACE"

  | Left_parenthesis ->
      "LPAREN"

  | Right_parenthesis ->
      "RPAREN"

  | Comma ->
      "COMMA"

  | Colon ->
      "COLON"

  | Semicolon ->
      "SEMICOLON"

  | Dot ->
      "DOT"

  | Dollar ->
      "DOLLAR"

  | Newline ->
      "NEWLINE"

  | Eof ->
      "EOF"

(* ---------------------------------------------------------- *)
(* Source spelling                                            *)
(* ---------------------------------------------------------- *)

let string_of_duration_unit = function
  | Value.Nanosecond ->
      "ns"

  | Value.Microsecond ->
      "us"

  | Value.Millisecond ->
      "ms"

  | Value.Second ->
      "s"

  | Value.Minute ->
      "min"

  | Value.Hour ->
      "h"

let string_of_size_unit = function
  | Value.Byte ->
      "B"

  | Value.Kilobyte ->
      "KB"

  | Value.Megabyte ->
      "MB"

  | Value.Gigabyte ->
      "GB"

  | Value.Kibibyte ->
      "KiB"

  | Value.Mebibyte ->
      "MiB"

  | Value.Gibibyte ->
      "GiB"

let to_string = function
  | Include ->
      "include"

  | Define ->
      "define"

  | When ->
      "when"

  | Else ->
      "else"

  | Identifier value ->
      value

  | String value ->
      "\"" ^ Formatter.escape_string value ^ "\""

  | Integer value ->
      Int64.to_string value

  | Float value ->
      Formatter.string_of_float value

  | Boolean true ->
      "true"

  | Boolean false ->
      "false"

  | Null ->
      "null"

  | Color value ->
      value

  | Duration (value, unit) ->
      Formatter.string_of_float value
      ^ string_of_duration_unit unit

  | Size (value, unit) ->
      Formatter.string_of_float value
      ^ string_of_size_unit unit

  | Rgb ->
      "rgb"

  | Rgba ->
      "rgba"

  | Assign ->
      "="

  | Define_assign ->
      ":="

  | Add_assign ->
      "+="

  | Sub_assign ->
      "-="

  | Equal ->
      "=="

  | Not_equal ->
      "!="

  | Less ->
      "<"

  | Less_equal ->
      "<="

  | Greater ->
      ">"

  | Greater_equal ->
      ">="

  | And ->
      "&&"

  | Or ->
      "||"

  | Not ->
      "!"

  | Left_bracket ->
      "["

  | Right_bracket ->
      "]"

  | Left_brace ->
      "{"

  | Right_brace ->
      "}"

  | Left_parenthesis ->
      "("

  | Right_parenthesis ->
      ")"

  | Comma ->
      ","

  | Colon ->
      ":"

  | Semicolon ->
      ";"

  | Dot ->
      "."

  | Dollar ->
      "$"

  | Newline ->
      "\\n"

  | Eof ->
      "<eof>"

(* ---------------------------------------------------------- *)
(* Descriptions                                               *)
(* ---------------------------------------------------------- *)

let description = function
  | Include ->
      "keyword 'include'"

  | Define ->
      "keyword 'define'"

  | When ->
      "keyword 'when'"

  | Else ->
      "keyword 'else'"

  | Identifier _ ->
      "identifier"

  | String _ ->
      "string literal"

  | Integer _ ->
      "integer literal"

  | Float _ ->
      "floating-point literal"

  | Boolean _ ->
      "boolean literal"

  | Null ->
      "null literal"

  | Color _ ->
      "color literal"

  | Duration _ ->
      "duration literal"

  | Size _ ->
      "size literal"

  | Rgb ->
      "color function 'rgb'"

  | Rgba ->
      "color function 'rgba'"

  | Assign ->
      "assignment operator '='"

  | Define_assign ->
      "definition assignment operator ':='"

  | Add_assign ->
      "addition assignment operator '+='"

  | Sub_assign ->
      "subtraction assignment operator '-='"

  | Equal ->
      "equality operator '=='"

  | Not_equal ->
      "inequality operator '!='"

  | Less ->
      "less-than operator '<'"

  | Less_equal ->
      "less-than-or-equal operator '<='"

  | Greater ->
      "greater-than operator '>'"

  | Greater_equal ->
      "greater-than-or-equal operator '>='"

  | And ->
      "logical AND operator '&&'"

  | Or ->
      "logical OR operator '||'"

  | Not ->
      "logical NOT operator '!'"

  | Left_bracket ->
      "left bracket '['"

  | Right_bracket ->
      "right bracket ']'"

  | Left_brace ->
      "left brace '{'"

  | Right_brace ->
      "right brace '}'"

  | Left_parenthesis ->
      "left parenthesis '('"

  | Right_parenthesis ->
      "right parenthesis ')'"

  | Comma ->
      "comma ','"

  | Colon ->
      "colon ':'"

  | Semicolon ->
      "semicolon ';'"

  | Dot ->
      "dot '.'"

  | Dollar ->
      "dollar sign '$'"

  | Newline ->
      "newline"

  | Eof ->
      "end of file"

(* ---------------------------------------------------------- *)
(* Literal accessors                                          *)
(* ---------------------------------------------------------- *)

let identifier_value = function
  | Identifier value ->
      Some value

  | _ ->
      None

let string_value = function
  | String value ->
      Some value

  | _ ->
      None

let integer_value = function
  | Integer value ->
      Some value

  | _ ->
      None

let float_value = function
  | Float value ->
      Some value

  | Integer value ->
      Some (Int64.to_float value)

  | _ ->
      None

let boolean_value = function
  | Boolean value ->
      Some value

  | _ ->
      None

let color_value = function
  | Color value ->
      Some value

  | _ ->
      None

let duration_value = function
  | Duration (value, unit) ->
      Some (value, unit)

  | _ ->
      None

let size_value = function
  | Size (value, unit) ->
      Some (value, unit)

  | _ ->
      None

(* ---------------------------------------------------------- *)
(* Equality                                                   *)
(* ---------------------------------------------------------- *)

let equal left right =
  match left, right with
  | Include, Include
  | Define, Define
  | When, When
  | Else, Else
  | Null, Null
  | Rgb, Rgb
  | Rgba, Rgba
  | Assign, Assign
  | Define_assign, Define_assign
  | Add_assign, Add_assign
  | Sub_assign, Sub_assign
  | Equal, Equal
  | Not_equal, Not_equal
  | Less, Less
  | Less_equal, Less_equal
  | Greater, Greater
  | Greater_equal, Greater_equal
  | And, And
  | Or, Or
  | Not, Not
  | Left_bracket, Left_bracket
  | Right_bracket, Right_bracket
  | Left_brace, Left_brace
  | Right_brace, Right_brace
  | Left_parenthesis, Left_parenthesis
  | Right_parenthesis, Right_parenthesis
  | Comma, Comma
  | Colon, Colon
  | Semicolon, Semicolon
  | Dot, Dot
  | Dollar, Dollar
  | Newline, Newline
  | Eof, Eof ->
      true

  | Identifier left, Identifier right
  | String left, String right
  | Color left, Color right ->
      String.equal left right

  | Integer left, Integer right ->
      Int64.equal left right

  | Float left, Float right ->
      Float.equal left right

  | Boolean left, Boolean right ->
      Bool.equal left right

  | Duration (left_value, left_unit),
    Duration (right_value, right_unit) ->
      Float.equal left_value right_value
      && left_unit = right_unit

  | Size (left_value, left_unit),
    Size (right_value, right_unit) ->
      Float.equal left_value right_value
      && left_unit = right_unit

  | _ ->
      false

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp formatter token =
  Format.pp_print_string
    formatter
    (to_string token)

let pp_debug formatter token =
  Format.fprintf
    formatter
    "%s(%s)"
    (name token)
    (to_string token)

let located token span =
  Node.located span token

let value token =
  token.Node.value

let span token =
  token.Node.span