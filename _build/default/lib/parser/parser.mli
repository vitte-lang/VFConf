
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

module MenhirInterpreter : sig
  
  (* The incremental API. *)
  
  include MenhirLib.IncrementalEngine.INCREMENTAL_ENGINE
    with type token = token
  
  (* The indexed type of terminal symbols. *)
  
  type _ terminal = 
    | T_error : unit terminal
    | T_WHEN : unit terminal
    | T_SUB_ASSIGN : unit terminal
    | T_STRING : (string) terminal
    | T_SIZE : (float * Value.size_unit) terminal
    | T_SEMICOLON : unit terminal
    | T_RPAREN : unit terminal
    | T_RGBA : unit terminal
    | T_RGB : unit terminal
    | T_RBRACKET : unit terminal
    | T_RBRACE : unit terminal
    | T_OR : unit terminal
    | T_NULL : unit terminal
    | T_NOT : unit terminal
    | T_NEWLINE : unit terminal
    | T_NEQ : unit terminal
    | T_LTE : unit terminal
    | T_LT : unit terminal
    | T_LPAREN : unit terminal
    | T_LBRACKET : unit terminal
    | T_LBRACE : unit terminal
    | T_INTEGER : (int64) terminal
    | T_INCLUDE : unit terminal
    | T_IDENTIFIER : (string) terminal
    | T_GTE : unit terminal
    | T_GT : unit terminal
    | T_FLOAT : (float) terminal
    | T_EQEQ : unit terminal
    | T_EOF : unit terminal
    | T_ELSE : unit terminal
    | T_DURATION : (float * Value.duration_unit) terminal
    | T_DOT : unit terminal
    | T_DOLLAR : unit terminal
    | T_DEFINE_ASSIGN : unit terminal
    | T_DEFINE : unit terminal
    | T_COMMA : unit terminal
    | T_COLOR : (string) terminal
    | T_COLON : unit terminal
    | T_BOOLEAN : (bool) terminal
    | T_ASSIGN : unit terminal
    | T_AND : unit terminal
    | T_ADD_ASSIGN : unit terminal
  
  (* The indexed type of nonterminal symbols. *)
  
  type _ nonterminal = 
    | N_value : (Value.t Node.t) nonterminal
    | N_statements_before_rbrace : (Statement.t Node.t list) nonterminal
    | N_statement : (Statement.t Node.t) nonterminal
    | N_separators1 : (unit) nonterminal
    | N_separators : (unit) nonterminal
    | N_separator : (unit) nonterminal
    | N_reference : (Value.reference) nonterminal
    | N_path_component : (string) nonterminal
    | N_path : (Value.reference) nonterminal
    | N_optional_else : (Statement.t Node.t list option) nonterminal
    | N_object_value : (Value.object_entry list) nonterminal
    | N_object_tail : (Value.object_entry list) nonterminal
    | N_object_entry : (Value.object_entry) nonterminal
    | N_object_contents : (Value.object_entry list) nonterminal
    | N_numeric_value : (Value.t Node.t) nonterminal
    | N_non_section_statement : (Statement.t Node.t) nonterminal
    | N_include_statement : (Statement.include_statement) nonterminal
    | N_flat_document_items : (Statement.t Node.t list) nonterminal
    | N_flat_document_item : (Statement.t Node.t) nonterminal
    | N_document : (Statement.t Node.t list) nonterminal
    | N_define_statement : (Statement.define_statement) nonterminal
    | N_conditional : (Statement.conditional) nonterminal
    | N_condition_primary : (Statement.condition Node.t) nonterminal
    | N_condition_or : (Statement.condition Node.t) nonterminal
    | N_condition_not : (Statement.condition Node.t) nonterminal
    | N_condition_and : (Statement.condition Node.t) nonterminal
    | N_condition : (Statement.condition Node.t) nonterminal
    | N_comparison_operator : (Statement.comparison_operator) nonterminal
    | N_block_statements : (Statement.t Node.t list) nonterminal
    | N_block_statement_tail : (Statement.t Node.t list) nonterminal
    | N_assignment_operator : (Statement.assignment_operator) nonterminal
    | N_assignment : (Statement.assignment) nonterminal
    | N_array_tail : (Value.t Node.t list) nonterminal
    | N_array_contents : (Value.t Node.t list) nonterminal
    | N_array : (Value.t Node.t list) nonterminal
  
  (* The inspection API. *)
  
  include MenhirLib.IncrementalEngine.INSPECTION
    with type 'a lr1state := 'a lr1state
    with type production := production
    with type 'a terminal := 'a terminal
    with type 'a nonterminal := 'a nonterminal
    with type 'a env := 'a env
  
end

(* The entry point(s) to the incremental API. *)

module Incremental : sig
  
  val document: Lexing.position -> (Statement.t Node.t list) MenhirInterpreter.checkpoint
  
end

(* The parse tables. *)

(* Warning: this submodule is undocumented. In the future,
   its type could change, or it could disappear altogether. *)

module Tables : MenhirLib.TableFormat.TABLES
  with type token = token
