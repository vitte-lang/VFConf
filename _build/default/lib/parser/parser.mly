%{
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


let group_document_sections statements =
  let flush_section output current =
    match current with
    | None ->
        output
    | Some (node, section, body_rev) ->
        let grouped =
          {
            node with
            Node.value =
              Statement.Section
                {
                  section with
                  Statement.body = List.rev body_rev;
                };
          }
        in
        grouped :: output
  in

  let rec loop output current = function
    | [] ->
        List.rev (flush_section output current)

    | node :: rest ->
        begin
          match node.Node.value with
          | Statement.Section section ->
              let output =
                flush_section output current
              in
              loop
                output
                (Some (node, section, []))
                rest

          | _ ->
              begin
                match current with
                | None ->
                    loop
                      (node :: output)
                      None
                      rest

                | Some (section_node, section, body_rev) ->
                    loop
                      output
                      (Some
                         ( section_node,
                           section,
                           node :: body_rev ))
                      rest
              end
        end
  in

  loop [] None statements

%}

%token INCLUDE
%token DEFINE
%token WHEN
%token ELSE

%token <string> IDENTIFIER
%token <string> STRING
%token <int64> INTEGER
%token <float> FLOAT
%token <bool> BOOLEAN
%token NULL
%token <string> COLOR
%token <float * Value.duration_unit> DURATION
%token <float * Value.size_unit> SIZE

%token RGB
%token RGBA

%token ASSIGN
%token DEFINE_ASSIGN
%token ADD_ASSIGN
%token SUB_ASSIGN

%token EQEQ
%token NEQ
%token LT
%token LTE
%token GT
%token GTE

%token AND
%token OR
%token NOT

%token LBRACKET
%token RBRACKET
%token LBRACE
%token RBRACE
%token LPAREN
%token RPAREN

%token COMMA
%token COLON
%token SEMICOLON
%token DOT
%token DOLLAR
%token NEWLINE

%token EOF

%start <Statement.t Node.t list> document


%%

separators:
  /* empty */
    {
      ()
    }
| separators separator
    {
      ()
    }
;

separators1:
  separator
    {
      ()
    }
| separators1 separator
    {
      ()
    }
;

separator:
  NEWLINE
    {
      ()
    }
| SEMICOLON
    {
      ()
    }
;

statement:
  non_section_statement
    {
      $1
    }
;

document:
  separators flat_document_items EOF
    {
      group_document_sections $2
    }
;

flat_document_items:
  /* empty */
    {
      []
    }

| flat_document_item separators flat_document_items
    {
      $1 :: $3
    }
;

flat_document_item:
  LBRACKET path RBRACKET
    {
      located $startpos $endpos
        (Statement.Section
          {
            Statement.name = $2;
            body = [];
          })
    }

| non_section_statement
    {
      $1
    }
;

non_section_statement:
  assignment
    {
      located $startpos $endpos
        (Statement.Assignment $1)
    }

| include_statement
    {
      located $startpos $endpos
        (Statement.Include $1)
    }

| define_statement
    {
      located $startpos $endpos
        (Statement.Define $1)
    }

| conditional
    {
      located $startpos $endpos
        (Statement.Conditional $1)
    }
;

assignment:
  path assignment_operator value
    {
      {
        Statement.key = $1;
        operator = $2;
        value = $3;
      }
    }
;

assignment_operator:
  ASSIGN
    {
      Statement.Assign
    }

| DEFINE_ASSIGN
    {
      Statement.Define_assign
    }

| ADD_ASSIGN
    {
      Statement.Add_assign
    }

| SUB_ASSIGN
    {
      Statement.Sub_assign
    }
;

include_statement:
  INCLUDE STRING
    {
      {
        Statement.path = $2;
      }
    }
;

define_statement:
  DEFINE IDENTIFIER ASSIGN value
    {
      {
        Statement.name = $2;
        value = $4;
      }
    }

| DEFINE IDENTIFIER DEFINE_ASSIGN value
    {
      {
        Statement.name = $2;
        value = $4;
      }
    }
;


conditional:
  WHEN condition
  separators
  LBRACE
  block_statements
  RBRACE
  optional_else
    {
      {
        Statement.condition = $2;
        then_branch = $5;
        else_branch = $7;
      }
    }
;

optional_else:
  /* empty */
    {
      None
    }

| ELSE
  separators
  LBRACE
  block_statements
  RBRACE
    {
      Some $4
    }
;


block_statements:
  separators statements_before_rbrace
    {
      $2
    }
;

statements_before_rbrace:
  /* empty */
    {
      []
    }

| statement block_statement_tail
    {
      $1 :: $2
    }
;

block_statement_tail:
  /* empty */
    {
      []
    }

| separators1
    {
      []
    }

| separators1 statement block_statement_tail
    {
      $2 :: $3
    }
;

path_component:
  IDENTIFIER
    { $1 }
| NULL
    { "null" }
| INCLUDE
    { "include" }
| WHEN
    { "when" }
| RGB
    { "rgb" }
| RGBA
    { "rgba" }
| DEFINE
    { "define" }
| BOOLEAN
    {
      if $1 then
        "true"
      else
        "false"
    }
;

path:
  path_component
    { [$1] }
| path_component DOT path
    { $1 :: $3 }
;

reference:
  DOLLAR path
    {
      $2
    }
;

value:
  STRING
    {
      located $startpos $endpos
        (Value.String $1)
    }

| INTEGER
    {
      located $startpos $endpos
        (Value.Integer $1)
    }

| FLOAT
    {
      located $startpos $endpos
        (Value.Float $1)
    }

| BOOLEAN
    {
      located $startpos $endpos
        (Value.Boolean $1)
    }

| NULL
    {
      located $startpos $endpos
        Value.Null
    }

| reference
    {
      located $startpos $endpos
        (Value.Reference $1)
    }

| COLOR
    {
      located $startpos $endpos
        (Value.Color (color_of_hex $1))
    }

| DURATION
    {
      let amount, unit = $1 in
      located $startpos $endpos
        (Value.Duration (amount, unit))
    }

| SIZE
    {
      let amount, unit = $1 in
      located $startpos $endpos
        (Value.Size (amount, unit))
    }

| array
    {
      located $startpos $endpos
        (Value.Array $1)
    }

| object_value
    {
      located $startpos $endpos
        (Value.Object $1)
    }

| RGB LPAREN INTEGER COMMA INTEGER COMMA INTEGER RPAREN
    {
      let red = int_of_int64_checked $3 in
      let green = int_of_int64_checked $5 in
      let blue = int_of_int64_checked $7 in

      if
        red < 0 || red > 255
        || green < 0 || green > 255
        || blue < 0 || blue > 255
      then
        invalid_arg "RGB component outside 0..255";

      located $startpos $endpos
        (Value.Color
           (Value.Rgb
              {
                red;
                green;
                blue;
              }))
    }

| RGBA LPAREN INTEGER COMMA INTEGER COMMA INTEGER COMMA numeric_value RPAREN
    {
      let red = int_of_int64_checked $3 in
      let green = int_of_int64_checked $5 in
      let blue = int_of_int64_checked $7 in
      let alpha = alpha_of_value $9 in

      if
        red < 0 || red > 255
        || green < 0 || green > 255
        || blue < 0 || blue > 255
      then
        invalid_arg "RGBA component outside 0..255";

      if alpha < 0.0 || alpha > 1.0 then
        invalid_arg "RGBA alpha outside 0.0..1.0";

      located $startpos $endpos
        (Value.Color
           (Value.Rgba
              {
                red;
                green;
                blue;
                alpha;
              }))
    }
;

numeric_value:
  INTEGER
    {
      located $startpos $endpos
        (Value.Integer $1)
    }

| FLOAT
    {
      located $startpos $endpos
        (Value.Float $1)
    }
;

array:
  LBRACKET separators array_contents RBRACKET
    {
      $3
    }
;

array_contents:
  /* empty */
    {
      []
    }

| value array_tail
    {
      $1 :: $2
    }
;

array_tail:
  separators
    {
      []
    }

| separators COMMA separators array_contents
    {
      $4
    }
;


object_value:
  LBRACE separators object_contents RBRACE
    {
      $3
    }
;

object_contents:
  /* empty */
    {
      []
    }

| object_entry object_tail
    {
      $1 :: $2
    }
;

object_tail:
  separators
    {
      []
    }

| separators COMMA separators object_contents
    {
      $4
    }
;

object_entry:
  path COLON value
    {
      object_entry
        $1
        $3
        $startpos
        $endpos
    }
;

condition:
  condition_or
    {
      $1
    }
;

condition_or:
  condition_and
    {
      $1
    }

| condition_or OR condition_and
    {
      located $startpos $endpos
        (Statement.Logical
           {
             left = $1;
             operator = Statement.Or;
             right = $3;
           })
    }
;

condition_and:
  condition_not
    {
      $1
    }

| condition_and AND condition_not
    {
      located $startpos $endpos
        (Statement.Logical
           {
             left = $1;
             operator = Statement.And;
             right = $3;
           })
    }
;

condition_not:
  condition_primary
    {
      $1
    }

| NOT condition_not
    {
      located $startpos $endpos
        (Statement.Not $2)
    }
;

condition_primary:
  BOOLEAN
    {
      located $startpos $endpos
        (Statement.Boolean $1)
    }

| reference
    {
      located $startpos $endpos
        (Statement.Reference $1)
    }

| reference comparison_operator value
    {
      located $startpos $endpos
        (Statement.Compare
           {
             reference = $1;
             operator = $2;
             value = $3;
           })
    }

| LPAREN condition RPAREN
    {
      $2
    }
;

comparison_operator:
  EQEQ
    {
      Statement.Equal
    }

| NEQ
    {
      Statement.Not_equal
    }

| LT
    {
      Statement.Less
    }

| LTE
    {
      Statement.Less_equal
    }

| GT
    {
      Statement.Greater
    }

| GTE
    {
      Statement.Greater_equal
    }
;