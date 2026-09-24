
(* The type of tokens. *)

type token = 
  | WHEN
  | SUB_ASSIGN
  | STRING of (string)
  | SIZE of (float * Value.size_unit)
  | SEMICOLON
  | RPAREN
  | RGBA
  | RGB
  | RBRACKET
  | RBRACE
  | OR
  | NULL
  | NOT
  | NEWLINE
  | NEQ
  | LTE
  | LT
  | LPAREN
  | LBRACKET
  | LBRACE
  | INTEGER of (int64)
  | INCLUDE
  | IDENTIFIER of (string)
  | GTE
  | GT
  | FLOAT of (float)
  | EQEQ
  | EOF
  | ELSE
  | DURATION of (float * Value.duration_unit)
  | DOT
  | DOLLAR
  | DEFINE_ASSIGN
  | DEFINE
  | COMMA
  | COLOR of (string)
  | COLON
  | BOOLEAN of (bool)
  | ASSIGN
  | AND
  | ADD_ASSIGN

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val document: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Statement.t Node.t list)
