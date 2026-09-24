(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/source/position.ml
 *
 * Source position representation and utilities.
 *)

type t = {
  offset : int;
  line : int;
  column : int;
}

let make
    ~offset
    ~line
    ~column =
  if offset < 0 then
    invalid_arg
      "Position.make: offset must be non-negative";

  if line < 1 then
    invalid_arg
      "Position.make: line must be >= 1";

  if column < 1 then
    invalid_arg
      "Position.make: column must be >= 1";

  {
    offset;
    line;
    column;
  }

let zero =
  {
    offset = 0;
    line = 1;
    column = 1;
  }

let dummy =
  zero

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let offset position =
  position.offset

let line position =
  position.line

let column position =
  position.column

(* ---------------------------------------------------------- *)
(* Construction from Lexing                                   *)
(* ---------------------------------------------------------- *)

let of_lexing_position position =
  {
    offset = position.Lexing.pos_cnum;
    line = position.Lexing.pos_lnum;
    column =
      position.Lexing.pos_cnum
      - position.Lexing.pos_bol
      + 1;
  }

let to_lexing_position
    ?(filename = "")
    position =
  {
    Lexing.pos_fname = filename;
    pos_lnum = position.line;
    pos_bol =
      position.offset
      - position.column
      + 1;
    pos_cnum = position.offset;
  }

(* ---------------------------------------------------------- *)
(* Comparison                                                 *)
(* ---------------------------------------------------------- *)

let compare left right =
  Int.compare
    left.offset
    right.offset

let equal left right =
  left.offset = right.offset
  && left.line = right.line
  && left.column = right.column

let before left right =
  compare left right < 0

let before_or_equal left right =
  compare left right <= 0

let after left right =
  compare left right > 0

let after_or_equal left right =
  compare left right >= 0

let min left right =
  if before_or_equal left right then
    left
  else
    right

let max left right =
  if after_or_equal left right then
    left
  else
    right

(* ---------------------------------------------------------- *)
(* Movement                                                   *)
(* ---------------------------------------------------------- *)

let advance_bytes count position =
  if count < 0 then
    invalid_arg
      "Position.advance_bytes: count must be non-negative";

  {
    position with
    offset = position.offset + count;
    column = position.column + count;
  }

let advance_column position =
  advance_bytes
    1
    position

let advance_columns count position =
  advance_bytes
    count
    position

let next_line position =
  {
    offset = position.offset + 1;
    line = position.line + 1;
    column = 1;
  }

let advance_newline
    ?(bytes = 1)
    position =
  if bytes <= 0 then
    invalid_arg
      "Position.advance_newline: bytes must be positive";

  {
    offset = position.offset + bytes;
    line = position.line + 1;
    column = 1;
  }

let advance_char character position =
  match character with
  | '\n' ->
      advance_newline position

  | _ ->
      advance_column position

let advance_string string position =
  let length =
    String.length string
  in

  let rec loop index position =
    if index >= length then
      position
    else
      match string.[index] with
      | '\r'
        when index + 1 < length
             && string.[index + 1] = '\n' ->
          loop
            (index + 2)
            (advance_newline
               ~bytes:2
               position)

      | '\r'
      | '\n' ->
          loop
            (index + 1)
            (advance_newline position)

      | _ ->
          loop
            (index + 1)
            (advance_column position)
  in

  loop
    0
    position

(* ---------------------------------------------------------- *)
(* Distance                                                   *)
(* ---------------------------------------------------------- *)

let distance left right =
  right.offset - left.offset

let absolute_distance left right =
  Int.abs
    (distance left right)

let same_line left right =
  left.line = right.line

let line_distance left right =
  right.line - left.line

let column_distance left right =
  if same_line left right then
    Some
      (right.column - left.column)
  else
    None

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

let is_valid position =
  position.offset >= 0
  && position.line >= 1
  && position.column >= 1

(* ---------------------------------------------------------- *)
(* Node conversion                                            *)
(* ---------------------------------------------------------- *)

let of_node_position
    (position : Node.position) =
  {
    offset = position.offset;
    line = position.line;
    column = position.column;
  }

let to_node_position position : Node.position =
  {
    offset = position.offset;
    line = position.line;
    column = position.column;
  }

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let to_string position =
  Printf.sprintf
    "%d:%d"
    position.line
    position.column

let to_detailed_string position =
  Printf.sprintf
    "%d:%d@%d"
    position.line
    position.column
    position.offset

let pp formatter position =
  Format.pp_print_string
    formatter
    (to_string position)

let pp_detailed formatter position =
  Format.pp_print_string
    formatter
    (to_detailed_string position)