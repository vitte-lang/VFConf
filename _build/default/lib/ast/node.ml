(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/node.ml
 *
 * Generic source-located AST node infrastructure.
 *)

(* ---------------------------------------------------------- *)
(* Source position                                            *)
(* ---------------------------------------------------------- *)

type position = {
  offset : int;
  line : int;
  column : int;
}

let position
    ?(offset = 0)
    ?(line = 1)
    ?(column = 1)
    () =
  {
    offset;
    line;
    column;
  }

let dummy_position =
  {
    offset = 0;
    line = 1;
    column = 1;
  }

(* ---------------------------------------------------------- *)
(* Source span                                                *)
(* ---------------------------------------------------------- *)

type span = {
  filename : string;
  start_pos : position;
  end_pos : position;
}

let span
    ?(filename = "")
    start_pos
    end_pos =
  {
    filename;
    start_pos;
    end_pos;
  }

let dummy_span =
  {
    filename = "";
    start_pos = dummy_position;
    end_pos = dummy_position;
  }

(* ---------------------------------------------------------- *)
(* Generic AST node                                           *)
(* ---------------------------------------------------------- *)

type 'a t = {
  value : 'a;
  span : span;
}

let make
    ?(span = dummy_span)
    value =
  {
    value;
    span;
  }

let located span value =
  {
    value;
    span;
  }

let dummy value =
  {
    value;
    span = dummy_span;
  }

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let value node =
  node.value

let span_of node =
  node.span

let filename node =
  node.span.filename

let start_position node =
  node.span.start_pos

let end_position node =
  node.span.end_pos

(* ---------------------------------------------------------- *)
(* Functional helpers                                         *)
(* ---------------------------------------------------------- *)

let map function_ node =
  {
    value = function_ node.value;
    span = node.span;
  }

let map_span function_ node =
  {
    value = node.value;
    span = function_ node.span;
  }

let map_with_span function_ node =
  {
    value = function_ node.span node.value;
    span = node.span;
  }

let replace value node =
  {
    value;
    span = node.span;
  }

let with_span span node =
  {
    value = node.value;
    span;
  }

(* ---------------------------------------------------------- *)
(* Position operations                                        *)
(* ---------------------------------------------------------- *)

let compare_position left right =
  Int.compare left.offset right.offset

let position_before left right =
  compare_position left right < 0

let position_after left right =
  compare_position left right > 0

let position_equal left right =
  compare_position left right = 0

(* ---------------------------------------------------------- *)
(* Span operations                                            *)
(* ---------------------------------------------------------- *)

let span_length span =
  max
    0
    (span.end_pos.offset - span.start_pos.offset)

let span_is_empty span =
  span_length span = 0

let span_contains_position span position =
  position.offset >= span.start_pos.offset
  && position.offset <= span.end_pos.offset

let span_contains_span outer inner =
  inner.start_pos.offset >= outer.start_pos.offset
  && inner.end_pos.offset <= outer.end_pos.offset

let merge_spans left right =
  let start_pos =
    if compare_position left.start_pos right.start_pos <= 0 then
      left.start_pos
    else
      right.start_pos
  in

  let end_pos =
    if compare_position left.end_pos right.end_pos >= 0 then
      left.end_pos
    else
      right.end_pos
  in

  let filename =
    if left.filename <> "" then
      left.filename
    else
      right.filename
  in

  {
    filename;
    start_pos;
    end_pos;
  }

let merge left right =
  merge_spans left.span right.span

(* ---------------------------------------------------------- *)
(* Lexing integration                                         *)
(* ---------------------------------------------------------- *)

let position_of_lexing_position
    (position : Lexing.position) =
  {
    offset = position.pos_cnum;
    line = position.pos_lnum;
    column =
      position.pos_cnum
      - position.pos_bol
      + 1;
  }

let span_of_lexing_positions
    (start_position : Lexing.position)
    (end_position : Lexing.position) =
  {
    filename = start_position.pos_fname;
    start_pos =
      position_of_lexing_position
        start_position;
    end_pos =
      position_of_lexing_position
        end_position;
  }

let of_lexbuf value lexbuf =
  let start_position =
    Lexing.lexeme_start_p lexbuf
  in

  let end_position =
    Lexing.lexeme_end_p lexbuf
  in

  {
    value;
    span =
      span_of_lexing_positions
        start_position
        end_position;
  }

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_position formatter position =
  Format.fprintf
    formatter
    "%d:%d"
    position.line
    position.column

let pp_span formatter span =
  if span.filename = "" then
    Format.fprintf
      formatter
      "%a-%a"
      pp_position
      span.start_pos
      pp_position
      span.end_pos
  else
    Format.fprintf
      formatter
      "%s:%a-%a"
      span.filename
      pp_position
      span.start_pos
      pp_position
      span.end_pos

let pp
    pp_value
    formatter
    node =
  Format.fprintf
    formatter
    "@[<2>{ value = %a;@ span = %a }@]"
    pp_value
    node.value
    pp_span
    node.span

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

let to_string
    value_to_string
    node =
  Printf.sprintf
    "%s@%s:%d:%d-%d:%d"
    (value_to_string node.value)
    node.span.filename
    node.span.start_pos.line
    node.span.start_pos.column
    node.span.end_pos.line
    node.span.end_pos.column

(* ---------------------------------------------------------- *)
(* Equality                                                   *)
(* ---------------------------------------------------------- *)

let equal_position left right =
  left.offset = right.offset
  && left.line = right.line
  && left.column = right.column

let equal_span left right =
  String.equal left.filename right.filename
  && equal_position left.start_pos right.start_pos
  && equal_position left.end_pos right.end_pos

let equal equal_value left right =
  equal_value left.value right.value
  && equal_span left.span right.span

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

let valid_position position =
  position.offset >= 0
  && position.line >= 1
  && position.column >= 1

let valid_span span =
  valid_position span.start_pos
  && valid_position span.end_pos
  && span.start_pos.offset <= span.end_pos.offset

let valid node =
  valid_span node.span