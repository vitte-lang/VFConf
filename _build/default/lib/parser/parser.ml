
module MenhirBasics = struct
  
  exception Error
  
  let _eRR =
    fun _s ->
      raise Error
  
  type token = 
    | WHEN
    | SUB_ASSIGN
    | STRING of 
# 153 "lib/parser/parser.mly"
       (string)
# 17 "lib/parser/parser.ml"
  
    | SIZE of 
# 160 "lib/parser/parser.mly"
       (float * Value.size_unit)
# 22 "lib/parser/parser.ml"
  
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
    | INTEGER of 
# 154 "lib/parser/parser.mly"
       (int64)
# 43 "lib/parser/parser.ml"
  
    | INCLUDE
    | IDENTIFIER of 
# 152 "lib/parser/parser.mly"
       (string)
# 49 "lib/parser/parser.ml"
  
    | GTE
    | GT
    | FLOAT of 
# 155 "lib/parser/parser.mly"
       (float)
# 56 "lib/parser/parser.ml"
  
    | EQEQ
    | EOF
    | ELSE
    | DURATION of 
# 159 "lib/parser/parser.mly"
       (float * Value.duration_unit)
# 64 "lib/parser/parser.ml"
  
    | DOT
    | DOLLAR
    | DEFINE_ASSIGN
    | DEFINE
    | COMMA
    | COLOR of 
# 158 "lib/parser/parser.mly"
       (string)
# 74 "lib/parser/parser.ml"
  
    | COLON
    | BOOLEAN of 
# 156 "lib/parser/parser.mly"
       (bool)
# 80 "lib/parser/parser.ml"
  
    | ASSIGN
    | AND
    | ADD_ASSIGN
  
end

include MenhirBasics

# 1 "lib/parser/parser.mly"
  
(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/parser/parser.mly
 *
 * Canonical Menhir grammar.
 *)

let node_position (position : Lexing.position) : Node.position =
  {
    offset = position.Lexing.pos_cnum;
    line = position.Lexing.pos_lnum;
    column =
      position.Lexing.pos_cnum
      - position.Lexing.pos_bol;
  }

let span start_position end_position =
  let filename =
    if start_position.Lexing.pos_fname <> "" then
      start_position.Lexing.pos_fname
    else
      end_position.Lexing.pos_fname
  in

  Node.span
      ~filename
      (node_position start_position)
      (node_position end_position)

let located start_position end_position value =
  Node.located
    (span start_position end_position)
    value

let object_entry key value start_position end_position =
  {
    Value.key;
    value;
    span = span start_position end_position;
  }

let hex_digit_value character =
  match character with
  | '0' .. '9' ->
      Char.code character - Char.code '0'
  | 'a' .. 'f' ->
      10 + Char.code character - Char.code 'a'
  | 'A' .. 'F' ->
      10 + Char.code character - Char.code 'A'
  | _ ->
      invalid_arg "hex_digit_value"

let expand_hex_digit character =
  let value = hex_digit_value character in
  (value lsl 4) lor value

let parse_hex_byte string offset =
  (hex_digit_value string.[offset] lsl 4)
  lor hex_digit_value string.[offset + 1]

let color_of_hex string =
  let value =
    if String.length string > 0 && string.[0] = '#' then
      String.sub string 1 (String.length string - 1)
    else
      string
  in

  match String.length value with
  | 3 ->
      Value.Rgb
        {
          red = expand_hex_digit value.[0];
          green = expand_hex_digit value.[1];
          blue = expand_hex_digit value.[2];
        }

  | 4 ->
      Value.Rgba
        {
          red = expand_hex_digit value.[0];
          green = expand_hex_digit value.[1];
          blue = expand_hex_digit value.[2];
          alpha =
            float_of_int (expand_hex_digit value.[3])
            /. 255.0;
        }

  | 6 ->
      Value.Rgb
        {
          red = parse_hex_byte value 0;
          green = parse_hex_byte value 2;
          blue = parse_hex_byte value 4;
        }

  | 8 ->
      Value.Rgba
        {
          red = parse_hex_byte value 0;
          green = parse_hex_byte value 2;
          blue = parse_hex_byte value 4;
          alpha =
            float_of_int (parse_hex_byte value 6)
            /. 255.0;
        }

  | _ ->
      invalid_arg "color_of_hex"

let int_of_int64_checked value =
  if
    Int64.compare value (Int64.of_int max_int) > 0
    || Int64.compare value (Int64.of_int min_int) < 0
  then
    invalid_arg "integer outside OCaml int range"
  else
    Int64.to_int value

let alpha_of_value value =
  match value.Node.value with
  | Value.Float value ->
      value
  | Value.Integer value ->
      Int64.to_float value
  | _ ->
      invalid_arg "RGBA alpha must be numeric"

let rgb_component value =
  match value.Node.value with
  | Value.Integer value ->
      let value = int_of_int64_checked value in
      if value < 0 || value > 255 then
        invalid_arg "RGB component outside 0..255";
      value
  | _ ->
      invalid_arg "RGB component must be an integer"

let rgba_alpha value =
  let value = alpha_of_value value in
  if value < 0.0 || value > 1.0 then
    invalid_arg "RGBA alpha outside 0.0..1.0";
  value

# 236 "lib/parser/parser.ml"

type ('s, 'r) _menhir_state = 
  | MenhirState000 : ('s, _menhir_box_document) _menhir_state
    (** State 000.
        Stack shape : <empty>.
        Start symbol: document. *)

  | MenhirState001 : (('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 001.
        Stack shape : separators.
        Start symbol: document. *)

  | MenhirState002 : (('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_state
    (** State 002.
        Stack shape : WHEN.
        Start symbol: document. *)

  | MenhirState003 : (('s, _menhir_box_document) _menhir_cell1_NOT, _menhir_box_document) _menhir_state
    (** State 003.
        Stack shape : NOT.
        Start symbol: document. *)

  | MenhirState004 : (('s, _menhir_box_document) _menhir_cell1_LPAREN, _menhir_box_document) _menhir_state
    (** State 004.
        Stack shape : LPAREN.
        Start symbol: document. *)

  | MenhirState005 : (('s, _menhir_box_document) _menhir_cell1_DOLLAR, _menhir_box_document) _menhir_state
    (** State 005.
        Stack shape : DOLLAR.
        Start symbol: document. *)

  | MenhirState015 : (('s, _menhir_box_document) _menhir_cell1_path_component, _menhir_box_document) _menhir_state
    (** State 015.
        Stack shape : path_component.
        Start symbol: document. *)

  | MenhirState026 : (('s, _menhir_box_document) _menhir_cell1_reference _menhir_cell0_comparison_operator, _menhir_box_document) _menhir_state
    (** State 026.
        Stack shape : reference comparison_operator.
        Start symbol: document. *)

  | MenhirState050 : (('s, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_state
    (** State 050.
        Stack shape : LBRACKET.
        Start symbol: document. *)

  | MenhirState051 : ((('s, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 051.
        Stack shape : LBRACKET separators.
        Start symbol: document. *)

  | MenhirState054 : (('s, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_state
    (** State 054.
        Stack shape : LBRACE.
        Start symbol: document. *)

  | MenhirState055 : ((('s, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 055.
        Stack shape : LBRACE separators.
        Start symbol: document. *)

  | MenhirState058 : ((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_path, _menhir_box_document) _menhir_state
    (** State 058.
        Stack shape : separators path.
        Start symbol: document. *)

  | MenhirState068 : ((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry, _menhir_box_document) _menhir_state
    (** State 068.
        Stack shape : separators object_entry.
        Start symbol: document. *)

  | MenhirState069 : (((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 069.
        Stack shape : separators object_entry separators.
        Start symbol: document. *)

  | MenhirState070 : ((((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA, _menhir_box_document) _menhir_state
    (** State 070.
        Stack shape : separators object_entry separators COMMA.
        Start symbol: document. *)

  | MenhirState071 : (((((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 071.
        Stack shape : separators object_entry separators COMMA separators.
        Start symbol: document. *)

  | MenhirState076 : ((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value, _menhir_box_document) _menhir_state
    (** State 076.
        Stack shape : separators value.
        Start symbol: document. *)

  | MenhirState077 : (((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 077.
        Stack shape : separators value separators.
        Start symbol: document. *)

  | MenhirState078 : ((((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA, _menhir_box_document) _menhir_state
    (** State 078.
        Stack shape : separators value separators COMMA.
        Start symbol: document. *)

  | MenhirState079 : (((((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 079.
        Stack shape : separators value separators COMMA separators.
        Start symbol: document. *)

  | MenhirState087 : (('s, _menhir_box_document) _menhir_cell1_condition_or, _menhir_box_document) _menhir_state
    (** State 087.
        Stack shape : condition_or.
        Start symbol: document. *)

  | MenhirState090 : (('s, _menhir_box_document) _menhir_cell1_condition_and, _menhir_box_document) _menhir_state
    (** State 090.
        Stack shape : condition_and.
        Start symbol: document. *)

  | MenhirState096 : ((('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_state
    (** State 096.
        Stack shape : WHEN condition.
        Start symbol: document. *)

  | MenhirState097 : (((('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 097.
        Stack shape : WHEN condition separators.
        Start symbol: document. *)

  | MenhirState098 : ((((('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_state
    (** State 098.
        Stack shape : WHEN condition separators LBRACE.
        Start symbol: document. *)

  | MenhirState099 : (((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 099.
        Stack shape : separators LBRACE separators.
        Start symbol: document. *)

  | MenhirState100 : (('s, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_state
    (** State 100.
        Stack shape : LBRACKET.
        Start symbol: document. *)

  | MenhirState102 : ((('s, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_state
    (** State 102.
        Stack shape : LBRACKET path RBRACKET.
        Start symbol: document. *)

  | MenhirState103 : (((('s, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 103.
        Stack shape : LBRACKET path RBRACKET separators.
        Start symbol: document. *)

  | MenhirState104 : ((((('s, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_state
    (** State 104.
        Stack shape : LBRACKET path RBRACKET separators LBRACE.
        Start symbol: document. *)

  | MenhirState111 : (('s, _menhir_box_document) _menhir_cell1_DEFINE _menhir_cell0_IDENTIFIER, _menhir_box_document) _menhir_state
    (** State 111.
        Stack shape : DEFINE IDENTIFIER.
        Start symbol: document. *)

  | MenhirState113 : (('s, _menhir_box_document) _menhir_cell1_DEFINE _menhir_cell0_IDENTIFIER, _menhir_box_document) _menhir_state
    (** State 113.
        Stack shape : DEFINE IDENTIFIER.
        Start symbol: document. *)

  | MenhirState116 : ((((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_state
    (** State 116.
        Stack shape : separators LBRACE separators statement.
        Start symbol: document. *)

  | MenhirState117 : ((('s, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_cell1_separators1, _menhir_box_document) _menhir_state
    (** State 117.
        Stack shape : statement separators1.
        Start symbol: document. *)

  | MenhirState118 : (((('s, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_cell1_separators1, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_state
    (** State 118.
        Stack shape : statement separators1 statement.
        Start symbol: document. *)

  | MenhirState128 : (('s, _menhir_box_document) _menhir_cell1_path _menhir_cell0_assignment_operator, _menhir_box_document) _menhir_state
    (** State 128.
        Stack shape : path assignment_operator.
        Start symbol: document. *)

  | MenhirState137 : (((((('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_block_statements _menhir_cell0_RBRACE, _menhir_box_document) _menhir_state
    (** State 137.
        Stack shape : WHEN condition separators LBRACE block_statements RBRACE.
        Start symbol: document. *)

  | MenhirState138 : ((((((('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_block_statements _menhir_cell0_RBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 138.
        Stack shape : WHEN condition separators LBRACE block_statements RBRACE separators.
        Start symbol: document. *)

  | MenhirState139 : (((((((('s, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_block_statements _menhir_cell0_RBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_state
    (** State 139.
        Stack shape : WHEN condition separators LBRACE block_statements RBRACE separators LBRACE.
        Start symbol: document. *)

  | MenhirState143 : ((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_state
    (** State 143.
        Stack shape : separators LBRACKET.
        Start symbol: document. *)

  | MenhirState145 : (((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_state
    (** State 145.
        Stack shape : separators LBRACKET path RBRACKET.
        Start symbol: document. *)

  | MenhirState146 : ((((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 146.
        Stack shape : separators LBRACKET path RBRACKET separators.
        Start symbol: document. *)

  | MenhirState147 : ((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_non_section_statement, _menhir_box_document) _menhir_state
    (** State 147.
        Stack shape : separators non_section_statement.
        Start symbol: document. *)

  | MenhirState148 : (((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_non_section_statement, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 148.
        Stack shape : separators non_section_statement separators.
        Start symbol: document. *)

  | MenhirState159 : ((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_document_item, _menhir_box_document) _menhir_state
    (** State 159.
        Stack shape : separators document_item.
        Start symbol: document. *)

  | MenhirState160 : (((('s, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_document_item, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_state
    (** State 160.
        Stack shape : separators document_item separators.
        Start symbol: document. *)


and 's _menhir_cell0_assignment_operator = 
  | MenhirCell0_assignment_operator of 's * (Statement.assignment_operator)

and ('s, 'r) _menhir_cell1_block_statements = 
  | MenhirCell1_block_statements of 's * ('s, 'r) _menhir_state * (Statement.t Node.t list)

and 's _menhir_cell0_comparison_operator = 
  | MenhirCell0_comparison_operator of 's * (Statement.comparison_operator)

and ('s, 'r) _menhir_cell1_condition = 
  | MenhirCell1_condition of 's * ('s, 'r) _menhir_state * (Statement.condition Node.t)

and ('s, 'r) _menhir_cell1_condition_and = 
  | MenhirCell1_condition_and of 's * ('s, 'r) _menhir_state * (Statement.condition Node.t) * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_condition_or = 
  | MenhirCell1_condition_or of 's * ('s, 'r) _menhir_state * (Statement.condition Node.t) * Lexing.position

and ('s, 'r) _menhir_cell1_document_item = 
  | MenhirCell1_document_item of 's * ('s, 'r) _menhir_state * (Statement.t Node.t)

and ('s, 'r) _menhir_cell1_non_section_statement = 
  | MenhirCell1_non_section_statement of 's * ('s, 'r) _menhir_state * (Statement.t Node.t)

and ('s, 'r) _menhir_cell1_object_entry = 
  | MenhirCell1_object_entry of 's * ('s, 'r) _menhir_state * (Value.object_entry)

and ('s, 'r) _menhir_cell1_path = 
  | MenhirCell1_path of 's * ('s, 'r) _menhir_state * (Statement.section_name) * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_path_component = 
  | MenhirCell1_path_component of 's * ('s, 'r) _menhir_state * (string) * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_reference = 
  | MenhirCell1_reference of 's * ('s, 'r) _menhir_state * (Value.reference) * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_separators = 
  | MenhirCell1_separators of 's * ('s, 'r) _menhir_state * (unit)

and ('s, 'r) _menhir_cell1_separators1 = 
  | MenhirCell1_separators1 of 's * ('s, 'r) _menhir_state * (unit)

and ('s, 'r) _menhir_cell1_statement = 
  | MenhirCell1_statement of 's * ('s, 'r) _menhir_state * (Statement.t Node.t)

and ('s, 'r) _menhir_cell1_value = 
  | MenhirCell1_value of 's * ('s, 'r) _menhir_state * (Value.t Node.t) * Lexing.position

and ('s, 'r) _menhir_cell1_COMMA = 
  | MenhirCell1_COMMA of 's * ('s, 'r) _menhir_state

and ('s, 'r) _menhir_cell1_DEFINE = 
  | MenhirCell1_DEFINE of 's * ('s, 'r) _menhir_state * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_DOLLAR = 
  | MenhirCell1_DOLLAR of 's * ('s, 'r) _menhir_state * Lexing.position

and 's _menhir_cell0_IDENTIFIER = 
  | MenhirCell0_IDENTIFIER of 's * 
# 152 "lib/parser/parser.mly"
       (string)
# 536 "lib/parser/parser.ml"
 * Lexing.position * Lexing.position

and 's _menhir_cell0_INTEGER = 
  | MenhirCell0_INTEGER of 's * 
# 154 "lib/parser/parser.mly"
       (int64)
# 543 "lib/parser/parser.ml"
 * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_LBRACE = 
  | MenhirCell1_LBRACE of 's * ('s, 'r) _menhir_state * Lexing.position

and ('s, 'r) _menhir_cell1_LBRACKET = 
  | MenhirCell1_LBRACKET of 's * ('s, 'r) _menhir_state * Lexing.position

and ('s, 'r) _menhir_cell1_LPAREN = 
  | MenhirCell1_LPAREN of 's * ('s, 'r) _menhir_state * Lexing.position

and 's _menhir_cell0_LPAREN = 
  | MenhirCell0_LPAREN of 's * Lexing.position

and ('s, 'r) _menhir_cell1_NOT = 
  | MenhirCell1_NOT of 's * ('s, 'r) _menhir_state * Lexing.position

and 's _menhir_cell0_RBRACE = 
  | MenhirCell0_RBRACE of 's * Lexing.position

and 's _menhir_cell0_RBRACKET = 
  | MenhirCell0_RBRACKET of 's * Lexing.position

and ('s, 'r) _menhir_cell1_RGBA = 
  | MenhirCell1_RGBA of 's * ('s, 'r) _menhir_state * Lexing.position * Lexing.position

and ('s, 'r) _menhir_cell1_WHEN = 
  | MenhirCell1_WHEN of 's * ('s, 'r) _menhir_state * Lexing.position * Lexing.position

and _menhir_box_document = 
  | MenhirBox_document of (Statement.t Node.t list) [@@unboxed]

let _menhir_action_01 =
  fun _3 ->
    (
# 674 "lib/parser/parser.mly"
    (
      _3
    )
# 583 "lib/parser/parser.ml"
     : (Value.t Node.t list))

let _menhir_action_02 =
  fun () ->
    (
# 681 "lib/parser/parser.mly"
    (
      []
    )
# 593 "lib/parser/parser.ml"
     : (Value.t Node.t list))

let _menhir_action_03 =
  fun _1 _2 ->
    (
# 686 "lib/parser/parser.mly"
    (
      _1 :: _2
    )
# 603 "lib/parser/parser.ml"
     : (Value.t Node.t list))

let _menhir_action_04 =
  fun () ->
    (
# 693 "lib/parser/parser.mly"
    (
      []
    )
# 613 "lib/parser/parser.ml"
     : (Value.t Node.t list))

let _menhir_action_05 =
  fun _4 ->
    (
# 698 "lib/parser/parser.mly"
    (
      _4
    )
# 623 "lib/parser/parser.ml"
     : (Value.t Node.t list))

let _menhir_action_06 =
  fun _1 _2 _3 ->
    (
# 350 "lib/parser/parser.mly"
    (
      {
        Statement.key = _1;
        operator = _2;
        value = _3;
      }
    )
# 637 "lib/parser/parser.ml"
     : (Statement.assignment))

let _menhir_action_07 =
  fun () ->
    (
# 361 "lib/parser/parser.mly"
    (
      Statement.Assign
    )
# 647 "lib/parser/parser.ml"
     : (Statement.assignment_operator))

let _menhir_action_08 =
  fun () ->
    (
# 366 "lib/parser/parser.mly"
    (
      Statement.Define_assign
    )
# 657 "lib/parser/parser.ml"
     : (Statement.assignment_operator))

let _menhir_action_09 =
  fun () ->
    (
# 371 "lib/parser/parser.mly"
    (
      Statement.Add_assign
    )
# 667 "lib/parser/parser.ml"
     : (Statement.assignment_operator))

let _menhir_action_10 =
  fun () ->
    (
# 376 "lib/parser/parser.mly"
    (
      Statement.Sub_assign
    )
# 677 "lib/parser/parser.ml"
     : (Statement.assignment_operator))

let _menhir_action_11 =
  fun () ->
    (
# 484 "lib/parser/parser.mly"
    (
      []
    )
# 687 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_12 =
  fun () ->
    (
# 489 "lib/parser/parser.mly"
    (
      []
    )
# 697 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_13 =
  fun _2 _3 ->
    (
# 494 "lib/parser/parser.mly"
    (
      _2 :: _3
    )
# 707 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_14 =
  fun _2 ->
    (
# 465 "lib/parser/parser.mly"
    (
      _2
    )
# 717 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_15 =
  fun () ->
    (
# 834 "lib/parser/parser.mly"
    (
      Statement.Equal
    )
# 727 "lib/parser/parser.ml"
     : (Statement.comparison_operator))

let _menhir_action_16 =
  fun () ->
    (
# 839 "lib/parser/parser.mly"
    (
      Statement.Not_equal
    )
# 737 "lib/parser/parser.ml"
     : (Statement.comparison_operator))

let _menhir_action_17 =
  fun () ->
    (
# 844 "lib/parser/parser.mly"
    (
      Statement.Less
    )
# 747 "lib/parser/parser.ml"
     : (Statement.comparison_operator))

let _menhir_action_18 =
  fun () ->
    (
# 849 "lib/parser/parser.mly"
    (
      Statement.Less_equal
    )
# 757 "lib/parser/parser.ml"
     : (Statement.comparison_operator))

let _menhir_action_19 =
  fun () ->
    (
# 854 "lib/parser/parser.mly"
    (
      Statement.Greater
    )
# 767 "lib/parser/parser.ml"
     : (Statement.comparison_operator))

let _menhir_action_20 =
  fun () ->
    (
# 859 "lib/parser/parser.mly"
    (
      Statement.Greater_equal
    )
# 777 "lib/parser/parser.ml"
     : (Statement.comparison_operator))

let _menhir_action_21 =
  fun _1 ->
    (
# 748 "lib/parser/parser.mly"
    (
      _1
    )
# 787 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_22 =
  fun _1 ->
    (
# 773 "lib/parser/parser.mly"
    (
      _1
    )
# 797 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_23 =
  fun _1 _3 _endpos__3_ _startpos__1_ ->
    let _endpos = _endpos__3_ in
    let _startpos = _startpos__1_ in
    (
# 778 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Logical
           {
             left = _1;
             operator = Statement.And;
             right = _3;
           })
    )
# 815 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_24 =
  fun _1 ->
    (
# 791 "lib/parser/parser.mly"
    (
      _1
    )
# 825 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_25 =
  fun _2 _endpos__2_ _startpos__1_ ->
    let _endpos = _endpos__2_ in
    let _startpos = _startpos__1_ in
    (
# 796 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Not _2)
    )
# 838 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_26 =
  fun _1 ->
    (
# 755 "lib/parser/parser.mly"
    (
      _1
    )
# 848 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_27 =
  fun _1 _3 _endpos__3_ _startpos__1_ ->
    let _endpos = _endpos__3_ in
    let _startpos = _startpos__1_ in
    (
# 760 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Logical
           {
             left = _1;
             operator = Statement.Or;
             right = _3;
           })
    )
# 866 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_28 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 804 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Boolean _1)
    )
# 879 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_29 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 810 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Reference _1)
    )
# 892 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_30 =
  fun _1 _2 _3 _endpos__3_ _startpos__1_ ->
    let _endpos = _endpos__3_ in
    let _startpos = _startpos__1_ in
    (
# 816 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Compare
           {
             reference = _1;
             operator = _2;
             value = _3;
           })
    )
# 910 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_31 =
  fun _2 ->
    (
# 827 "lib/parser/parser.mly"
    (
      _2
    )
# 920 "lib/parser/parser.ml"
     : (Statement.condition Node.t))

let _menhir_action_32 =
  fun _2 _5 _7 ->
    (
# 437 "lib/parser/parser.mly"
    (
      {
        Statement.condition = _2;
        then_branch = _5;
        else_branch = _7;
      }
    )
# 934 "lib/parser/parser.ml"
     : (Statement.conditional))

let _menhir_action_33 =
  fun _2 _4 ->
    (
# 392 "lib/parser/parser.mly"
    (
      {
        Statement.name = _2;
        value = _4;
      }
    )
# 947 "lib/parser/parser.ml"
     : (Statement.define_statement))

let _menhir_action_34 =
  fun _2 _4 ->
    (
# 400 "lib/parser/parser.mly"
    (
      {
        Statement.name = _2;
        value = _4;
      }
    )
# 960 "lib/parser/parser.ml"
     : (Statement.define_statement))

let _menhir_action_35 =
  fun _2 ->
    (
# 268 "lib/parser/parser.mly"
    (
      _2
    )
# 970 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_36 =
  fun _1 ->
    (
# 287 "lib/parser/parser.mly"
    (
      _1
    )
# 980 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_37 =
  fun _1 ->
    (
# 292 "lib/parser/parser.mly"
    (
      _1
    )
# 990 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_38 =
  fun () ->
    (
# 275 "lib/parser/parser.mly"
    (
      []
    )
# 1000 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_39 =
  fun _1 _3 ->
    (
# 280 "lib/parser/parser.mly"
    (
      _1 :: _3
    )
# 1010 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_40 =
  fun _2 ->
    (
# 383 "lib/parser/parser.mly"
    (
      {
        Statement.path = _2;
      }
    )
# 1022 "lib/parser/parser.ml"
     : (Statement.include_statement))

let _menhir_action_41 =
  fun _2 _5 _endpos__5_ _startpos__1_ ->
    let _endpos = _endpos__5_ in
    let _startpos = _startpos__1_ in
    (
# 299 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Section
          {
            Statement.name = _2;
            body = _5;
          })
    )
# 1039 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_42 =
  fun () ->
    (
# 311 "lib/parser/parser.mly"
    (
      []
    )
# 1049 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_43 =
  fun _1 _3 ->
    (
# 316 "lib/parser/parser.mly"
    (
      _1 :: _3
    )
# 1059 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_44 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 323 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Assignment _1)
    )
# 1072 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_45 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 329 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Include _1)
    )
# 1085 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_46 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 335 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Define _1)
    )
# 1098 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_47 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 341 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Conditional _1)
    )
# 1111 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_48 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 660 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Integer _1)
    )
# 1124 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_49 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 666 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Float _1)
    )
# 1137 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_50 =
  fun () ->
    (
# 713 "lib/parser/parser.mly"
    (
      []
    )
# 1147 "lib/parser/parser.ml"
     : (Value.object_entry list))

let _menhir_action_51 =
  fun _1 _2 ->
    (
# 718 "lib/parser/parser.mly"
    (
      _1 :: _2
    )
# 1157 "lib/parser/parser.ml"
     : (Value.object_entry list))

let _menhir_action_52 =
  fun _1 _3 _endpos__3_ _startpos__1_ ->
    let _endpos = _endpos__3_ in
    let _startpos = _startpos__1_ in
    (
# 737 "lib/parser/parser.mly"
    (
      object_entry
        _1
        _3
        _startpos
        _endpos
    )
# 1173 "lib/parser/parser.ml"
     : (Value.object_entry))

let _menhir_action_53 =
  fun () ->
    (
# 725 "lib/parser/parser.mly"
    (
      []
    )
# 1183 "lib/parser/parser.ml"
     : (Value.object_entry list))

let _menhir_action_54 =
  fun _4 ->
    (
# 730 "lib/parser/parser.mly"
    (
      _4
    )
# 1193 "lib/parser/parser.ml"
     : (Value.object_entry list))

let _menhir_action_55 =
  fun _3 ->
    (
# 706 "lib/parser/parser.mly"
    (
      _3
    )
# 1203 "lib/parser/parser.ml"
     : (Value.object_entry list))

let _menhir_action_56 =
  fun () ->
    (
# 448 "lib/parser/parser.mly"
    (
      None
    )
# 1213 "lib/parser/parser.ml"
     : (Statement.t Node.t list option))

let _menhir_action_57 =
  fun _4 ->
    (
# 457 "lib/parser/parser.mly"
    (
      Some _4
    )
# 1223 "lib/parser/parser.ml"
     : (Statement.t Node.t list option))

let _menhir_action_58 =
  fun _1 ->
    (
# 525 "lib/parser/parser.mly"
    ( [_1] )
# 1231 "lib/parser/parser.ml"
     : (Statement.section_name))

let _menhir_action_59 =
  fun _1 _3 ->
    (
# 527 "lib/parser/parser.mly"
    ( _1 :: _3 )
# 1239 "lib/parser/parser.ml"
     : (Statement.section_name))

let _menhir_action_60 =
  fun _1 ->
    (
# 501 "lib/parser/parser.mly"
    ( _1 )
# 1247 "lib/parser/parser.ml"
     : (string))

let _menhir_action_61 =
  fun () ->
    (
# 503 "lib/parser/parser.mly"
    ( "null" )
# 1255 "lib/parser/parser.ml"
     : (string))

let _menhir_action_62 =
  fun () ->
    (
# 505 "lib/parser/parser.mly"
    ( "include" )
# 1263 "lib/parser/parser.ml"
     : (string))

let _menhir_action_63 =
  fun () ->
    (
# 507 "lib/parser/parser.mly"
    ( "when" )
# 1271 "lib/parser/parser.ml"
     : (string))

let _menhir_action_64 =
  fun () ->
    (
# 509 "lib/parser/parser.mly"
    ( "rgb" )
# 1279 "lib/parser/parser.ml"
     : (string))

let _menhir_action_65 =
  fun () ->
    (
# 511 "lib/parser/parser.mly"
    ( "rgba" )
# 1287 "lib/parser/parser.ml"
     : (string))

let _menhir_action_66 =
  fun () ->
    (
# 513 "lib/parser/parser.mly"
    ( "define" )
# 1295 "lib/parser/parser.ml"
     : (string))

let _menhir_action_67 =
  fun _1 ->
    (
# 515 "lib/parser/parser.mly"
    (
      if _1 then
        "true"
      else
        "false"
    )
# 1308 "lib/parser/parser.ml"
     : (string))

let _menhir_action_68 =
  fun _2 ->
    (
# 532 "lib/parser/parser.mly"
    (
      _2
    )
# 1318 "lib/parser/parser.ml"
     : (Value.reference))

let _menhir_action_69 =
  fun _2 ->
    (
# 410 "lib/parser/parser.mly"
    (
      {
        Statement.name = _2;
        body = [];
      }
    )
# 1331 "lib/parser/parser.ml"
     : (Statement.section))

let _menhir_action_70 =
  fun _2 _6 ->
    (
# 422 "lib/parser/parser.mly"
    (
      {
        Statement.name = _2;
        body = _6;
      }
    )
# 1344 "lib/parser/parser.ml"
     : (Statement.section))

let _menhir_action_71 =
  fun () ->
    (
# 229 "lib/parser/parser.mly"
    (
      ()
    )
# 1354 "lib/parser/parser.ml"
     : (unit))

let _menhir_action_72 =
  fun () ->
    (
# 233 "lib/parser/parser.mly"
    (
      ()
    )
# 1364 "lib/parser/parser.ml"
     : (unit))

let _menhir_action_73 =
  fun () ->
    (
# 207 "lib/parser/parser.mly"
    (
      ()
    )
# 1374 "lib/parser/parser.ml"
     : (unit))

let _menhir_action_74 =
  fun () ->
    (
# 211 "lib/parser/parser.mly"
    (
      ()
    )
# 1384 "lib/parser/parser.ml"
     : (unit))

let _menhir_action_75 =
  fun () ->
    (
# 218 "lib/parser/parser.mly"
    (
      ()
    )
# 1394 "lib/parser/parser.ml"
     : (unit))

let _menhir_action_76 =
  fun () ->
    (
# 222 "lib/parser/parser.mly"
    (
      ()
    )
# 1404 "lib/parser/parser.ml"
     : (unit))

let _menhir_action_77 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 240 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Assignment _1)
    )
# 1417 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_78 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 245 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Include _1)
    )
# 1430 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_79 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 250 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Define _1)
    )
# 1443 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_80 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 255 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Section _1)
    )
# 1456 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_81 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 260 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Conditional _1)
    )
# 1469 "lib/parser/parser.ml"
     : (Statement.t Node.t))

let _menhir_action_82 =
  fun () ->
    (
# 472 "lib/parser/parser.mly"
    (
      []
    )
# 1479 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_83 =
  fun _1 _2 ->
    (
# 477 "lib/parser/parser.mly"
    (
      _1 :: _2
    )
# 1489 "lib/parser/parser.ml"
     : (Statement.t Node.t list))

let _menhir_action_84 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 539 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.String _1)
    )
# 1502 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_85 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 545 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Integer _1)
    )
# 1515 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_86 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 551 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Float _1)
    )
# 1528 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_87 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 557 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Boolean _1)
    )
# 1541 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_88 =
  fun _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 563 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        Value.Null
    )
# 1554 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_89 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 569 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Reference _1)
    )
# 1567 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_90 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 575 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Color (color_of_hex _1))
    )
# 1580 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_91 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 581 "lib/parser/parser.mly"
    (
      let amount, unit = _1 in
      located _startpos _endpos
        (Value.Duration (amount, unit))
    )
# 1594 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_92 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 588 "lib/parser/parser.mly"
    (
      let amount, unit = _1 in
      located _startpos _endpos
        (Value.Size (amount, unit))
    )
# 1608 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_93 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 595 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Array _1)
    )
# 1621 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_94 =
  fun _1 _endpos__1_ _startpos__1_ ->
    let _endpos = _endpos__1_ in
    let _startpos = _startpos__1_ in
    (
# 601 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Object _1)
    )
# 1634 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_95 =
  fun _3 _5 _7 _endpos__8_ _startpos__1_ ->
    let _endpos = _endpos__8_ in
    let _startpos = _startpos__1_ in
    (
# 607 "lib/parser/parser.mly"
    (
      let red = int_of_int64_checked _3 in
      let green = int_of_int64_checked _5 in
      let blue = int_of_int64_checked _7 in

      if
        red < 0 || red > 255
        || green < 0 || green > 255
        || blue < 0 || blue > 255
      then
        invalid_arg "RGB component outside 0..255";

      located _startpos _endpos
        (Value.Color
           (Value.Rgb
              {
                red;
                green;
                blue;
              }))
    )
# 1664 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_action_96 =
  fun _3 _5 _7 _9 _endpos__10_ _startpos__1_ ->
    let _endpos = _endpos__10_ in
    let _startpos = _startpos__1_ in
    (
# 630 "lib/parser/parser.mly"
    (
      let red = int_of_int64_checked _3 in
      let green = int_of_int64_checked _5 in
      let blue = int_of_int64_checked _7 in
      let alpha = alpha_of_value _9 in

      if
        red < 0 || red > 255
        || green < 0 || green > 255
        || blue < 0 || blue > 255
      then
        invalid_arg "RGBA component outside 0..255";

      if alpha < 0.0 || alpha > 1.0 then
        invalid_arg "RGBA alpha outside 0.0..1.0";

      located _startpos _endpos
        (Value.Color
           (Value.Rgba
              {
                red;
                green;
                blue;
                alpha;
              }))
    )
# 1699 "lib/parser/parser.ml"
     : (Value.t Node.t))

let _menhir_print_token : token -> string =
  fun _tok ->
    match _tok with
    | WHEN ->
        "WHEN"
    | SUB_ASSIGN ->
        "SUB_ASSIGN"
    | STRING _ ->
        "STRING"
    | SIZE _ ->
        "SIZE"
    | SEMICOLON ->
        "SEMICOLON"
    | RPAREN ->
        "RPAREN"
    | RGBA ->
        "RGBA"
    | RGB ->
        "RGB"
    | RBRACKET ->
        "RBRACKET"
    | RBRACE ->
        "RBRACE"
    | OR ->
        "OR"
    | NULL ->
        "NULL"
    | NOT ->
        "NOT"
    | NEWLINE ->
        "NEWLINE"
    | NEQ ->
        "NEQ"
    | LTE ->
        "LTE"
    | LT ->
        "LT"
    | LPAREN ->
        "LPAREN"
    | LBRACKET ->
        "LBRACKET"
    | LBRACE ->
        "LBRACE"
    | INTEGER _ ->
        "INTEGER"
    | INCLUDE ->
        "INCLUDE"
    | IDENTIFIER _ ->
        "IDENTIFIER"
    | GTE ->
        "GTE"
    | GT ->
        "GT"
    | FLOAT _ ->
        "FLOAT"
    | EQEQ ->
        "EQEQ"
    | EOF ->
        "EOF"
    | ELSE ->
        "ELSE"
    | DURATION _ ->
        "DURATION"
    | DOT ->
        "DOT"
    | DOLLAR ->
        "DOLLAR"
    | DEFINE_ASSIGN ->
        "DEFINE_ASSIGN"
    | DEFINE ->
        "DEFINE"
    | COMMA ->
        "COMMA"
    | COLOR _ ->
        "COLOR"
    | COLON ->
        "COLON"
    | BOOLEAN _ ->
        "BOOLEAN"
    | ASSIGN ->
        "ASSIGN"
    | AND ->
        "AND"
    | ADD_ASSIGN ->
        "ADD_ASSIGN"

let _menhir_fail : unit -> 'a =
  fun () ->
    Printf.eprintf "Internal failure -- please contact the parser generator's developers.\n%!";
    assert false

include struct
  
  [@@@ocaml.warning "-4-37"]
  
  let _menhir_run_157 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_separators -> _ -> _menhir_box_document =
    fun _menhir_stack _v ->
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let _2 = _v in
      let _v = _menhir_action_35 _2 in
      MenhirBox_document _v
  
  let rec _menhir_run_161 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_document_item, _menhir_box_document) _menhir_cell1_separators -> _ -> _menhir_box_document =
    fun _menhir_stack _v ->
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_document_item (_menhir_stack, _menhir_s, _1) = _menhir_stack in
      let _3 = _v in
      let _v = _menhir_action_39 _1 _3 in
      _menhir_goto_document_items _menhir_stack _v _menhir_s
  
  and _menhir_goto_document_items : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _v _menhir_s ->
      match _menhir_s with
      | MenhirState001 ->
          _menhir_run_157 _menhir_stack _v
      | MenhirState160 ->
          _menhir_run_161 _menhir_stack _v
      | _ ->
          _menhir_fail ()
  
  let rec _menhir_run_001 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_002 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | LBRACKET ->
          _menhir_run_143 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | INCLUDE ->
          _menhir_run_107 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState001
      | DEFINE ->
          _menhir_run_109 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState001
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState001
      | EOF ->
          let _v_2 = _menhir_action_38 () in
          _menhir_run_157 _menhir_stack _v_2
      | _ ->
          _eRR ()
  
  and _menhir_run_002 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | NOT ->
          let _menhir_stack = MenhirCell1_WHEN (_menhir_stack, _menhir_s, _startpos, _endpos) in
          _menhir_run_003 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState002
      | LPAREN ->
          let _menhir_stack = MenhirCell1_WHEN (_menhir_stack, _menhir_s, _startpos, _endpos) in
          _menhir_run_004 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState002
      | DOLLAR ->
          let _menhir_stack = MenhirCell1_WHEN (_menhir_stack, _menhir_s, _startpos, _endpos) in
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState002
      | BOOLEAN _v ->
          let _menhir_stack = MenhirCell1_WHEN (_menhir_stack, _menhir_s, _startpos, _endpos) in
          _menhir_run_018 _menhir_stack _menhir_lexbuf _menhir_lexer _v MenhirState002
      | ADD_ASSIGN | ASSIGN | DEFINE_ASSIGN | DOT | SUB_ASSIGN ->
          let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
          let _v = _menhir_action_63 () in
          _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_003 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_NOT (_menhir_stack, _menhir_s, _startpos) in
      let _menhir_s = MenhirState003 in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | NOT ->
          _menhir_run_003 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | LPAREN ->
          _menhir_run_004 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | BOOLEAN _v ->
          _menhir_run_018 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_004 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_LPAREN (_menhir_stack, _menhir_s, _startpos) in
      let _menhir_s = MenhirState004 in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | NOT ->
          _menhir_run_003 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | LPAREN ->
          _menhir_run_004 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | BOOLEAN _v ->
          _menhir_run_018 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_005 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_DOLLAR (_menhir_stack, _menhir_s, _startpos) in
      let _menhir_s = MenhirState005 in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_006 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | INCLUDE ->
          _menhir_run_010 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | IDENTIFIER _v ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | DEFINE ->
          _menhir_run_012 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | BOOLEAN _v ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_006 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_63 () in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_path_component : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | DOT ->
          let _menhir_stack = MenhirCell1_path_component (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _menhir_s = MenhirState015 in
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | WHEN ->
              _menhir_run_006 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | RGBA ->
              _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | RGB ->
              _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | NULL ->
              _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | INCLUDE ->
              _menhir_run_010 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | IDENTIFIER _v ->
              _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | DEFINE ->
              _menhir_run_012 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | BOOLEAN _v ->
              _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | _ ->
              _eRR ())
      | ADD_ASSIGN | AND | ASSIGN | BOOLEAN _ | COLON | COMMA | DEFINE | DEFINE_ASSIGN | EOF | EQEQ | GT | GTE | IDENTIFIER _ | INCLUDE | LBRACE | LBRACKET | LT | LTE | NEQ | NEWLINE | NULL | OR | RBRACE | RBRACKET | RGB | RGBA | RPAREN | SEMICOLON | SUB_ASSIGN | WHEN ->
          let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
          let _v = _menhir_action_58 _1 in
          _menhir_goto_path _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_007 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_65 () in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_008 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_64 () in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_009 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_61 () in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_010 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_62 () in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_011 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_60 _1 in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_012 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_66 () in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_013 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_67 _1 in
      _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_path : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState015 ->
          _menhir_run_016 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState005 ->
          _menhir_run_017 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState055 ->
          _menhir_run_057 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState071 ->
          _menhir_run_057 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState100 ->
          _menhir_run_101 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState001 ->
          _menhir_run_123 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState099 ->
          _menhir_run_123 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_123 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState146 ->
          _menhir_run_123 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState148 ->
          _menhir_run_123 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState160 ->
          _menhir_run_123 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState143 ->
          _menhir_run_144 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_016 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_path_component -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_path_component (_menhir_stack, _menhir_s, _1, _startpos__1_, _) = _menhir_stack in
      let (_endpos__3_, _3) = (_endpos, _v) in
      let _v = _menhir_action_59 _1 _3 in
      _menhir_goto_path _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_017 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_DOLLAR -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_DOLLAR (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
      let (_endpos__2_, _2) = (_endpos, _v) in
      let _v = _menhir_action_68 _2 in
      _menhir_goto_reference _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__2_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_reference : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState002 ->
          _menhir_run_019 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState003 ->
          _menhir_run_019 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState004 ->
          _menhir_run_019 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState087 ->
          _menhir_run_019 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState090 ->
          _menhir_run_019 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState026 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState051 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState058 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState079 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState111 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState113 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState128 ->
          _menhir_run_065 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_019 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | NEQ ->
          let _menhir_stack = MenhirCell1_reference (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_16 () in
          _menhir_goto_comparison_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | LTE ->
          let _menhir_stack = MenhirCell1_reference (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_18 () in
          _menhir_goto_comparison_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | LT ->
          let _menhir_stack = MenhirCell1_reference (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_17 () in
          _menhir_goto_comparison_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | GTE ->
          let _menhir_stack = MenhirCell1_reference (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_20 () in
          _menhir_goto_comparison_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | GT ->
          let _menhir_stack = MenhirCell1_reference (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_19 () in
          _menhir_goto_comparison_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | EQEQ ->
          let _menhir_stack = MenhirCell1_reference (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_15 () in
          _menhir_goto_comparison_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | AND | LBRACE | NEWLINE | OR | RPAREN | SEMICOLON ->
          let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
          let _v = _menhir_action_29 _1 _endpos__1_ _startpos__1_ in
          _menhir_goto_condition_primary _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_goto_comparison_operator : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_reference -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok ->
      let _menhir_stack = MenhirCell0_comparison_operator (_menhir_stack, _v) in
      match (_tok : MenhirBasics.token) with
      | STRING _v_0 ->
          _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState026
      | SIZE _v_1 ->
          _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState026
      | RGBA ->
          _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState026
      | RGB ->
          _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState026
      | NULL ->
          _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState026
      | LBRACKET ->
          _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState026
      | LBRACE ->
          _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState026
      | INTEGER _v_2 ->
          _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v_2 MenhirState026
      | FLOAT _v_3 ->
          _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v_3 MenhirState026
      | DURATION _v_4 ->
          _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v_4 MenhirState026
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState026
      | COLOR _v_5 ->
          _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v_5 MenhirState026
      | BOOLEAN _v_6 ->
          _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v_6 MenhirState026
      | _ ->
          _eRR ()
  
  and _menhir_run_027 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_84 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_value : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState058 ->
          _menhir_run_064 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState051 ->
          _menhir_run_076 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
      | MenhirState079 ->
          _menhir_run_076 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
      | MenhirState026 ->
          _menhir_run_084 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState111 ->
          _menhir_run_112 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState113 ->
          _menhir_run_114 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState128 ->
          _menhir_run_129 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_064 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_path -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_path (_menhir_stack, _menhir_s, _1, _startpos__1_, _) = _menhir_stack in
      let (_endpos__3_, _3) = (_endpos, _v) in
      let _v = _menhir_action_52 _1 _3 _endpos__3_ _startpos__1_ in
      let _menhir_stack = MenhirCell1_object_entry (_menhir_stack, _menhir_s, _v) in
      let _v_0 = _menhir_action_73 () in
      _menhir_run_069 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState068 _tok
  
  and _menhir_run_069 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState069
      | NEWLINE ->
          let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState069
      | COMMA ->
          let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
          let _menhir_stack = MenhirCell1_COMMA (_menhir_stack, MenhirState069) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_0 = _menhir_action_73 () in
          _menhir_run_071 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState070 _tok
      | RBRACE ->
          let _v = _menhir_action_53 () in
          _menhir_goto_object_tail _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _eRR ()
  
  and _menhir_run_052 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let _ = _menhir_action_72 () in
      _menhir_goto_separator _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _menhir_s _tok
  
  and _menhir_goto_separator : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _menhir_s _tok ->
      match _menhir_s with
      | MenhirState001 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState051 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState055 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState069 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState071 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState077 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState079 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState097 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState099 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState103 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState138 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState146 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState148 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState160 ->
          _menhir_run_056 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok
      | MenhirState116 ->
          _menhir_run_119 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s _tok
      | MenhirState118 ->
          _menhir_run_119 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_121 _menhir_stack _menhir_lexbuf _menhir_lexer _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_056 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _tok ->
      let MenhirCell1_separators (_menhir_stack, _menhir_s, _) = _menhir_stack in
      let _v = _menhir_action_74 () in
      _menhir_goto_separators _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
  
  and _menhir_goto_separators : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState000 ->
          _menhir_run_001 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState050 ->
          _menhir_run_051 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState054 ->
          _menhir_run_055 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState068 ->
          _menhir_run_069 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState070 ->
          _menhir_run_071 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState076 ->
          _menhir_run_077 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState078 ->
          _menhir_run_079 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState096 ->
          _menhir_run_097 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState098 ->
          _menhir_run_099 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState104 ->
          _menhir_run_099 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState139 ->
          _menhir_run_099 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState102 ->
          _menhir_run_103 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState137 ->
          _menhir_run_138 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState145 ->
          _menhir_run_146 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
      | MenhirState147 ->
          _menhir_run_148 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
      | MenhirState159 ->
          _menhir_run_160 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_051 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACKET as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | STRING _v_0 ->
          _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState051
      | SIZE _v_1 ->
          _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState051
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | RGBA ->
          _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | RGB ->
          _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | NULL ->
          _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | LBRACKET ->
          _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | LBRACE ->
          _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | INTEGER _v_2 ->
          _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v_2 MenhirState051
      | FLOAT _v_3 ->
          _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v_3 MenhirState051
      | DURATION _v_4 ->
          _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v_4 MenhirState051
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState051
      | COLOR _v_5 ->
          _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v_5 MenhirState051
      | BOOLEAN _v_6 ->
          _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v_6 MenhirState051
      | RBRACKET ->
          let _v_7 = _menhir_action_02 () in
          _menhir_run_082 _menhir_stack _menhir_lexbuf _menhir_lexer _v_7
      | _ ->
          _eRR ()
  
  and _menhir_run_028 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_92 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_029 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _menhir_stack = MenhirCell1_RGBA (_menhir_stack, _menhir_s, _startpos, _endpos) in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | LPAREN ->
          let _startpos_0 = _menhir_lexbuf.Lexing.lex_start_p in
          let _menhir_stack = MenhirCell0_LPAREN (_menhir_stack, _startpos_0) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | INTEGER _v ->
              let _startpos_1 = _menhir_lexbuf.Lexing.lex_start_p in
              let _endpos_2 = _menhir_lexbuf.Lexing.lex_curr_p in
              let _menhir_stack = MenhirCell0_INTEGER (_menhir_stack, _v, _startpos_1, _endpos_2) in
              let _tok = _menhir_lexer _menhir_lexbuf in
              (match (_tok : MenhirBasics.token) with
              | COMMA ->
                  let _tok = _menhir_lexer _menhir_lexbuf in
                  (match (_tok : MenhirBasics.token) with
                  | INTEGER _v_3 ->
                      let _startpos_4 = _menhir_lexbuf.Lexing.lex_start_p in
                      let _endpos_5 = _menhir_lexbuf.Lexing.lex_curr_p in
                      let _menhir_stack = MenhirCell0_INTEGER (_menhir_stack, _v_3, _startpos_4, _endpos_5) in
                      let _tok = _menhir_lexer _menhir_lexbuf in
                      (match (_tok : MenhirBasics.token) with
                      | COMMA ->
                          let _tok = _menhir_lexer _menhir_lexbuf in
                          (match (_tok : MenhirBasics.token) with
                          | INTEGER _v_6 ->
                              let _startpos_7 = _menhir_lexbuf.Lexing.lex_start_p in
                              let _endpos_8 = _menhir_lexbuf.Lexing.lex_curr_p in
                              let _menhir_stack = MenhirCell0_INTEGER (_menhir_stack, _v_6, _startpos_7, _endpos_8) in
                              let _tok = _menhir_lexer _menhir_lexbuf in
                              (match (_tok : MenhirBasics.token) with
                              | COMMA ->
                                  let _tok = _menhir_lexer _menhir_lexbuf in
                                  (match (_tok : MenhirBasics.token) with
                                  | INTEGER _v_9 ->
                                      let _startpos_10 = _menhir_lexbuf.Lexing.lex_start_p in
                                      let _endpos_11 = _menhir_lexbuf.Lexing.lex_curr_p in
                                      let _tok = _menhir_lexer _menhir_lexbuf in
                                      let (_endpos__1_, _startpos__1_, _1) = (_endpos_11, _startpos_10, _v_9) in
                                      let _v = _menhir_action_48 _1 _endpos__1_ _startpos__1_ in
                                      _menhir_goto_numeric_value _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
                                  | FLOAT _v_13 ->
                                      let _startpos_14 = _menhir_lexbuf.Lexing.lex_start_p in
                                      let _endpos_15 = _menhir_lexbuf.Lexing.lex_curr_p in
                                      let _tok = _menhir_lexer _menhir_lexbuf in
                                      let (_endpos__1_, _startpos__1_, _1) = (_endpos_15, _startpos_14, _v_13) in
                                      let _v = _menhir_action_49 _1 _endpos__1_ _startpos__1_ in
                                      _menhir_goto_numeric_value _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
                                  | _ ->
                                      _eRR ())
                              | _ ->
                                  _eRR ())
                          | _ ->
                              _eRR ())
                      | _ ->
                          _eRR ())
                  | _ ->
                      _eRR ())
              | _ ->
                  _eRR ())
          | _ ->
              _eRR ())
      | _ ->
          _eRR ()
  
  and _menhir_goto_numeric_value : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_RGBA _menhir_cell0_LPAREN _menhir_cell0_INTEGER _menhir_cell0_INTEGER _menhir_cell0_INTEGER -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok ->
      match (_tok : MenhirBasics.token) with
      | RPAREN ->
          let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let MenhirCell0_INTEGER (_menhir_stack, _7, _, _) = _menhir_stack in
          let MenhirCell0_INTEGER (_menhir_stack, _5, _, _) = _menhir_stack in
          let MenhirCell0_INTEGER (_menhir_stack, _3, _, _) = _menhir_stack in
          let MenhirCell0_LPAREN (_menhir_stack, _) = _menhir_stack in
          let MenhirCell1_RGBA (_menhir_stack, _menhir_s, _startpos__1_, _) = _menhir_stack in
          let (_endpos__10_, _9) = (_endpos, _v) in
          let _v = _menhir_action_96 _3 _5 _7 _9 _endpos__10_ _startpos__1_ in
          _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__10_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_041 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | LPAREN ->
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | INTEGER _v ->
              let _tok = _menhir_lexer _menhir_lexbuf in
              (match (_tok : MenhirBasics.token) with
              | COMMA ->
                  let _tok = _menhir_lexer _menhir_lexbuf in
                  (match (_tok : MenhirBasics.token) with
                  | INTEGER _v_3 ->
                      let _tok = _menhir_lexer _menhir_lexbuf in
                      (match (_tok : MenhirBasics.token) with
                      | COMMA ->
                          let _tok = _menhir_lexer _menhir_lexbuf in
                          (match (_tok : MenhirBasics.token) with
                          | INTEGER _v_6 ->
                              let _tok = _menhir_lexer _menhir_lexbuf in
                              (match (_tok : MenhirBasics.token) with
                              | RPAREN ->
                                  let _endpos_9 = _menhir_lexbuf.Lexing.lex_curr_p in
                                  let _tok = _menhir_lexer _menhir_lexbuf in
                                  let (_startpos__1_, _3, _5, _7, _endpos__8_) = (_startpos, _v, _v_3, _v_6, _endpos_9) in
                                  let _v = _menhir_action_95 _3 _5 _7 _endpos__8_ _startpos__1_ in
                                  _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__8_ _v _menhir_s _tok
                              | _ ->
                                  _eRR ())
                          | _ ->
                              _eRR ())
                      | _ ->
                          _eRR ())
                  | _ ->
                      _eRR ())
              | _ ->
                  _eRR ())
          | _ ->
              _eRR ())
      | _ ->
          _eRR ()
  
  and _menhir_run_049 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
      let _v = _menhir_action_88 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_053 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let _ = _menhir_action_71 () in
      _menhir_goto_separator _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _menhir_s _tok
  
  and _menhir_run_050 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos) in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let _v = _menhir_action_73 () in
      _menhir_run_051 _menhir_stack _menhir_lexbuf _menhir_lexer _v MenhirState050 _tok
  
  and _menhir_run_054 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_LBRACE (_menhir_stack, _menhir_s, _startpos) in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let _v = _menhir_action_73 () in
      _menhir_run_055 _menhir_stack _menhir_lexbuf _menhir_lexer _v MenhirState054 _tok
  
  and _menhir_run_055 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACE as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_006 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | INCLUDE ->
          _menhir_run_010 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState055
      | DEFINE ->
          _menhir_run_012 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState055
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState055
      | RBRACE ->
          let _v_2 = _menhir_action_50 () in
          _menhir_run_074 _menhir_stack _menhir_lexbuf _menhir_lexer _v_2
      | _ ->
          _eRR ()
  
  and _menhir_run_074 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_LBRACE (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
      let (_3, _endpos__4_) = (_v, _endpos) in
      let _v = _menhir_action_55 _3 in
      let (_endpos, _startpos) = (_endpos__4_, _startpos__1_) in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_94 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_059 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_85 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_060 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_86 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_061 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_91 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_062 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_90 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_063 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_87 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_082 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
      let (_3, _endpos__4_) = (_v, _endpos) in
      let _v = _menhir_action_01 _3 in
      let (_endpos, _startpos) = (_endpos__4_, _startpos__1_) in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_93 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_071 : type  ttv_stack. (((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_006 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | INCLUDE ->
          _menhir_run_010 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState071
      | DEFINE ->
          _menhir_run_012 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState071
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState071
      | RBRACE ->
          let _v_2 = _menhir_action_50 () in
          _menhir_run_072 _menhir_stack _menhir_lexbuf _menhir_lexer _v_2
      | _ ->
          _eRR ()
  
  and _menhir_run_072 : type  ttv_stack. (((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_COMMA (_menhir_stack, _) = _menhir_stack in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let _4 = _v in
      let _v = _menhir_action_54 _4 in
      _menhir_goto_object_tail _menhir_stack _menhir_lexbuf _menhir_lexer _v
  
  and _menhir_goto_object_tail : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_object_entry -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_object_entry (_menhir_stack, _menhir_s, _1) = _menhir_stack in
      let _2 = _v in
      let _v = _menhir_action_51 _1 _2 in
      _menhir_goto_object_contents _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
  
  and _menhir_goto_object_contents : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      match _menhir_s with
      | MenhirState071 ->
          _menhir_run_072 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | MenhirState055 ->
          _menhir_run_074 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_077 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState077
      | NEWLINE ->
          let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState077
      | COMMA ->
          let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
          let _menhir_stack = MenhirCell1_COMMA (_menhir_stack, MenhirState077) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_0 = _menhir_action_73 () in
          _menhir_run_079 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState078 _tok
      | RBRACKET ->
          let _v = _menhir_action_04 () in
          _menhir_goto_array_tail _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _eRR ()
  
  and _menhir_run_079 : type  ttv_stack. (((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | STRING _v_0 ->
          _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState079
      | SIZE _v_1 ->
          _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState079
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | RGBA ->
          _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | RGB ->
          _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | NULL ->
          _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | LBRACKET ->
          _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | LBRACE ->
          _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | INTEGER _v_2 ->
          _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v_2 MenhirState079
      | FLOAT _v_3 ->
          _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v_3 MenhirState079
      | DURATION _v_4 ->
          _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v_4 MenhirState079
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState079
      | COLOR _v_5 ->
          _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v_5 MenhirState079
      | BOOLEAN _v_6 ->
          _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v_6 MenhirState079
      | RBRACKET ->
          let _v_7 = _menhir_action_02 () in
          _menhir_run_080 _menhir_stack _menhir_lexbuf _menhir_lexer _v_7
      | _ ->
          _eRR ()
  
  and _menhir_run_080 : type  ttv_stack. (((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_COMMA, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_COMMA (_menhir_stack, _) = _menhir_stack in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let _4 = _v in
      let _v = _menhir_action_05 _4 in
      _menhir_goto_array_tail _menhir_stack _menhir_lexbuf _menhir_lexer _v
  
  and _menhir_goto_array_tail : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_value -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_value (_menhir_stack, _menhir_s, _1, _) = _menhir_stack in
      let _2 = _v in
      let _v = _menhir_action_03 _1 _2 in
      _menhir_goto_array_contents _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
  
  and _menhir_goto_array_contents : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      match _menhir_s with
      | MenhirState079 ->
          _menhir_run_080 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | MenhirState051 ->
          _menhir_run_082 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_097 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState097
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState097
      | LBRACE ->
          let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
          let _menhir_stack = MenhirCell1_LBRACE (_menhir_stack, MenhirState097, _startpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_0 = _menhir_action_73 () in
          _menhir_run_099 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState098 _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_099 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_002 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | LBRACKET ->
          _menhir_run_100 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | INCLUDE ->
          _menhir_run_107 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState099
      | DEFINE ->
          _menhir_run_109 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState099
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState099
      | RBRACE ->
          let _v = _menhir_action_82 () in
          _menhir_goto_statements_before_rbrace _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _eRR ()
  
  and _menhir_run_100 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos) in
      let _menhir_s = MenhirState100 in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_006 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | INCLUDE ->
          _menhir_run_010 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | IDENTIFIER _v ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | DEFINE ->
          _menhir_run_012 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | BOOLEAN _v ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_107 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | STRING _v ->
          let _endpos_1 = _menhir_lexbuf.Lexing.lex_curr_p in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let (_startpos__1_, _endpos__2_, _2) = (_startpos, _endpos_1, _v) in
          let _v = _menhir_action_40 _2 in
          _menhir_goto_include_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__2_ _startpos__1_ _v _menhir_s _tok
      | ADD_ASSIGN | ASSIGN | DEFINE_ASSIGN | DOT | SUB_ASSIGN ->
          let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
          let _v = _menhir_action_62 () in
          _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_goto_include_statement : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState099 ->
          _menhir_run_130 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_130 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState001 ->
          _menhir_run_150 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState146 ->
          _menhir_run_150 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState148 ->
          _menhir_run_150 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState160 ->
          _menhir_run_150 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_130 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_78 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_statement _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_goto_statement : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState099 ->
          _menhir_run_116 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_118 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_116 : type  ttv_stack. ((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_statement (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState116
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState116
      | RBRACE ->
          let _v_0 = _menhir_action_11 () in
          _menhir_run_134 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0
      | _ ->
          _eRR ()
  
  and _menhir_run_134 : type  ttv_stack. ((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_statement -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_statement (_menhir_stack, _, _1) = _menhir_stack in
      let _2 = _v in
      let _v = _menhir_action_83 _1 _2 in
      _menhir_goto_statements_before_rbrace _menhir_stack _menhir_lexbuf _menhir_lexer _v
  
  and _menhir_goto_statements_before_rbrace : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_separators (_menhir_stack, _menhir_s, _) = _menhir_stack in
      let _2 = _v in
      let _v = _menhir_action_14 _2 in
      _menhir_goto_block_statements _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
  
  and _menhir_goto_block_statements : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      match _menhir_s with
      | MenhirState104 ->
          _menhir_run_105 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | MenhirState098 ->
          _menhir_run_135 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | MenhirState139 ->
          _menhir_run_140 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_105 : type  ttv_stack. ((((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let MenhirCell1_LBRACE (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell0_RBRACKET (_menhir_stack, _) = _menhir_stack in
      let MenhirCell1_path (_menhir_stack, _, _2, _, _) = _menhir_stack in
      let MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
      let (_endpos__7_, _6) = (_endpos, _v) in
      let _v = _menhir_action_70 _2 _6 in
      _menhir_goto_section _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__7_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_section : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_80 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_statement _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_run_135 : type  ttv_stack. (((((ttv_stack, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _menhir_stack = MenhirCell1_block_statements (_menhir_stack, _menhir_s, _v) in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _menhir_stack = MenhirCell0_RBRACE (_menhir_stack, _endpos) in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | ELSE ->
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_1 = _menhir_action_73 () in
          _menhir_run_138 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState137 _tok
      | BOOLEAN _ | DEFINE | EOF | IDENTIFIER _ | INCLUDE | LBRACKET | NEWLINE | NULL | RBRACE | RGB | RGBA | SEMICOLON | WHEN ->
          let _v = _menhir_action_56 () in
          _menhir_goto_optional_else _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_138 : type  ttv_stack. ((((((ttv_stack, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_block_statements _menhir_cell0_RBRACE as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState138
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState138
      | LBRACE ->
          let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
          let _menhir_stack = MenhirCell1_LBRACE (_menhir_stack, MenhirState138, _startpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_0 = _menhir_action_73 () in
          _menhir_run_099 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState139 _tok
      | _ ->
          _eRR ()
  
  and _menhir_goto_optional_else : type  ttv_stack. (((((ttv_stack, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_block_statements _menhir_cell0_RBRACE -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell0_RBRACE (_menhir_stack, _) = _menhir_stack in
      let MenhirCell1_block_statements (_menhir_stack, _, _5) = _menhir_stack in
      let MenhirCell1_LBRACE (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_condition (_menhir_stack, _, _2) = _menhir_stack in
      let MenhirCell1_WHEN (_menhir_stack, _menhir_s, _startpos__1_, _) = _menhir_stack in
      let (_endpos__7_, _7) = (_endpos, _v) in
      let _v = _menhir_action_32 _2 _5 _7 in
      _menhir_goto_conditional _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__7_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_conditional : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState099 ->
          _menhir_run_132 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_132 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState001 ->
          _menhir_run_152 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState146 ->
          _menhir_run_152 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState148 ->
          _menhir_run_152 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState160 ->
          _menhir_run_152 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_132 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_81 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_statement _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_run_152 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_47 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_non_section_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
  
  and _menhir_goto_non_section_statement : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState146 ->
          _menhir_run_147 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
      | MenhirState148 ->
          _menhir_run_147 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
      | MenhirState001 ->
          _menhir_run_155 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | MenhirState160 ->
          _menhir_run_155 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_147 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_non_section_statement (_menhir_stack, _menhir_s, _v) in
      let _v_0 = _menhir_action_73 () in
      _menhir_run_148 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v_0 MenhirState147 _tok
  
  and _menhir_run_148 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_non_section_statement as 'stack) -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_002 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | INCLUDE ->
          _menhir_run_107 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState148
      | DEFINE ->
          _menhir_run_109 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState148
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState148
      | EOF | LBRACKET ->
          let _v_2 = _menhir_action_42 () in
          _menhir_run_149 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v_2 _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_109 : type  ttv_stack. ttv_stack -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | IDENTIFIER _v ->
          let _menhir_stack = MenhirCell1_DEFINE (_menhir_stack, _menhir_s, _startpos, _endpos) in
          let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
          let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
          let _menhir_stack = MenhirCell0_IDENTIFIER (_menhir_stack, _v, _startpos, _endpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | DEFINE_ASSIGN ->
              let _menhir_s = MenhirState111 in
              let _tok = _menhir_lexer _menhir_lexbuf in
              (match (_tok : MenhirBasics.token) with
              | STRING _v ->
                  _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | SIZE _v ->
                  _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | RGBA ->
                  _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | RGB ->
                  _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | NULL ->
                  _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | LBRACKET ->
                  _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | LBRACE ->
                  _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | INTEGER _v ->
                  _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | FLOAT _v ->
                  _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | DURATION _v ->
                  _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | DOLLAR ->
                  _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | COLOR _v ->
                  _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | BOOLEAN _v ->
                  _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | _ ->
                  _eRR ())
          | ASSIGN ->
              let _menhir_s = MenhirState113 in
              let _tok = _menhir_lexer _menhir_lexbuf in
              (match (_tok : MenhirBasics.token) with
              | STRING _v ->
                  _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | SIZE _v ->
                  _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | RGBA ->
                  _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | RGB ->
                  _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | NULL ->
                  _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | LBRACKET ->
                  _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | LBRACE ->
                  _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | INTEGER _v ->
                  _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | FLOAT _v ->
                  _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | DURATION _v ->
                  _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | DOLLAR ->
                  _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
              | COLOR _v ->
                  _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | BOOLEAN _v ->
                  _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
              | _ ->
                  _eRR ())
          | _ ->
              _eRR ())
      | ADD_ASSIGN | ASSIGN | DEFINE_ASSIGN | DOT | SUB_ASSIGN ->
          let (_endpos__1_, _startpos__1_) = (_endpos, _startpos) in
          let _v = _menhir_action_66 () in
          _menhir_goto_path_component _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_149 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_non_section_statement, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_non_section_statement (_menhir_stack, _menhir_s, _1) = _menhir_stack in
      let (_endpos__3_, _3) = (_endpos, _v) in
      let _v = _menhir_action_43 _1 _3 in
      _menhir_goto_ini_section_body _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _v _menhir_s _tok
  
  and _menhir_goto_ini_section_body : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState148 ->
          _menhir_run_149 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState146 ->
          _menhir_run_154 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_154 : type  ttv_stack. ((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET, _menhir_box_document) _menhir_cell1_separators -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell0_RBRACKET (_menhir_stack, _) = _menhir_stack in
      let MenhirCell1_path (_menhir_stack, _, _2, _, _) = _menhir_stack in
      let MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
      let (_endpos__5_, _5) = (_endpos, _v) in
      let _v = _menhir_action_41 _2 _5 _endpos__5_ _startpos__1_ in
      let _1 = _v in
      let _v = _menhir_action_36 _1 in
      _menhir_goto_document_item _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_goto_document_item : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_document_item (_menhir_stack, _menhir_s, _v) in
      let _v_0 = _menhir_action_73 () in
      _menhir_run_160 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState159 _tok
  
  and _menhir_run_160 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_document_item as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_002 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | LBRACKET ->
          _menhir_run_143 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | INCLUDE ->
          _menhir_run_107 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState160
      | DEFINE ->
          _menhir_run_109 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState160
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState160
      | EOF ->
          let _v_2 = _menhir_action_38 () in
          _menhir_run_161 _menhir_stack _v_2
      | _ ->
          _eRR ()
  
  and _menhir_run_143 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _menhir_stack = MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos) in
      let _menhir_s = MenhirState143 in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_006 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | INCLUDE ->
          _menhir_run_010 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | IDENTIFIER _v ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | DEFINE ->
          _menhir_run_012 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | BOOLEAN _v ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_155 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _1 = _v in
      let _v = _menhir_action_37 _1 in
      _menhir_goto_document_item _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_run_140 : type  ttv_stack. (((((((ttv_stack, _menhir_box_document) _menhir_cell1_WHEN, _menhir_box_document) _menhir_cell1_condition, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE, _menhir_box_document) _menhir_cell1_block_statements _menhir_cell0_RBRACE, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACE -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let MenhirCell1_LBRACE (_menhir_stack, _, _) = _menhir_stack in
      let MenhirCell1_separators (_menhir_stack, _, _) = _menhir_stack in
      let (_4, _endpos__5_) = (_v, _endpos) in
      let _v = _menhir_action_57 _4 in
      _menhir_goto_optional_else _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__5_ _v _tok
  
  and _menhir_run_118 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_cell1_separators1 as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_statement (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState118
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState118
      | RBRACE ->
          let _v_0 = _menhir_action_11 () in
          _menhir_run_120 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0
      | _ ->
          _eRR ()
  
  and _menhir_run_120 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_cell1_separators1, _menhir_box_document) _menhir_cell1_statement -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v ->
      let MenhirCell1_statement (_menhir_stack, _, _2) = _menhir_stack in
      let MenhirCell1_separators1 (_menhir_stack, _menhir_s, _) = _menhir_stack in
      let _3 = _v in
      let _v = _menhir_action_13 _2 _3 in
      _menhir_goto_block_statement_tail _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
  
  and _menhir_goto_block_statement_tail : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_statement as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      match _menhir_s with
      | MenhirState118 ->
          _menhir_run_120 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | MenhirState116 ->
          _menhir_run_134 _menhir_stack _menhir_lexbuf _menhir_lexer _v
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_150 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_45 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_non_section_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
  
  and _menhir_run_103 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState103
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState103
      | LBRACE ->
          let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
          let _menhir_stack = MenhirCell1_LBRACE (_menhir_stack, MenhirState103, _startpos) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_0 = _menhir_action_73 () in
          _menhir_run_099 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState104 _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_146 : type  ttv_stack. ((((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACKET, _menhir_box_document) _menhir_cell1_path _menhir_cell0_RBRACKET as 'stack) -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_separators (_menhir_stack, _menhir_s, _v) in
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          _menhir_run_002 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | SEMICOLON ->
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | RGBA ->
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | RGB ->
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | NULL ->
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | NEWLINE ->
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | INCLUDE ->
          _menhir_run_107 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | IDENTIFIER _v_0 ->
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState146
      | DEFINE ->
          _menhir_run_109 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState146
      | BOOLEAN _v_1 ->
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState146
      | EOF | LBRACKET ->
          let _v_2 = _menhir_action_42 () in
          _menhir_run_154 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v_2 _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_119 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_statement as 'stack) -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s _tok ->
      let _v = _menhir_action_75 () in
      _menhir_goto_separators1 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_goto_separators1 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_statement as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | WHEN ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_002 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | SEMICOLON ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_052 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | RGBA ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_007 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | RGB ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_008 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | NULL ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_009 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | NEWLINE ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_053 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | LBRACKET ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_100 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | INCLUDE ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_107 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | IDENTIFIER _v_0 ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_011 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState117
      | DEFINE ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_109 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState117
      | BOOLEAN _v_1 ->
          let _menhir_stack = MenhirCell1_separators1 (_menhir_stack, _menhir_s, _v) in
          _menhir_run_013 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState117
      | RBRACE ->
          let _v = _menhir_action_12 () in
          _menhir_goto_block_statement_tail _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_121 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_statement, _menhir_box_document) _menhir_cell1_separators1 -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _tok ->
      let MenhirCell1_separators1 (_menhir_stack, _menhir_s, _) = _menhir_stack in
      let _v = _menhir_action_76 () in
      _menhir_goto_separators1 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_run_076 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_value (_menhir_stack, _menhir_s, _v, _endpos) in
      let _v_0 = _menhir_action_73 () in
      _menhir_run_077 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState076 _tok
  
  and _menhir_run_084 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_reference _menhir_cell0_comparison_operator -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell0_comparison_operator (_menhir_stack, _2) = _menhir_stack in
      let MenhirCell1_reference (_menhir_stack, _menhir_s, _1, _startpos__1_, _) = _menhir_stack in
      let (_endpos__3_, _3) = (_endpos, _v) in
      let _v = _menhir_action_30 _1 _2 _3 _endpos__3_ _startpos__1_ in
      _menhir_goto_condition_primary _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_condition_primary : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_24 _1 in
      _menhir_goto_condition_not _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_condition_not : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState002 ->
          _menhir_run_088 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState004 ->
          _menhir_run_088 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState087 ->
          _menhir_run_088 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState090 ->
          _menhir_run_091 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | MenhirState003 ->
          _menhir_run_095 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_088 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_22 _1 in
      _menhir_goto_condition_and _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_condition_and : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState087 ->
          _menhir_run_089 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState002 ->
          _menhir_run_092 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState004 ->
          _menhir_run_092 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_089 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_condition_or as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | AND ->
          let _menhir_stack = MenhirCell1_condition_and (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          _menhir_run_090 _menhir_stack _menhir_lexbuf _menhir_lexer
      | LBRACE | NEWLINE | OR | RPAREN | SEMICOLON ->
          let MenhirCell1_condition_or (_menhir_stack, _menhir_s, _1, _startpos__1_) = _menhir_stack in
          let (_endpos__3_, _3) = (_endpos, _v) in
          let _v = _menhir_action_27 _1 _3 _endpos__3_ _startpos__1_ in
          _menhir_goto_condition_or _menhir_stack _menhir_lexbuf _menhir_lexer _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_090 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_condition_and -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer ->
      let _menhir_s = MenhirState090 in
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | NOT ->
          _menhir_run_003 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | LPAREN ->
          _menhir_run_004 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
      | BOOLEAN _v ->
          _menhir_run_018 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
      | _ ->
          _eRR ()
  
  and _menhir_run_018 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s ->
      let _startpos = _menhir_lexbuf.Lexing.lex_start_p in
      let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
      let _tok = _menhir_lexer _menhir_lexbuf in
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_28 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_condition_primary _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_condition_or : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _startpos _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | OR ->
          let _menhir_stack = MenhirCell1_condition_or (_menhir_stack, _menhir_s, _v, _startpos) in
          let _menhir_s = MenhirState087 in
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | NOT ->
              _menhir_run_003 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | LPAREN ->
              _menhir_run_004 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | DOLLAR ->
              _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | BOOLEAN _v ->
              _menhir_run_018 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | _ ->
              _eRR ())
      | LBRACE | NEWLINE | RPAREN | SEMICOLON ->
          let _1 = _v in
          let _v = _menhir_action_21 _1 in
          _menhir_goto_condition _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_goto_condition : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState004 ->
          _menhir_run_093 _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | MenhirState002 ->
          _menhir_run_096 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_093 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_LPAREN -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok ->
      match (_tok : MenhirBasics.token) with
      | RPAREN ->
          let _endpos = _menhir_lexbuf.Lexing.lex_curr_p in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let MenhirCell1_LPAREN (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
          let (_2, _endpos__3_) = (_v, _endpos) in
          let _v = _menhir_action_31 _2 in
          _menhir_goto_condition_primary _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_096 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_WHEN as 'stack) -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_condition (_menhir_stack, _menhir_s, _v) in
      let _v_0 = _menhir_action_73 () in
      _menhir_run_097 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState096 _tok
  
  and _menhir_run_092 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | AND ->
          let _menhir_stack = MenhirCell1_condition_and (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
          _menhir_run_090 _menhir_stack _menhir_lexbuf _menhir_lexer
      | LBRACE | NEWLINE | OR | RPAREN | SEMICOLON ->
          let (_startpos__1_, _1) = (_startpos, _v) in
          let _v = _menhir_action_26 _1 in
          _menhir_goto_condition_or _menhir_stack _menhir_lexbuf _menhir_lexer _startpos__1_ _v _menhir_s _tok
      | _ ->
          _eRR ()
  
  and _menhir_run_091 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_condition_and -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_condition_and (_menhir_stack, _menhir_s, _1, _startpos__1_, _) = _menhir_stack in
      let (_endpos__3_, _3) = (_endpos, _v) in
      let _v = _menhir_action_23 _1 _3 _endpos__3_ _startpos__1_ in
      _menhir_goto_condition_and _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_095 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_NOT -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell1_NOT (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
      let (_endpos__2_, _2) = (_endpos, _v) in
      let _v = _menhir_action_25 _2 _endpos__2_ _startpos__1_ in
      _menhir_goto_condition_not _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__2_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_112 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_DEFINE _menhir_cell0_IDENTIFIER -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell0_IDENTIFIER (_menhir_stack, _2, _, _) = _menhir_stack in
      let MenhirCell1_DEFINE (_menhir_stack, _menhir_s, _startpos__1_, _) = _menhir_stack in
      let (_endpos__4_, _4) = (_endpos, _v) in
      let _v = _menhir_action_34 _2 _4 in
      _menhir_goto_define_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__4_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_define_statement : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState099 ->
          _menhir_run_131 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_131 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState001 ->
          _menhir_run_151 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState146 ->
          _menhir_run_151 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState148 ->
          _menhir_run_151 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState160 ->
          _menhir_run_151 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_131 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_79 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_statement _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_run_151 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_46 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_non_section_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
  
  and _menhir_run_114 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_DEFINE _menhir_cell0_IDENTIFIER -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell0_IDENTIFIER (_menhir_stack, _2, _, _) = _menhir_stack in
      let MenhirCell1_DEFINE (_menhir_stack, _menhir_s, _startpos__1_, _) = _menhir_stack in
      let (_endpos__4_, _4) = (_endpos, _v) in
      let _v = _menhir_action_33 _2 _4 in
      _menhir_goto_define_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__4_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_run_129 : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_path _menhir_cell0_assignment_operator -> _ -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _tok ->
      let MenhirCell0_assignment_operator (_menhir_stack, _2) = _menhir_stack in
      let MenhirCell1_path (_menhir_stack, _menhir_s, _1, _startpos__1_, _) = _menhir_stack in
      let (_endpos__3_, _3) = (_endpos, _v) in
      let _v = _menhir_action_06 _1 _2 _3 in
      _menhir_goto_assignment _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _startpos__1_ _v _menhir_s _tok
  
  and _menhir_goto_assignment : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match _menhir_s with
      | MenhirState099 ->
          _menhir_run_133 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState117 ->
          _menhir_run_133 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState001 ->
          _menhir_run_153 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState146 ->
          _menhir_run_153 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState148 ->
          _menhir_run_153 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | MenhirState160 ->
          _menhir_run_153 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok
      | _ ->
          _menhir_fail ()
  
  and _menhir_run_133 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_77 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_statement _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s _tok
  
  and _menhir_run_153 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_44 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_non_section_statement _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _v _menhir_s _tok
  
  and _menhir_run_065 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let (_endpos__1_, _startpos__1_, _1) = (_endpos, _startpos, _v) in
      let _v = _menhir_action_89 _1 _endpos__1_ _startpos__1_ in
      _menhir_goto_value _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__1_ _v _menhir_s _tok
  
  and _menhir_run_057 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_separators as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_path (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
      match (_tok : MenhirBasics.token) with
      | COLON ->
          let _menhir_s = MenhirState058 in
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | STRING _v ->
              _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | SIZE _v ->
              _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | RGBA ->
              _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | RGB ->
              _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | NULL ->
              _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | LBRACKET ->
              _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | LBRACE ->
              _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | INTEGER _v ->
              _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | FLOAT _v ->
              _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | DURATION _v ->
              _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | DOLLAR ->
              _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer _menhir_s
          | COLOR _v ->
              _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | BOOLEAN _v ->
              _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v _menhir_s
          | _ ->
              _eRR ())
      | _ ->
          _eRR ()
  
  and _menhir_run_101 : type  ttv_stack. ((ttv_stack, _menhir_box_document) _menhir_cell1_LBRACKET as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      match (_tok : MenhirBasics.token) with
      | RBRACKET ->
          let _endpos_0 = _menhir_lexbuf.Lexing.lex_curr_p in
          let _tok = _menhir_lexer _menhir_lexbuf in
          (match (_tok : MenhirBasics.token) with
          | RBRACE ->
              let MenhirCell1_LBRACKET (_menhir_stack, _menhir_s, _startpos__1_) = _menhir_stack in
              let (_2, _endpos__3_) = (_v, _endpos_0) in
              let _v = _menhir_action_69 _2 in
              _menhir_goto_section _menhir_stack _menhir_lexbuf _menhir_lexer _endpos__3_ _startpos__1_ _v _menhir_s _tok
          | LBRACE | NEWLINE | SEMICOLON ->
              let _menhir_stack = MenhirCell1_path (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
              let _menhir_stack = MenhirCell0_RBRACKET (_menhir_stack, _endpos_0) in
              let _v_1 = _menhir_action_73 () in
              _menhir_run_103 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState102 _tok
          | _ ->
              _eRR ())
      | _ ->
          _eRR ()
  
  and _menhir_run_123 : type  ttv_stack. ttv_stack -> _ -> _ -> _ -> _ -> _ -> (ttv_stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_path (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
      match (_tok : MenhirBasics.token) with
      | SUB_ASSIGN ->
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_10 () in
          _menhir_goto_assignment_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | DEFINE_ASSIGN ->
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_08 () in
          _menhir_goto_assignment_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | ASSIGN ->
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_07 () in
          _menhir_goto_assignment_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | ADD_ASSIGN ->
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v = _menhir_action_09 () in
          _menhir_goto_assignment_operator _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok
      | _ ->
          _eRR ()
  
  and _menhir_goto_assignment_operator : type  ttv_stack. (ttv_stack, _menhir_box_document) _menhir_cell1_path -> _ -> _ -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _v _tok ->
      let _menhir_stack = MenhirCell0_assignment_operator (_menhir_stack, _v) in
      match (_tok : MenhirBasics.token) with
      | STRING _v_0 ->
          _menhir_run_027 _menhir_stack _menhir_lexbuf _menhir_lexer _v_0 MenhirState128
      | SIZE _v_1 ->
          _menhir_run_028 _menhir_stack _menhir_lexbuf _menhir_lexer _v_1 MenhirState128
      | RGBA ->
          _menhir_run_029 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState128
      | RGB ->
          _menhir_run_041 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState128
      | NULL ->
          _menhir_run_049 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState128
      | LBRACKET ->
          _menhir_run_050 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState128
      | LBRACE ->
          _menhir_run_054 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState128
      | INTEGER _v_2 ->
          _menhir_run_059 _menhir_stack _menhir_lexbuf _menhir_lexer _v_2 MenhirState128
      | FLOAT _v_3 ->
          _menhir_run_060 _menhir_stack _menhir_lexbuf _menhir_lexer _v_3 MenhirState128
      | DURATION _v_4 ->
          _menhir_run_061 _menhir_stack _menhir_lexbuf _menhir_lexer _v_4 MenhirState128
      | DOLLAR ->
          _menhir_run_005 _menhir_stack _menhir_lexbuf _menhir_lexer MenhirState128
      | COLOR _v_5 ->
          _menhir_run_062 _menhir_stack _menhir_lexbuf _menhir_lexer _v_5 MenhirState128
      | BOOLEAN _v_6 ->
          _menhir_run_063 _menhir_stack _menhir_lexbuf _menhir_lexer _v_6 MenhirState128
      | _ ->
          _eRR ()
  
  and _menhir_run_144 : type  ttv_stack. (((ttv_stack, _menhir_box_document) _menhir_cell1_separators, _menhir_box_document) _menhir_cell1_LBRACKET as 'stack) -> _ -> _ -> _ -> _ -> _ -> ('stack, _menhir_box_document) _menhir_state -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer _endpos _startpos _v _menhir_s _tok ->
      let _menhir_stack = MenhirCell1_path (_menhir_stack, _menhir_s, _v, _startpos, _endpos) in
      match (_tok : MenhirBasics.token) with
      | RBRACKET ->
          let _endpos_0 = _menhir_lexbuf.Lexing.lex_curr_p in
          let _menhir_stack = MenhirCell0_RBRACKET (_menhir_stack, _endpos_0) in
          let _tok = _menhir_lexer _menhir_lexbuf in
          let _v_1 = _menhir_action_73 () in
          _menhir_run_146 _menhir_stack _menhir_lexbuf _menhir_lexer _endpos_0 _v_1 MenhirState145 _tok
      | _ ->
          _eRR ()
  
  let _menhir_run_000 : type  ttv_stack. ttv_stack -> _ -> _ -> _menhir_box_document =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer ->
      let _tok = _menhir_lexer _menhir_lexbuf in
      let _v = _menhir_action_73 () in
      _menhir_run_001 _menhir_stack _menhir_lexbuf _menhir_lexer _v MenhirState000 _tok
  
end

let document =
  fun _menhir_lexer _menhir_lexbuf ->
    let _menhir_stack = () in
    let MenhirBox_document v = _menhir_run_000 _menhir_stack _menhir_lexbuf _menhir_lexer in
    v
