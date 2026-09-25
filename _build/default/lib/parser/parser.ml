
(* This generated code requires the following version of MenhirLib: *)

let () =
  MenhirLib.StaticVersion.require_20260209

module MenhirBasics = struct
  
  exception Error
  
  let _eRR =
    fun _s ->
      raise Error
  
  type token = 
    | WHEN
    | SUB_ASSIGN
    | STRING of 
# 198 "lib/parser/parser.mly"
       (string)
# 22 "lib/parser/parser.ml"
  
    | SIZE of 
# 205 "lib/parser/parser.mly"
       (float * Value.size_unit)
# 27 "lib/parser/parser.ml"
  
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
# 199 "lib/parser/parser.mly"
       (int64)
# 48 "lib/parser/parser.ml"
  
    | INCLUDE
    | IDENTIFIER of 
# 197 "lib/parser/parser.mly"
       (string)
# 54 "lib/parser/parser.ml"
  
    | GTE
    | GT
    | FLOAT of 
# 200 "lib/parser/parser.mly"
       (float)
# 61 "lib/parser/parser.ml"
  
    | EQEQ
    | EOF
    | ELSE
    | DURATION of 
# 204 "lib/parser/parser.mly"
       (float * Value.duration_unit)
# 69 "lib/parser/parser.ml"
  
    | DOT
    | DOLLAR
    | DEFINE_ASSIGN
    | DEFINE
    | COMMA
    | COLOR of 
# 203 "lib/parser/parser.mly"
       (string)
# 79 "lib/parser/parser.ml"
  
    | COLON
    | BOOLEAN of 
# 201 "lib/parser/parser.mly"
       (bool)
# 85 "lib/parser/parser.ml"
  
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


# 286 "lib/parser/parser.ml"

module Tables = struct
  
  include MenhirBasics
  
  let semantic_action =
    [|
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _4;
          MenhirLib.EngineTypes.startp = _startpos__4_;
          MenhirLib.EngineTypes.endp = _endpos__4_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _3;
            MenhirLib.EngineTypes.startp = _startpos__3_;
            MenhirLib.EngineTypes.endp = _endpos__3_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _2;
              MenhirLib.EngineTypes.startp = _startpos__2_;
              MenhirLib.EngineTypes.endp = _endpos__2_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _menhir_s;
                MenhirLib.EngineTypes.semv = _1;
                MenhirLib.EngineTypes.startp = _startpos__1_;
                MenhirLib.EngineTypes.endp = _endpos__1_;
                MenhirLib.EngineTypes.next = _menhir_stack;
              };
            };
          };
        } = _menhir_stack in
        let _4 : unit = Obj.magic _4 in
        let _3 : (Value.t Node.t list) = Obj.magic _3 in
        let _2 : (unit) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__4_ in
        let _v : (Value.t Node.t list) = 
# 654 "lib/parser/parser.mly"
    (
      _3
    )
# 333 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (Value.t Node.t list) = 
# 661 "lib/parser/parser.mly"
    (
      []
    )
# 353 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (Value.t Node.t list) = Obj.magic _2 in
        let _1 : (Value.t Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (Value.t Node.t list) = 
# 666 "lib/parser/parser.mly"
    (
      _1 :: _2
    )
# 387 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Value.t Node.t list) = 
# 673 "lib/parser/parser.mly"
    (
      []
    )
# 414 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _4;
          MenhirLib.EngineTypes.startp = _startpos__4_;
          MenhirLib.EngineTypes.endp = _endpos__4_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _3;
            MenhirLib.EngineTypes.startp = _startpos__3_;
            MenhirLib.EngineTypes.endp = _endpos__3_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _2;
              MenhirLib.EngineTypes.startp = _startpos__2_;
              MenhirLib.EngineTypes.endp = _endpos__2_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _menhir_s;
                MenhirLib.EngineTypes.semv = _1;
                MenhirLib.EngineTypes.startp = _startpos__1_;
                MenhirLib.EngineTypes.endp = _endpos__1_;
                MenhirLib.EngineTypes.next = _menhir_stack;
              };
            };
          };
        } = _menhir_stack in
        let _4 : (Value.t Node.t list) = Obj.magic _4 in
        let _3 : (unit) = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__4_ in
        let _v : (Value.t Node.t list) = 
# 678 "lib/parser/parser.mly"
    (
      _4
    )
# 462 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Value.t Node.t) = Obj.magic _3 in
        let _2 : (Statement.assignment_operator) = Obj.magic _2 in
        let _1 : (Value.reference) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v : (Statement.assignment) = 
# 351 "lib/parser/parser.mly"
    (
      {
        Statement.key = _1;
        operator = _2;
        value = _3;
      }
    )
# 507 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.assignment_operator) = 
# 362 "lib/parser/parser.mly"
    (
      Statement.Assign
    )
# 534 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.assignment_operator) = 
# 367 "lib/parser/parser.mly"
    (
      Statement.Define_assign
    )
# 561 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.assignment_operator) = 
# 372 "lib/parser/parser.mly"
    (
      Statement.Add_assign
    )
# 588 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.assignment_operator) = 
# 377 "lib/parser/parser.mly"
    (
      Statement.Sub_assign
    )
# 615 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (Statement.t Node.t list) = 
# 464 "lib/parser/parser.mly"
    (
      []
    )
# 635 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.t Node.t list) = 
# 469 "lib/parser/parser.mly"
    (
      []
    )
# 662 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Statement.t Node.t list) = Obj.magic _3 in
        let _2 : (Statement.t Node.t) = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v : (Statement.t Node.t list) = 
# 474 "lib/parser/parser.mly"
    (
      _2 :: _3
    )
# 703 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (Statement.t Node.t list) = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (Statement.t Node.t list) = 
# 445 "lib/parser/parser.mly"
    (
      _2
    )
# 737 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.comparison_operator) = 
# 814 "lib/parser/parser.mly"
    (
      Statement.Equal
    )
# 764 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.comparison_operator) = 
# 819 "lib/parser/parser.mly"
    (
      Statement.Not_equal
    )
# 791 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.comparison_operator) = 
# 824 "lib/parser/parser.mly"
    (
      Statement.Less
    )
# 818 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.comparison_operator) = 
# 829 "lib/parser/parser.mly"
    (
      Statement.Less_equal
    )
# 845 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.comparison_operator) = 
# 834 "lib/parser/parser.mly"
    (
      Statement.Greater
    )
# 872 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.comparison_operator) = 
# 839 "lib/parser/parser.mly"
    (
      Statement.Greater_equal
    )
# 899 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.condition Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.condition Node.t) = 
# 728 "lib/parser/parser.mly"
    (
      _1
    )
# 926 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.condition Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.condition Node.t) = 
# 753 "lib/parser/parser.mly"
    (
      _1
    )
# 953 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Statement.condition Node.t) = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : (Statement.condition Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v =
          let _endpos = _endpos__3_ in
          let _startpos = _startpos__1_ in
          (
# 758 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Logical
           {
             left = _1;
             operator = Statement.And;
             right = _3;
           })
    )
# 1003 "lib/parser/parser.ml"
           : (Statement.condition Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.condition Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.condition Node.t) = 
# 771 "lib/parser/parser.mly"
    (
      _1
    )
# 1031 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (Statement.condition Node.t) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v =
          let _endpos = _endpos__2_ in
          let _startpos = _startpos__1_ in
          (
# 776 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Not _2)
    )
# 1069 "lib/parser/parser.ml"
           : (Statement.condition Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.condition Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.condition Node.t) = 
# 735 "lib/parser/parser.mly"
    (
      _1
    )
# 1097 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Statement.condition Node.t) = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : (Statement.condition Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v =
          let _endpos = _endpos__3_ in
          let _startpos = _startpos__1_ in
          (
# 740 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Logical
           {
             left = _1;
             operator = Statement.Or;
             right = _3;
           })
    )
# 1147 "lib/parser/parser.ml"
           : (Statement.condition Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 201 "lib/parser/parser.mly"
       (bool)
# 1169 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 784 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Boolean _1)
    )
# 1183 "lib/parser/parser.ml"
           : (Statement.condition Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Value.reference) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 790 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Reference _1)
    )
# 1215 "lib/parser/parser.ml"
           : (Statement.condition Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Value.t Node.t) = Obj.magic _3 in
        let _2 : (Statement.comparison_operator) = Obj.magic _2 in
        let _1 : (Value.reference) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v =
          let _endpos = _endpos__3_ in
          let _startpos = _startpos__1_ in
          (
# 796 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Compare
           {
             reference = _1;
             operator = _2;
             value = _3;
           })
    )
# 1266 "lib/parser/parser.ml"
           : (Statement.condition Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : unit = Obj.magic _3 in
        let _2 : (Statement.condition Node.t) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v : (Statement.condition Node.t) = 
# 807 "lib/parser/parser.mly"
    (
      _2
    )
# 1308 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _7;
          MenhirLib.EngineTypes.startp = _startpos__7_;
          MenhirLib.EngineTypes.endp = _endpos__7_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _6;
            MenhirLib.EngineTypes.startp = _startpos__6_;
            MenhirLib.EngineTypes.endp = _endpos__6_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _5;
              MenhirLib.EngineTypes.startp = _startpos__5_;
              MenhirLib.EngineTypes.endp = _endpos__5_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _;
                MenhirLib.EngineTypes.semv = _4;
                MenhirLib.EngineTypes.startp = _startpos__4_;
                MenhirLib.EngineTypes.endp = _endpos__4_;
                MenhirLib.EngineTypes.next = {
                  MenhirLib.EngineTypes.state = _;
                  MenhirLib.EngineTypes.semv = _3;
                  MenhirLib.EngineTypes.startp = _startpos__3_;
                  MenhirLib.EngineTypes.endp = _endpos__3_;
                  MenhirLib.EngineTypes.next = {
                    MenhirLib.EngineTypes.state = _;
                    MenhirLib.EngineTypes.semv = _2;
                    MenhirLib.EngineTypes.startp = _startpos__2_;
                    MenhirLib.EngineTypes.endp = _endpos__2_;
                    MenhirLib.EngineTypes.next = {
                      MenhirLib.EngineTypes.state = _menhir_s;
                      MenhirLib.EngineTypes.semv = _1;
                      MenhirLib.EngineTypes.startp = _startpos__1_;
                      MenhirLib.EngineTypes.endp = _endpos__1_;
                      MenhirLib.EngineTypes.next = _menhir_stack;
                    };
                  };
                };
              };
            };
          };
        } = _menhir_stack in
        let _7 : (Statement.t Node.t list option) = Obj.magic _7 in
        let _6 : unit = Obj.magic _6 in
        let _5 : (Statement.t Node.t list) = Obj.magic _5 in
        let _4 : unit = Obj.magic _4 in
        let _3 : (unit) = Obj.magic _3 in
        let _2 : (Statement.condition Node.t) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__7_ in
        let _v : (Statement.conditional) = 
# 417 "lib/parser/parser.mly"
    (
      {
        Statement.condition = _2;
        then_branch = _5;
        else_branch = _7;
      }
    )
# 1381 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _4;
          MenhirLib.EngineTypes.startp = _startpos__4_;
          MenhirLib.EngineTypes.endp = _endpos__4_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _3;
            MenhirLib.EngineTypes.startp = _startpos__3_;
            MenhirLib.EngineTypes.endp = _endpos__3_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _2;
              MenhirLib.EngineTypes.startp = _startpos__2_;
              MenhirLib.EngineTypes.endp = _endpos__2_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _menhir_s;
                MenhirLib.EngineTypes.semv = _1;
                MenhirLib.EngineTypes.startp = _startpos__1_;
                MenhirLib.EngineTypes.endp = _endpos__1_;
                MenhirLib.EngineTypes.next = _menhir_stack;
              };
            };
          };
        } = _menhir_stack in
        let _4 : (Value.t Node.t) = Obj.magic _4 in
        let _3 : unit = Obj.magic _3 in
        let _2 : 
# 197 "lib/parser/parser.mly"
       (string)
# 1422 "lib/parser/parser.ml"
         = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__4_ in
        let _v : (Statement.define_statement) = 
# 393 "lib/parser/parser.mly"
    (
      {
        Statement.name = _2;
        value = _4;
      }
    )
# 1436 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _4;
          MenhirLib.EngineTypes.startp = _startpos__4_;
          MenhirLib.EngineTypes.endp = _endpos__4_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _3;
            MenhirLib.EngineTypes.startp = _startpos__3_;
            MenhirLib.EngineTypes.endp = _endpos__3_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _2;
              MenhirLib.EngineTypes.startp = _startpos__2_;
              MenhirLib.EngineTypes.endp = _endpos__2_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _menhir_s;
                MenhirLib.EngineTypes.semv = _1;
                MenhirLib.EngineTypes.startp = _startpos__1_;
                MenhirLib.EngineTypes.endp = _endpos__1_;
                MenhirLib.EngineTypes.next = _menhir_stack;
              };
            };
          };
        } = _menhir_stack in
        let _4 : (Value.t Node.t) = Obj.magic _4 in
        let _3 : unit = Obj.magic _3 in
        let _2 : 
# 197 "lib/parser/parser.mly"
       (string)
# 1477 "lib/parser/parser.ml"
         = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__4_ in
        let _v : (Statement.define_statement) = 
# 401 "lib/parser/parser.mly"
    (
      {
        Statement.name = _2;
        value = _4;
      }
    )
# 1491 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : unit = Obj.magic _3 in
        let _2 : (Statement.t Node.t list) = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v : (Statement.t Node.t list) = 
# 289 "lib/parser/parser.mly"
    (
      group_document_sections _2
    )
# 1532 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : unit = Obj.magic _3 in
        let _2 : (Value.reference) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v =
          let _endpos = _endpos__3_ in
          let _startpos = _startpos__1_ in
          (
# 308 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Section
          {
            Statement.name = _2;
            body = [];
          })
    )
# 1581 "lib/parser/parser.ml"
           : (Statement.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.t Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.t Node.t) = 
# 318 "lib/parser/parser.mly"
    (
      _1
    )
# 1609 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (Statement.t Node.t list) = 
# 296 "lib/parser/parser.mly"
    (
      []
    )
# 1629 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Statement.t Node.t list) = Obj.magic _3 in
        let _2 : (unit) = Obj.magic _2 in
        let _1 : (Statement.t Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v : (Statement.t Node.t list) = 
# 301 "lib/parser/parser.mly"
    (
      _1 :: _3
    )
# 1670 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : 
# 198 "lib/parser/parser.mly"
       (string)
# 1697 "lib/parser/parser.ml"
         = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (Statement.include_statement) = 
# 384 "lib/parser/parser.mly"
    (
      {
        Statement.path = _2;
      }
    )
# 1710 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.assignment) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 325 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Assignment _1)
    )
# 1741 "lib/parser/parser.ml"
           : (Statement.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.include_statement) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 331 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Include _1)
    )
# 1773 "lib/parser/parser.ml"
           : (Statement.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.define_statement) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 337 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Define _1)
    )
# 1805 "lib/parser/parser.ml"
           : (Statement.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.conditional) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 343 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Statement.Conditional _1)
    )
# 1837 "lib/parser/parser.ml"
           : (Statement.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 1859 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 640 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Integer _1)
    )
# 1873 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 200 "lib/parser/parser.mly"
       (float)
# 1895 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 646 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Float _1)
    )
# 1909 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (Value.object_entry list) = 
# 693 "lib/parser/parser.mly"
    (
      []
    )
# 1930 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (Value.object_entry list) = Obj.magic _2 in
        let _1 : (Value.object_entry) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (Value.object_entry list) = 
# 698 "lib/parser/parser.mly"
    (
      _1 :: _2
    )
# 1964 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Value.t Node.t) = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : (Value.reference) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v =
          let _endpos = _endpos__3_ in
          let _startpos = _startpos__1_ in
          (
# 717 "lib/parser/parser.mly"
    (
      object_entry
        _1
        _3
        _startpos
        _endpos
    )
# 2012 "lib/parser/parser.ml"
           : (Value.object_entry))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Value.object_entry list) = 
# 705 "lib/parser/parser.mly"
    (
      []
    )
# 2040 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _4;
          MenhirLib.EngineTypes.startp = _startpos__4_;
          MenhirLib.EngineTypes.endp = _endpos__4_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _3;
            MenhirLib.EngineTypes.startp = _startpos__3_;
            MenhirLib.EngineTypes.endp = _endpos__3_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _2;
              MenhirLib.EngineTypes.startp = _startpos__2_;
              MenhirLib.EngineTypes.endp = _endpos__2_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _menhir_s;
                MenhirLib.EngineTypes.semv = _1;
                MenhirLib.EngineTypes.startp = _startpos__1_;
                MenhirLib.EngineTypes.endp = _endpos__1_;
                MenhirLib.EngineTypes.next = _menhir_stack;
              };
            };
          };
        } = _menhir_stack in
        let _4 : (Value.object_entry list) = Obj.magic _4 in
        let _3 : (unit) = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__4_ in
        let _v : (Value.object_entry list) = 
# 710 "lib/parser/parser.mly"
    (
      _4
    )
# 2088 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _4;
          MenhirLib.EngineTypes.startp = _startpos__4_;
          MenhirLib.EngineTypes.endp = _endpos__4_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _3;
            MenhirLib.EngineTypes.startp = _startpos__3_;
            MenhirLib.EngineTypes.endp = _endpos__3_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _2;
              MenhirLib.EngineTypes.startp = _startpos__2_;
              MenhirLib.EngineTypes.endp = _endpos__2_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _menhir_s;
                MenhirLib.EngineTypes.semv = _1;
                MenhirLib.EngineTypes.startp = _startpos__1_;
                MenhirLib.EngineTypes.endp = _endpos__1_;
                MenhirLib.EngineTypes.next = _menhir_stack;
              };
            };
          };
        } = _menhir_stack in
        let _4 : unit = Obj.magic _4 in
        let _3 : (Value.object_entry list) = Obj.magic _3 in
        let _2 : (unit) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__4_ in
        let _v : (Value.object_entry list) = 
# 686 "lib/parser/parser.mly"
    (
      _3
    )
# 2136 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (Statement.t Node.t list option) = 
# 428 "lib/parser/parser.mly"
    (
      None
    )
# 2156 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _5;
          MenhirLib.EngineTypes.startp = _startpos__5_;
          MenhirLib.EngineTypes.endp = _endpos__5_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _4;
            MenhirLib.EngineTypes.startp = _startpos__4_;
            MenhirLib.EngineTypes.endp = _endpos__4_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _3;
              MenhirLib.EngineTypes.startp = _startpos__3_;
              MenhirLib.EngineTypes.endp = _endpos__3_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _;
                MenhirLib.EngineTypes.semv = _2;
                MenhirLib.EngineTypes.startp = _startpos__2_;
                MenhirLib.EngineTypes.endp = _endpos__2_;
                MenhirLib.EngineTypes.next = {
                  MenhirLib.EngineTypes.state = _menhir_s;
                  MenhirLib.EngineTypes.semv = _1;
                  MenhirLib.EngineTypes.startp = _startpos__1_;
                  MenhirLib.EngineTypes.endp = _endpos__1_;
                  MenhirLib.EngineTypes.next = _menhir_stack;
                };
              };
            };
          };
        } = _menhir_stack in
        let _5 : unit = Obj.magic _5 in
        let _4 : (Statement.t Node.t list) = Obj.magic _4 in
        let _3 : unit = Obj.magic _3 in
        let _2 : (unit) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__5_ in
        let _v : (Statement.t Node.t list option) = 
# 437 "lib/parser/parser.mly"
    (
      Some _4
    )
# 2211 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (string) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Value.reference) = 
# 505 "lib/parser/parser.mly"
    ( [_1] )
# 2236 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _3;
          MenhirLib.EngineTypes.startp = _startpos__3_;
          MenhirLib.EngineTypes.endp = _endpos__3_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _2;
            MenhirLib.EngineTypes.startp = _startpos__2_;
            MenhirLib.EngineTypes.endp = _endpos__2_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _menhir_s;
              MenhirLib.EngineTypes.semv = _1;
              MenhirLib.EngineTypes.startp = _startpos__1_;
              MenhirLib.EngineTypes.endp = _endpos__1_;
              MenhirLib.EngineTypes.next = _menhir_stack;
            };
          };
        } = _menhir_stack in
        let _3 : (Value.reference) = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : (string) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__3_ in
        let _v : (Value.reference) = 
# 507 "lib/parser/parser.mly"
    ( _1 :: _3 )
# 2275 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 197 "lib/parser/parser.mly"
       (string)
# 2296 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 481 "lib/parser/parser.mly"
    ( _1 )
# 2304 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 483 "lib/parser/parser.mly"
    ( "null" )
# 2329 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 485 "lib/parser/parser.mly"
    ( "include" )
# 2354 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 487 "lib/parser/parser.mly"
    ( "when" )
# 2379 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 489 "lib/parser/parser.mly"
    ( "rgb" )
# 2404 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 491 "lib/parser/parser.mly"
    ( "rgba" )
# 2429 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 493 "lib/parser/parser.mly"
    ( "define" )
# 2454 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 201 "lib/parser/parser.mly"
       (bool)
# 2475 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (string) = 
# 495 "lib/parser/parser.mly"
    (
      if _1 then
        "true"
      else
        "false"
    )
# 2488 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (Value.reference) = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (Value.reference) = 
# 512 "lib/parser/parser.mly"
    (
      _2
    )
# 2522 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (unit) = 
# 271 "lib/parser/parser.mly"
    (
      ()
    )
# 2549 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (unit) = 
# 275 "lib/parser/parser.mly"
    (
      ()
    )
# 2576 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (unit) = 
# 249 "lib/parser/parser.mly"
    (
      ()
    )
# 2596 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (unit) = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (unit) = 
# 253 "lib/parser/parser.mly"
    (
      ()
    )
# 2630 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (unit) = 
# 260 "lib/parser/parser.mly"
    (
      ()
    )
# 2657 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (unit) = Obj.magic _2 in
        let _1 : (unit) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (unit) = 
# 264 "lib/parser/parser.mly"
    (
      ()
    )
# 2691 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Statement.t Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v : (Statement.t Node.t) = 
# 282 "lib/parser/parser.mly"
    (
      _1
    )
# 2718 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let _menhir_s = _menhir_env.MenhirLib.EngineTypes.current in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _endpos = _startpos in
        let _v : (Statement.t Node.t list) = 
# 452 "lib/parser/parser.mly"
    (
      []
    )
# 2738 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _2;
          MenhirLib.EngineTypes.startp = _startpos__2_;
          MenhirLib.EngineTypes.endp = _endpos__2_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _menhir_s;
            MenhirLib.EngineTypes.semv = _1;
            MenhirLib.EngineTypes.startp = _startpos__1_;
            MenhirLib.EngineTypes.endp = _endpos__1_;
            MenhirLib.EngineTypes.next = _menhir_stack;
          };
        } = _menhir_stack in
        let _2 : (Statement.t Node.t list) = Obj.magic _2 in
        let _1 : (Statement.t Node.t) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__2_ in
        let _v : (Statement.t Node.t list) = 
# 457 "lib/parser/parser.mly"
    (
      _1 :: _2
    )
# 2772 "lib/parser/parser.ml"
         in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 198 "lib/parser/parser.mly"
       (string)
# 2793 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 519 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.String _1)
    )
# 2807 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 2829 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 525 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Integer _1)
    )
# 2843 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 200 "lib/parser/parser.mly"
       (float)
# 2865 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 531 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Float _1)
    )
# 2879 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 201 "lib/parser/parser.mly"
       (bool)
# 2901 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 537 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Boolean _1)
    )
# 2915 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 543 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        Value.Null
    )
# 2947 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Value.reference) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 549 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Reference _1)
    )
# 2979 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 203 "lib/parser/parser.mly"
       (string)
# 3001 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 555 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Color (color_of_hex _1))
    )
# 3015 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 204 "lib/parser/parser.mly"
       (float * Value.duration_unit)
# 3037 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 561 "lib/parser/parser.mly"
    (
      let amount, unit = _1 in
      located _startpos _endpos
        (Value.Duration (amount, unit))
    )
# 3052 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : 
# 205 "lib/parser/parser.mly"
       (float * Value.size_unit)
# 3074 "lib/parser/parser.ml"
         = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 568 "lib/parser/parser.mly"
    (
      let amount, unit = _1 in
      located _startpos _endpos
        (Value.Size (amount, unit))
    )
# 3089 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Value.t Node.t list) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 575 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Array _1)
    )
# 3121 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = _1;
          MenhirLib.EngineTypes.startp = _startpos__1_;
          MenhirLib.EngineTypes.endp = _endpos__1_;
          MenhirLib.EngineTypes.next = _menhir_stack;
        } = _menhir_stack in
        let _1 : (Value.object_entry list) = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__1_ in
        let _v =
          let _endpos = _endpos__1_ in
          let _startpos = _startpos__1_ in
          (
# 581 "lib/parser/parser.mly"
    (
      located _startpos _endpos
        (Value.Object _1)
    )
# 3153 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _8;
          MenhirLib.EngineTypes.startp = _startpos__8_;
          MenhirLib.EngineTypes.endp = _endpos__8_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _7;
            MenhirLib.EngineTypes.startp = _startpos__7_;
            MenhirLib.EngineTypes.endp = _endpos__7_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _6;
              MenhirLib.EngineTypes.startp = _startpos__6_;
              MenhirLib.EngineTypes.endp = _endpos__6_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _;
                MenhirLib.EngineTypes.semv = _5;
                MenhirLib.EngineTypes.startp = _startpos__5_;
                MenhirLib.EngineTypes.endp = _endpos__5_;
                MenhirLib.EngineTypes.next = {
                  MenhirLib.EngineTypes.state = _;
                  MenhirLib.EngineTypes.semv = _4;
                  MenhirLib.EngineTypes.startp = _startpos__4_;
                  MenhirLib.EngineTypes.endp = _endpos__4_;
                  MenhirLib.EngineTypes.next = {
                    MenhirLib.EngineTypes.state = _;
                    MenhirLib.EngineTypes.semv = _3;
                    MenhirLib.EngineTypes.startp = _startpos__3_;
                    MenhirLib.EngineTypes.endp = _endpos__3_;
                    MenhirLib.EngineTypes.next = {
                      MenhirLib.EngineTypes.state = _;
                      MenhirLib.EngineTypes.semv = _2;
                      MenhirLib.EngineTypes.startp = _startpos__2_;
                      MenhirLib.EngineTypes.endp = _endpos__2_;
                      MenhirLib.EngineTypes.next = {
                        MenhirLib.EngineTypes.state = _menhir_s;
                        MenhirLib.EngineTypes.semv = _1;
                        MenhirLib.EngineTypes.startp = _startpos__1_;
                        MenhirLib.EngineTypes.endp = _endpos__1_;
                        MenhirLib.EngineTypes.next = _menhir_stack;
                      };
                    };
                  };
                };
              };
            };
          };
        } = _menhir_stack in
        let _8 : unit = Obj.magic _8 in
        let _7 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3218 "lib/parser/parser.ml"
         = Obj.magic _7 in
        let _6 : unit = Obj.magic _6 in
        let _5 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3224 "lib/parser/parser.ml"
         = Obj.magic _5 in
        let _4 : unit = Obj.magic _4 in
        let _3 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3230 "lib/parser/parser.ml"
         = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__8_ in
        let _v =
          let _endpos = _endpos__8_ in
          let _startpos = _startpos__1_ in
          (
# 587 "lib/parser/parser.mly"
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
# 3263 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
      (fun _menhir_env ->
        let _menhir_stack = _menhir_env.MenhirLib.EngineTypes.stack in
        let {
          MenhirLib.EngineTypes.state = _;
          MenhirLib.EngineTypes.semv = _10;
          MenhirLib.EngineTypes.startp = _startpos__10_;
          MenhirLib.EngineTypes.endp = _endpos__10_;
          MenhirLib.EngineTypes.next = {
            MenhirLib.EngineTypes.state = _;
            MenhirLib.EngineTypes.semv = _9;
            MenhirLib.EngineTypes.startp = _startpos__9_;
            MenhirLib.EngineTypes.endp = _endpos__9_;
            MenhirLib.EngineTypes.next = {
              MenhirLib.EngineTypes.state = _;
              MenhirLib.EngineTypes.semv = _8;
              MenhirLib.EngineTypes.startp = _startpos__8_;
              MenhirLib.EngineTypes.endp = _endpos__8_;
              MenhirLib.EngineTypes.next = {
                MenhirLib.EngineTypes.state = _;
                MenhirLib.EngineTypes.semv = _7;
                MenhirLib.EngineTypes.startp = _startpos__7_;
                MenhirLib.EngineTypes.endp = _endpos__7_;
                MenhirLib.EngineTypes.next = {
                  MenhirLib.EngineTypes.state = _;
                  MenhirLib.EngineTypes.semv = _6;
                  MenhirLib.EngineTypes.startp = _startpos__6_;
                  MenhirLib.EngineTypes.endp = _endpos__6_;
                  MenhirLib.EngineTypes.next = {
                    MenhirLib.EngineTypes.state = _;
                    MenhirLib.EngineTypes.semv = _5;
                    MenhirLib.EngineTypes.startp = _startpos__5_;
                    MenhirLib.EngineTypes.endp = _endpos__5_;
                    MenhirLib.EngineTypes.next = {
                      MenhirLib.EngineTypes.state = _;
                      MenhirLib.EngineTypes.semv = _4;
                      MenhirLib.EngineTypes.startp = _startpos__4_;
                      MenhirLib.EngineTypes.endp = _endpos__4_;
                      MenhirLib.EngineTypes.next = {
                        MenhirLib.EngineTypes.state = _;
                        MenhirLib.EngineTypes.semv = _3;
                        MenhirLib.EngineTypes.startp = _startpos__3_;
                        MenhirLib.EngineTypes.endp = _endpos__3_;
                        MenhirLib.EngineTypes.next = {
                          MenhirLib.EngineTypes.state = _;
                          MenhirLib.EngineTypes.semv = _2;
                          MenhirLib.EngineTypes.startp = _startpos__2_;
                          MenhirLib.EngineTypes.endp = _endpos__2_;
                          MenhirLib.EngineTypes.next = {
                            MenhirLib.EngineTypes.state = _menhir_s;
                            MenhirLib.EngineTypes.semv = _1;
                            MenhirLib.EngineTypes.startp = _startpos__1_;
                            MenhirLib.EngineTypes.endp = _endpos__1_;
                            MenhirLib.EngineTypes.next = _menhir_stack;
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        } = _menhir_stack in
        let _10 : unit = Obj.magic _10 in
        let _9 : (Value.t Node.t) = Obj.magic _9 in
        let _8 : unit = Obj.magic _8 in
        let _7 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3342 "lib/parser/parser.ml"
         = Obj.magic _7 in
        let _6 : unit = Obj.magic _6 in
        let _5 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3348 "lib/parser/parser.ml"
         = Obj.magic _5 in
        let _4 : unit = Obj.magic _4 in
        let _3 : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3354 "lib/parser/parser.ml"
         = Obj.magic _3 in
        let _2 : unit = Obj.magic _2 in
        let _1 : unit = Obj.magic _1 in
        let _endpos__0_ = _menhir_stack.MenhirLib.EngineTypes.endp in
        let _startpos = _startpos__1_ in
        let _endpos = _endpos__10_ in
        let _v =
          let _endpos = _endpos__10_ in
          let _startpos = _startpos__1_ in
          (
# 610 "lib/parser/parser.mly"
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
# 3392 "lib/parser/parser.ml"
           : (Value.t Node.t))
        in
        {
          MenhirLib.EngineTypes.state = _menhir_s;
          MenhirLib.EngineTypes.semv = Obj.repr _v;
          MenhirLib.EngineTypes.startp = _startpos;
          MenhirLib.EngineTypes.endp = _endpos;
          MenhirLib.EngineTypes.next = _menhir_stack;
        });
    |]
  
  let terminal_count =
    42
  
  let token2terminal : token -> int =
    fun _tok ->
      match _tok with
      | WHEN ->
          1
      | SUB_ASSIGN ->
          2
      | STRING _ ->
          3
      | SIZE _ ->
          4
      | SEMICOLON ->
          5
      | RPAREN ->
          6
      | RGBA ->
          7
      | RGB ->
          8
      | RBRACKET ->
          9
      | RBRACE ->
          10
      | OR ->
          11
      | NULL ->
          12
      | NOT ->
          13
      | NEWLINE ->
          14
      | NEQ ->
          15
      | LTE ->
          16
      | LT ->
          17
      | LPAREN ->
          18
      | LBRACKET ->
          19
      | LBRACE ->
          20
      | INTEGER _ ->
          21
      | INCLUDE ->
          22
      | IDENTIFIER _ ->
          23
      | GTE ->
          24
      | GT ->
          25
      | FLOAT _ ->
          26
      | EQEQ ->
          27
      | EOF ->
          28
      | ELSE ->
          29
      | DURATION _ ->
          30
      | DOT ->
          31
      | DOLLAR ->
          32
      | DEFINE_ASSIGN ->
          33
      | DEFINE ->
          34
      | COMMA ->
          35
      | COLOR _ ->
          36
      | COLON ->
          37
      | BOOLEAN _ ->
          38
      | ASSIGN ->
          39
      | AND ->
          40
      | ADD_ASSIGN ->
          41
  
  let error_terminal =
    0
  
  let token2value : token -> Obj.t =
    fun _tok ->
      match _tok with
      | WHEN ->
          Obj.repr ()
      | SUB_ASSIGN ->
          Obj.repr ()
      | STRING _v ->
          Obj.repr (_v : 
# 198 "lib/parser/parser.mly"
       (string)
# 3507 "lib/parser/parser.ml"
          )
      | SIZE _v ->
          Obj.repr (_v : 
# 205 "lib/parser/parser.mly"
       (float * Value.size_unit)
# 3513 "lib/parser/parser.ml"
          )
      | SEMICOLON ->
          Obj.repr ()
      | RPAREN ->
          Obj.repr ()
      | RGBA ->
          Obj.repr ()
      | RGB ->
          Obj.repr ()
      | RBRACKET ->
          Obj.repr ()
      | RBRACE ->
          Obj.repr ()
      | OR ->
          Obj.repr ()
      | NULL ->
          Obj.repr ()
      | NOT ->
          Obj.repr ()
      | NEWLINE ->
          Obj.repr ()
      | NEQ ->
          Obj.repr ()
      | LTE ->
          Obj.repr ()
      | LT ->
          Obj.repr ()
      | LPAREN ->
          Obj.repr ()
      | LBRACKET ->
          Obj.repr ()
      | LBRACE ->
          Obj.repr ()
      | INTEGER _v ->
          Obj.repr (_v : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3551 "lib/parser/parser.ml"
          )
      | INCLUDE ->
          Obj.repr ()
      | IDENTIFIER _v ->
          Obj.repr (_v : 
# 197 "lib/parser/parser.mly"
       (string)
# 3559 "lib/parser/parser.ml"
          )
      | GTE ->
          Obj.repr ()
      | GT ->
          Obj.repr ()
      | FLOAT _v ->
          Obj.repr (_v : 
# 200 "lib/parser/parser.mly"
       (float)
# 3569 "lib/parser/parser.ml"
          )
      | EQEQ ->
          Obj.repr ()
      | EOF ->
          Obj.repr ()
      | ELSE ->
          Obj.repr ()
      | DURATION _v ->
          Obj.repr (_v : 
# 204 "lib/parser/parser.mly"
       (float * Value.duration_unit)
# 3581 "lib/parser/parser.ml"
          )
      | DOT ->
          Obj.repr ()
      | DOLLAR ->
          Obj.repr ()
      | DEFINE_ASSIGN ->
          Obj.repr ()
      | DEFINE ->
          Obj.repr ()
      | COMMA ->
          Obj.repr ()
      | COLOR _v ->
          Obj.repr (_v : 
# 203 "lib/parser/parser.mly"
       (string)
# 3597 "lib/parser/parser.ml"
          )
      | COLON ->
          Obj.repr ()
      | BOOLEAN _v ->
          Obj.repr (_v : 
# 201 "lib/parser/parser.mly"
       (bool)
# 3605 "lib/parser/parser.ml"
          )
      | ASSIGN ->
          Obj.repr ()
      | AND ->
          Obj.repr ()
      | ADD_ASSIGN ->
          Obj.repr ()
  
  let default_reduction =
    "E\000\000\000\000\000=?>;<:@A\000\0009B\029\000\017\019\018\021\020\016\000LT\000\000\000\000\000\000\000\000./\000X\000\000\000\000\000\000\000WPE\000DCE\000F\000\000MNSRO2QVUE\000E\00041\0005E\000E\000\006\004\000\002\031\025\000\000\023\000\000\024\000\000 \026E\000E\000\000)\000\000\000#\000\"\015\000\000\000G\014H\000\011\t\b\n\000\007I+,-*K\000\000E\000E\0007!\000\000%&\000$E\000(\001"
  
  let[@inline] default_reduction =
    fun i ->
      MenhirLib.PackedIntArray.get8 default_reduction i
  
  let error =
    "\000\000\000\000\000\017b\132\194\b\130\000B\000\0284\000\016\128\002\b\000\004 \000\130\016b\000\192\b\128\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\006\127\189\189\151}\006 \012\000\136\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\024O#@\002\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\152\129\194(\160\000\000\000\000\000\000\000\000\000\000\000\000\b\000\000\000\000\000@\000\000\000\000\000\000@\000\000\004\000\000\000\000\000\000\004\000\000\000@\000\000\000\000\000\000@\000\000\004 \000\000\000\000\000\000\000\000\000\000\000\000\b\000\000\000\000\000\000\000\000\000\000\000\b\000\000\000\000\000@\000\000\000\000\000\000@\000\000\004\000\000\000\000\000\000\004\000\000\000@\000\000\b\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000w(p\138(\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\022\168\012\000\136\000\000\000\000\000\000\000\000\000\001\001\152\129\194(\160\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\b\128\000\004\000\000\000\000\000\001\022\168\012\000\136\000\000\000\000\000\000\000\000\000\000\000\002\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\016\128\000\004\000\000\000\000\000\000w(p\138(\000\000\000\000\000\000\000\000\000\000\000\004\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000a \128\000\000\000\016\128\002\b\000\000\000\000\000\001\132\130\000\000 \000B\000\b \000\000\000\000\000\006\018\b\000\000\128\128\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\001\000\130\000\000\000\000\000\000\000\001\022\168\012\000\1360\000\000\001A@\000\000\000\000\002\000\000\016\020\020\000\000\000\001\004\025\136\028\"\138\000\000\000\000\000\001\152\129\194(\160\000\000\000\000\000\000\000\000\000\000\001\b\128\000\000\004Z\1600\002 \016\136\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\128\000\000\001\005\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\025\136\028\"\138\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000 \000\000\000\017j\132\195\b\128\000\000\000\000\000\016\b \000\000\000\000\000\000\000\000\b\000\000\000\000\000\000\000\000\000\000\000\000\000\000A\136\003\000\"\000\016\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\b\000\000\000\000\000\000\000\000\000\000\000\001\022(L \136\000\000\000\000\000\000\000\000\000\000\000"
  
  let[@inline] error =
    fun i ->
      MenhirLib.PackedIntArray.get1 error i
  
  let[@inline] error =
    fun i j ->
      error (42 * i + j)
  
  let start =
    1
  
  let action_displacement =
    "\000\000\000\140\001V\001V\001V\000\254\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\003\000\254\000\000\000\000\000\000\0010\000\000\000\000\000\000\000\000\000\000\000\000\000L\000\000\000\000\000\158\000\160\000j\000\132\000`\000x\000J\000\019\000\000\000\000\000^\000\000\000\026\000\028\000\018\000<\000\015\000Z\000\t\000\000\000\000\000\000\000L\000\000\000\000\000\000\000\254\000\000\000<\000L\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000L\000\000\000\254\000\000\000\000\000\172\000\000\000\000\000\140\000\000\000L\000\000\000\000\000\180\000\000\000\000\000\000\000b\001V\000\000\001\132\001V\000\000\000\160\000\178\000\000\000\000\000\000\000\140\000\000\001Z\000\230\000\000\001\128\000.\000L\000\000\000L\000\000\000\000\000\030\000\140\000\030\000\000\000\000\000\000\001*\000\000\000\000\000\000\000\000\000L\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000f\000\204\000\000\000\254\000\000\000N\000\000\000\000\000\254\000\r\000\000\000\000\000J\000\000\000\000\000\140\000\000\000\000"
  
  let[@inline] action_displacement =
    fun i ->
      MenhirLib.PackedIntArray.get16 action_displacement i
  
  let action_data =
    "\000\221\000\221\000\194\002*\000\221\000\221\000\221\000\221\000\221\000\221\000\221\000\221\000\150\000\221\000\221\000\221\000\221\000\154\000\221\000\221\000\210\000\221\000\221\000\221\000\221\000-\000\221\000\221\000\186\000\214\000>\000\170\000\221\000\221\000\221\000\174\000\221\000\221\000\221\000\221\000\221\000n\000r\000\210\000\178\000v\000\166\000\t\000\201\002\026\000\198\000\182\000\214\000\162\000U\000U\001\162\000\202\000\218\000\238\001^\002\006\001\170\000U\000\242\0027\000\190\000\234\000\246\000U\000\022\000\n\000\146\001\026\000\250\000\210\000\254\000\030\000\"\000\017\0001\000\142\000&\000\138\000\214\000i\000i\000\134\000\130\002\"\001\138\000i\001\146\000.\000i\001z\001.\000z\000\153\001N\000i\000~\000\000\000\213\001\154\001:\000\000\000\213\0006\000\213\000\213\000\000\000\213\000\000\000\213\000\000\000\213\000\237\001\150\000\000\001j\000\213\000\000\000\000\000\213\000\213\000\000\000\000\000\026\000\000\000\213\002\n\000\210\000\000\000\030\000\"\000\213\000\189\000\000\000&\000\213\000\214\000\000\000\000\000\000\000\000\000\237\002\018\000\237\000*\000.\001\210\000\000\000\000\000\237\000\000\000\237\000u\000u\000\000\000\000\0002\000\000\000u\000\000\0006\000u\000R\000V\000Z\000\000\000\000\000u\000\241\000\n\000\000\000^\000b\000\210\000f\000\030\000\"\001\214\001%\000\014\000&\000\000\000\214\001\218\000\018\001\222\000\000\000u\000\000\000\253\001\146\000.\000\000\000\000\000m\000m\000\000\000\241\000\022\000\241\000m\000\000\001\154\000m\000J\000\241\0006\000\241\000\000\000m\001\158\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\253\000\000\000\253\000\000\000\000\000\000\000\000\000\000\000\253\000\000\000\253\001j"
  
  let[@inline] action_data =
    fun i ->
      MenhirLib.PackedIntArray.get16 action_data i
  
  let[@inline] action =
    fun i j ->
      let k = MenhirLib.RowDisplacementDecode.decode (action_displacement i) in
      action_data (k + j)
  
  let lhs =
    "\000#\"\"!! \031\031\031\031\030\030\030\029\028\028\028\028\028\028\027\026\026\025\025\024\024\023\023\023\023\022\021\021\020\019\019\018\018\017\016\016\016\016\015\015\014\014\r\012\012\011\n\n\t\t\b\b\b\b\b\b\b\b\007\006\006\005\005\004\004\003\002\002\001\001\001\001\001\001\001\001\001\001\001\001\001"
  
  let[@inline] lhs =
    fun i ->
      MenhirLib.PackedIntArray.get8 lhs i
  
  let goto_displacement =
    "\003\003t\228Z@\000\000\000\000\000\000\000\000\000H\000\000\000d\000\000\000\000\000\000\224\000\000\000\000\000\000\000\000\000\178\000\000\000\000\000\000\000\000\000\000\000\000\000b\003\000\000\144\178\000\000\230\000\000\000\000\000\000\000\000\000D*\174\160\000\000\000\000V*\172*\000\000\000\000\000\000\000\178\000\000\226\000\000\000\000\000\164*\007*\000\000\000\000\200\000\196\000\000\242t\n\000\000\000\n\000\000\000\000\198\000\000\000\000\000\000\000\000R\018*\t\000\000\000\b\000\000\000\000\000\005R\000\000"
  
  let[@inline] goto_displacement =
    fun i ->
      MenhirLib.PackedIntArray.get8 goto_displacement i
  
  let goto_data =
    "Mdd\144\0029B\015toCq\015\138\132\140|\141\143\146}~Mmn\134\1299B\015t\127CSDry{|F\015\018}~\015\017J9N\015t\136\020\1274QD\140|\145\143p}~s\020\015tVWY]^\127{|R8\027}~VWY]a9b\015:\127PHEI9\020\015:lzjEK(BBB\000CCCVUYZA\000\000B\020\020BC\000oCq\000\000\000\000\000DDDVV\\`\000\000\000\000\000\000\000D\000\000D\128"
  
  let[@inline] goto_data =
    fun i ->
      MenhirLib.PackedIntArray.get8 goto_data i
  
  let[@inline] goto =
    fun i j ->
      let k = MenhirLib.RowDisplacementDecode.decode (goto_displacement i) in
      goto_data (k + j)
  
  let trace =
    None
  
end

module MenhirInterpreter = struct
  
  module ET = MenhirLib.TableInterpreter.MakeEngineTable (Tables)
  
  module TI = MenhirLib.Engine.Make (ET)
  
  include TI
  
  module Symbols = struct
    
    type _ terminal = 
      | T_error : unit terminal
      | T_WHEN : unit terminal
      | T_SUB_ASSIGN : unit terminal
      | T_STRING : 
# 198 "lib/parser/parser.mly"
       (string)
# 3702 "lib/parser/parser.ml"
     terminal
      | T_SIZE : 
# 205 "lib/parser/parser.mly"
       (float * Value.size_unit)
# 3707 "lib/parser/parser.ml"
     terminal
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
      | T_INTEGER : 
# 199 "lib/parser/parser.mly"
       (int64)
# 3728 "lib/parser/parser.ml"
     terminal
      | T_INCLUDE : unit terminal
      | T_IDENTIFIER : 
# 197 "lib/parser/parser.mly"
       (string)
# 3734 "lib/parser/parser.ml"
     terminal
      | T_GTE : unit terminal
      | T_GT : unit terminal
      | T_FLOAT : 
# 200 "lib/parser/parser.mly"
       (float)
# 3741 "lib/parser/parser.ml"
     terminal
      | T_EQEQ : unit terminal
      | T_EOF : unit terminal
      | T_ELSE : unit terminal
      | T_DURATION : 
# 204 "lib/parser/parser.mly"
       (float * Value.duration_unit)
# 3749 "lib/parser/parser.ml"
     terminal
      | T_DOT : unit terminal
      | T_DOLLAR : unit terminal
      | T_DEFINE_ASSIGN : unit terminal
      | T_DEFINE : unit terminal
      | T_COMMA : unit terminal
      | T_COLOR : 
# 203 "lib/parser/parser.mly"
       (string)
# 3759 "lib/parser/parser.ml"
     terminal
      | T_COLON : unit terminal
      | T_BOOLEAN : 
# 201 "lib/parser/parser.mly"
       (bool)
# 3765 "lib/parser/parser.ml"
     terminal
      | T_ASSIGN : unit terminal
      | T_AND : unit terminal
      | T_ADD_ASSIGN : unit terminal
    
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
    
  end
  
  include Symbols
  
  include MenhirLib.InspectionTableInterpreter.Make (Tables) (struct
    
    include TI
    
    include Symbols
    
    include MenhirLib.InspectionTableInterpreter.Symbols (Symbols)
    
    let terminal =
      fun t ->
        match t with
        | 0 ->
            X (T T_error)
        | 1 ->
            X (T T_WHEN)
        | 2 ->
            X (T T_SUB_ASSIGN)
        | 3 ->
            X (T T_STRING)
        | 4 ->
            X (T T_SIZE)
        | 5 ->
            X (T T_SEMICOLON)
        | 6 ->
            X (T T_RPAREN)
        | 7 ->
            X (T T_RGBA)
        | 8 ->
            X (T T_RGB)
        | 9 ->
            X (T T_RBRACKET)
        | 10 ->
            X (T T_RBRACE)
        | 11 ->
            X (T T_OR)
        | 12 ->
            X (T T_NULL)
        | 13 ->
            X (T T_NOT)
        | 14 ->
            X (T T_NEWLINE)
        | 15 ->
            X (T T_NEQ)
        | 16 ->
            X (T T_LTE)
        | 17 ->
            X (T T_LT)
        | 18 ->
            X (T T_LPAREN)
        | 19 ->
            X (T T_LBRACKET)
        | 20 ->
            X (T T_LBRACE)
        | 21 ->
            X (T T_INTEGER)
        | 22 ->
            X (T T_INCLUDE)
        | 23 ->
            X (T T_IDENTIFIER)
        | 24 ->
            X (T T_GTE)
        | 25 ->
            X (T T_GT)
        | 26 ->
            X (T T_FLOAT)
        | 27 ->
            X (T T_EQEQ)
        | 28 ->
            X (T T_EOF)
        | 29 ->
            X (T T_ELSE)
        | 30 ->
            X (T T_DURATION)
        | 31 ->
            X (T T_DOT)
        | 32 ->
            X (T T_DOLLAR)
        | 33 ->
            X (T T_DEFINE_ASSIGN)
        | 34 ->
            X (T T_DEFINE)
        | 35 ->
            X (T T_COMMA)
        | 36 ->
            X (T T_COLOR)
        | 37 ->
            X (T T_COLON)
        | 38 ->
            X (T T_BOOLEAN)
        | 39 ->
            X (T T_ASSIGN)
        | 40 ->
            X (T T_AND)
        | 41 ->
            X (T T_ADD_ASSIGN)
        | _ ->
            assert false
    
    let nonterminal =
      fun nt ->
        match nt with
        | 35 ->
            X (N N_array)
        | 34 ->
            X (N N_array_contents)
        | 33 ->
            X (N N_array_tail)
        | 32 ->
            X (N N_assignment)
        | 31 ->
            X (N N_assignment_operator)
        | 30 ->
            X (N N_block_statement_tail)
        | 29 ->
            X (N N_block_statements)
        | 28 ->
            X (N N_comparison_operator)
        | 27 ->
            X (N N_condition)
        | 26 ->
            X (N N_condition_and)
        | 25 ->
            X (N N_condition_not)
        | 24 ->
            X (N N_condition_or)
        | 23 ->
            X (N N_condition_primary)
        | 22 ->
            X (N N_conditional)
        | 21 ->
            X (N N_define_statement)
        | 20 ->
            X (N N_document)
        | 19 ->
            X (N N_flat_document_item)
        | 18 ->
            X (N N_flat_document_items)
        | 17 ->
            X (N N_include_statement)
        | 16 ->
            X (N N_non_section_statement)
        | 15 ->
            X (N N_numeric_value)
        | 14 ->
            X (N N_object_contents)
        | 13 ->
            X (N N_object_entry)
        | 12 ->
            X (N N_object_tail)
        | 11 ->
            X (N N_object_value)
        | 10 ->
            X (N N_optional_else)
        | 9 ->
            X (N N_path)
        | 8 ->
            X (N N_path_component)
        | 7 ->
            X (N N_reference)
        | 6 ->
            X (N N_separator)
        | 5 ->
            X (N N_separators)
        | 4 ->
            X (N N_separators1)
        | 3 ->
            X (N N_statement)
        | 2 ->
            X (N N_statements_before_rbrace)
        | 1 ->
            X (N N_value)
        | _ ->
            assert false
    
    let lr0_incoming =
      "\000\011\004\028&B\004\016\018\026.0FN\017@\019\019N\015 \"$2489\b\n\016&,H,H,H,6\031\014\018&,H,H,\014\026(\011\012\030*\011\r\019L,6>JN\003\015\023G\027\011H\011\029\025\029\022\003\011H\011ECE\020\003/1\02435R357\01437\011*\011.\bF0D\003P\003\005\007\t\007\r=\r\019\006DPT?\003!#+-A=;\022<\011*;\022\021(\019\020!%:'\011%)"
    
    let[@inline] lr0_incoming =
      fun i ->
        MenhirLib.PackedIntArray.get8 lr0_incoming i
    
    let rhs_data =
      ")(\011E\020\003C\011\011H\011E\019?\003PDT\006\t\t\007=\011\0058 $\"42135R3/\028351\0245N\015\0159\003&7\014\0047\011*;\022\021F0P\003F0D\003\011%:(\019\020!'\011%.\bA#+-,6\027\025\019L\003\011\011H\011\029*\011\029\022<\011*;\022\017\017@\0190\026.\004\018\016FNB\019\030\012\011\r\r\t\r!\007=\b,6N\026\015J>\nG\023\018&,H,H,\014\016&,H,H,H\031\014"
    
    let[@inline] rhs_data =
      fun i ->
        MenhirLib.PackedIntArray.get8 rhs_data i
    
    let rhs_entry =
      "\000\001\005\005\007\b\012\015\016\017\018\019\019\020\023\025\026\027\028\029\030\031 !$%'(+,-03:>BEHIILNOPQRSTTVYZ^bbghklmnopqrsuvwwyz|}}\127\128\129\130\131\132\133\134\135\136\137\138\146\156"
    
    let[@inline] rhs_entry =
      fun i ->
        MenhirLib.PackedIntArray.get8 rhs_entry i
    
    let[@inline] rhs =
      fun i ->
        MenhirLib.LinearizedArray.read_row_via rhs_data rhs_entry i
    
    let lr0_core =
      "\000\001\002\003\004\005\006\007\b\t\n\011\012\r\014\015\016\017\018\019\020\021\022\023\024\025\026\027\028\029\030\031 !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\127\128\129\130\131\132\133\134\135\136\137\138\139\140\141\142\143\144\145"
    
    let[@inline] lr0_core =
      fun i ->
        MenhirLib.PackedIntArray.get8 lr0_core i
    
    let lr0_items_data =
      "\000\000\000\000\000\001\020\001\000\000\140\001\000\000\240\001\000\000\128\001\000\000d\001\000\000|\001\000\001\004\001\000\000\240\001\000\000\248\001\000\000\244\001\000\000\232\001\000\000\236\001\000\000\228\001\000\000\252\001\000\001\000\001\000\000\224\001\000\000\220\001\000\000\224\002\000\000\224\003\000\001\004\002\000\000p\001\000\000x\001\000\000t\001\000\000@\001\000\000H\001\000\000D\001\000\000P\001\000\000L\001\000\000<\001\000\000x\002\000\001,\001\000\001L\001\000\001\\\001\000\001\\\002\000\001\\\003\000\001\\\004\000\001\\\005\000\001\\\006\000\001\\\007\000\001\\\b\000\000\180\001\000\000\184\001\000\001\\\t\000\001\\\n\000\001X\001\000\001X\002\000\001X\003\000\001X\004\000\001X\005\000\001X\006\000\001X\007\000\001X\b\000\001<\001\000\000\004\001\000\001\020\001\000\000\004\002\000\001\012\001\000\001\b\001\000\000\208\001\000\001\020\001\000\000\208\002\000\001\020\002\000\000\196\001\000\000\196\002\000\0010\001\000\0014\001\000\001H\001\000\001D\001\000\0018\001\000\000\196\003\000\001@\001\000\001T\001\000\001P\001\000\000\192\001\000\001\020\001\000\000\204\001\000\000\200\001\000\000\204\002\000\001\020\001\000\000\204\003\000\000\204\004\000\000\192\002\000\000\208\003\000\000\208\004\000\000\012\001\000\001\020\001\000\000\020\001\000\000\016\001\000\000\020\002\000\001\020\001\000\000\020\003\000\000\020\004\000\000\012\002\000\000\004\003\000\000\004\004\000\000x\003\000\000`\001\000\000l\001\000\000T\001\000\000l\002\000\000X\001\000\000l\003\000\000\\\001\000\000\\\002\000\000\\\003\000\000h\001\000\000\\\001\000\000|\002\000\000|\003\000\000d\002\000\000\128\002\000\001\020\001\000\000\128\003\000\000\128\004\000\001\020\001\000\0008\001\000\000\236\001\000\000\160\001\000\000\160\002\000\000\252\001\000\000\136\001\000\000\132\001\000\000\136\002\000\000\132\002\000\000\136\003\000\000\136\004\000\000\132\003\000\000\132\004\000\0008\002\000\001(\001\000\001\028\001\000\0004\001\000\0000\001\000\0004\002\000\001\024\001\000\0004\003\000\001\028\002\000\000\024\001\000\000(\001\000\000 \001\000\000\028\001\000\000$\001\000\000\024\002\000\000\024\003\000\001 \001\000\000\168\001\000\000\172\001\000\000\176\001\000\000\164\001\000\001(\002\000\000\128\005\000\000\128\006\000\000\216\001\000\001\020\001\000\000\216\002\000\000\216\003\000\000\216\004\000\000\216\005\000\000\128\007\000\000\144\001\000\000\144\002\000\000\144\003\000\000\148\001\000\000\140\002\000\000\140\003\000\000\156\001\000\001\020\001\000\000\156\002\000\000\156\003\000\000\000\001"
    
    let[@inline] lr0_items_data =
      fun i ->
        MenhirLib.PackedIntArray.get32 lr0_items_data i
    
    let lr0_items_entry =
      "\000\001\003\005\006\007\b\t\n\011\012\r\014\015\016\018\019\020\021\022\024\025\026\027\028\029\030\031 !\"#$%&'()*+,-./012345679:;<>?@ABCDEFGHIJKNOQRSTUVYZ\\]^_`abdefhijlmnoprsuwx{}~\127\128\129\130\131\134\135\136\137\138\139\140\141\142\143\144\145\146\147\148\149\150\151\152\153\154\156\157\158\159\160\161\162\163\164\165\166\167\169\170\171"
    
    let[@inline] lr0_items_entry =
      fun i ->
        MenhirLib.PackedIntArray.get8 lr0_items_entry i
    
    let[@inline] lr0_items =
      fun i ->
        MenhirLib.LinearizedArray.read_row_via lr0_items_data lr0_items_entry i
    
    let nullable =
      "$* \006`"
    
    let[@inline] nullable =
      fun i ->
        MenhirLib.PackedIntArray.get1 nullable i
    
    let first =
      "E\138\019\b\"\006b\007\b\162\132\024\1280\002!\006 \012\000\136\004\002\000\000\000\001\000\128\000\000\000@ \000\000\000\000\000\000\002\000A\136\003\000\"\016b\000\192\b\128\000\000\000@\000\000\000 \000\000\004\002\000\000\016\016b\000\192\b\132\024\1280\002 \000\000\016\128\000A\136\003\000\"\000\000\000\128\000\004\024\1290\002!\006 L\000\136E\138\019\b\"\000\000\000\000\b\004\000\000\000\000\000\000\000\128\002\b\000\004 \000\130\000\001\b\000 \128\000B\000\b \000\016\128\002\b\000\001\192\208\000\017b\128\192\b\128@ \000\000\000\128\000\000\001\005A\136\003\000\"\001\000\128\000\004\001\152\129\194(\160\000\000@\000\000"
    
    let[@inline] first =
      fun i ->
        MenhirLib.PackedIntArray.get1 first i
    
    let[@inline] first =
      fun i j ->
        first (42 * i + j)
    
  end) (ET) (TI)
  
end

let document =
  fun lexer lexbuf : ((Statement.t Node.t list)) ->
    Obj.magic (MenhirInterpreter.entry `Legacy 0 lexer lexbuf)

module Incremental = struct
  
  let document =
    fun initial_position : ((Statement.t Node.t list) MenhirInterpreter.checkpoint) ->
      Obj.magic (MenhirInterpreter.start 0 initial_position)
  
end
