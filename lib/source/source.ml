(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/source/source.ml
 *
 * Source file representation and source text utilities.
 *)

type t = {
  filename : string;
  text : string;
  length : int;
  line_offsets : int array;
}

type error =
  | Invalid_offset of int
  | Invalid_line of int
  | Invalid_position of Position.t
  | Io_error of {
      filename : string;
      message : string;
    }

exception Source_error of error

(* ---------------------------------------------------------- *)
(* Line index                                                 *)
(* ---------------------------------------------------------- *)

let compute_line_offsets text =
  let length =
    String.length text
  in

  let offsets =
    ref [0]
  in

  let index =
    ref 0
  in

  while !index < length do
    match text.[!index] with
    | '\r'
      when !index + 1 < length
           && text.[!index + 1] = '\n' ->
        offsets :=
          (!index + 2) :: !offsets;
        index := !index + 2

    | '\r'
    | '\n' ->
        offsets :=
          (!index + 1) :: !offsets;
        incr index

    | _ ->
        incr index
  done;

  Array.of_list
    (List.rev !offsets)

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let make
    ?(filename = "<memory>")
    text =
  {
    filename;
    text;
    length = String.length text;
    line_offsets =
      compute_line_offsets text;
  }

let empty
    ?(filename = "<memory>")
    () =
  make
    ~filename
    ""

let of_string =
  make

let read_file filename =
  let channel =
    try
      open_in_bin filename
    with
    | Sys_error message ->
        raise
          (Source_error
             (Io_error
                {
                  filename;
                  message;
                }))
  in

  try
    let length =
      in_channel_length channel
    in

    let text =
      really_input_string
        channel
        length
    in

    close_in channel;

    make
      ~filename
      text
  with
  | exn ->
      close_in_noerr channel;

      begin
        match exn with
        | Source_error _ ->
            raise exn

        | Sys_error message ->
            raise
              (Source_error
                 (Io_error
                    {
                      filename;
                      message;
                    }))

        | End_of_file ->
            raise
              (Source_error
                 (Io_error
                    {
                      filename;
                      message =
                        "unexpected end of file while reading source";
                    }))

        | _ ->
            raise exn
      end

let of_file =
  read_file

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let filename source =
  source.filename

let text source =
  source.text

let length source =
  source.length

let is_empty source =
  source.length = 0

let line_count source =
  Array.length
    source.line_offsets

(* ---------------------------------------------------------- *)
(* Offset validation                                          *)
(* ---------------------------------------------------------- *)

let valid_offset source offset =
  offset >= 0
  && offset <= source.length

let check_offset source offset =
  if not (valid_offset source offset) then
    raise
      (Source_error
         (Invalid_offset offset))

let valid_character_offset source offset =
  offset >= 0
  && offset < source.length

let check_character_offset source offset =
  if not (valid_character_offset source offset) then
    raise
      (Source_error
         (Invalid_offset offset))

(* ---------------------------------------------------------- *)
(* Line lookup                                                *)
(* ---------------------------------------------------------- *)

let valid_line source line =
  line >= 1
  && line <= line_count source

let check_line source line =
  if not (valid_line source line) then
    raise
      (Source_error
         (Invalid_line line))

let line_start_offset source line =
  check_line source line;

  source.line_offsets.(line - 1)

let line_end_offset source line =
  check_line source line;

  let start =
    line_start_offset
      source
      line
  in

  let raw_end =
    if line < line_count source then
      source.line_offsets.(line)
    else
      source.length
  in

  if raw_end <= start then
    raw_end
  else
    match source.text.[raw_end - 1] with
    | '\n'
      when raw_end - 2 >= start
           && source.text.[raw_end - 2] = '\r' ->
        raw_end - 2

    | '\n'
    | '\r' ->
        raw_end - 1

    | _ ->
        raw_end

let line_length source line =
  line_end_offset source line
  - line_start_offset source line

let line source line =
  let start =
    line_start_offset
      source
      line
  in

  let finish =
    line_end_offset
      source
      line
  in

  String.sub
    source.text
    start
    (finish - start)

let lines source =
  List.init
    (line_count source)
    (fun index ->
      line source (index + 1))

(* ---------------------------------------------------------- *)
(* Offset -> position                                         *)
(* ---------------------------------------------------------- *)

let line_of_offset source offset =
  check_offset source offset;

  let count =
    line_count source
  in

  let rec search low high =
    if low > high then
      high
    else
      let middle =
        (low + high) / 2
      in

      if source.line_offsets.(middle) <= offset then
        search
          (middle + 1)
          high
      else
        search
          low
          (middle - 1)
  in

  search 0 (count - 1) + 1

let position_of_offset source offset =
  check_offset source offset;

  let line =
    line_of_offset
      source
      offset
  in

  let line_start =
    line_start_offset
      source
      line
  in

  Position.make
    ~offset
    ~line
    ~column:(offset - line_start + 1)

(* ---------------------------------------------------------- *)
(* Position -> offset                                         *)
(* ---------------------------------------------------------- *)

let offset_of_position source position =
  let line =
    Position.line position
  in

  check_line source line;

  let start =
    line_start_offset
      source
      line
  in

  let finish =
    line_end_offset
      source
      line
  in

  let column =
    Position.column position
  in

  if column < 1 then
    raise
      (Source_error
         (Invalid_position position));

  let offset =
    start + column - 1
  in

  if offset > finish then
    raise
      (Source_error
         (Invalid_position position));

  offset

let position_is_valid source position =
  try
    let offset =
      offset_of_position
        source
        position
    in

    offset = Position.offset position
  with
  | Source_error _ ->
      false

(* ---------------------------------------------------------- *)
(* Characters                                                 *)
(* ---------------------------------------------------------- *)

let char_at source offset =
  check_character_offset
    source
    offset;

  source.text.[offset]

let char_at_opt source offset =
  if valid_character_offset source offset then
    Some source.text.[offset]
  else
    None

(* ---------------------------------------------------------- *)
(* Slices                                                     *)
(* ---------------------------------------------------------- *)

let slice source start_offset end_offset =
  check_offset source start_offset;
  check_offset source end_offset;

  if end_offset < start_offset then
    invalid_arg
      "Source.slice: end offset is before start offset";

  String.sub
    source.text
    start_offset
    (end_offset - start_offset)

let slice_positions source start_position end_position =
  let start_offset =
    offset_of_position
      source
      start_position
  in

  let end_offset =
    offset_of_position
      source
      end_position
  in

  slice
    source
    start_offset
    end_offset

let slice_node_span source span =
  if
    span.Node.filename <> ""
    && source.filename <> ""
    && not
         (String.equal
            span.Node.filename
            source.filename)
  then
    invalid_arg
      "Source.slice_node_span: span belongs to another source";

  slice
    source
    span.Node.start_pos.offset
    span.Node.end_pos.offset

(* ---------------------------------------------------------- *)
(* Lexing                                                     *)
(* ---------------------------------------------------------- *)

let lexbuf source =
  let buffer =
    Lexing.from_string
      source.text
  in

  let position =
    {
      Lexing.pos_fname = source.filename;
      pos_lnum = 1;
      pos_bol = 0;
      pos_cnum = 0;
    }
  in

  buffer.Lexing.lex_curr_p <- position;
  buffer.Lexing.lex_start_p <- position;

  buffer

(* ---------------------------------------------------------- *)
(* Node positions                                             *)
(* ---------------------------------------------------------- *)

let node_position_of_offset source offset =
  position_of_offset
    source
    offset
  |> Position.to_node_position

let node_span
    source
    start_offset
    end_offset =
  check_offset source start_offset;
  check_offset source end_offset;

  if end_offset < start_offset then
    invalid_arg
      "Source.node_span: end offset is before start offset";

  {
    Node.filename = source.filename;
    start_pos =
      node_position_of_offset
        source
        start_offset;
    end_pos =
      node_position_of_offset
        source
        end_offset;
  }

let full_span source =
  node_span
    source
    0
    source.length

(* ---------------------------------------------------------- *)
(* Line / column utilities                                    *)
(* ---------------------------------------------------------- *)

let line_and_column source offset =
  let position =
    position_of_offset
      source
      offset
  in

  ( Position.line position,
    Position.column position )

let offset_of_line_column
    source
    ~line
    ~column =
  offset_of_position
    source
    (Position.make
       ~offset:
         (line_start_offset source line
          + column
          - 1)
       ~line
       ~column)

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Invalid_offset offset ->
      Printf.sprintf
        "invalid source offset %d"
        offset

  | Invalid_line line ->
      Printf.sprintf
        "invalid source line %d"
        line

  | Invalid_position position ->
      Printf.sprintf
        "invalid source position %s"
        (Position.to_detailed_string position)

  | Io_error
      {
        filename;
        message;
      } ->
      Printf.sprintf
        "%s: %s"
        filename
        message

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

let pp formatter source =
  Format.fprintf
    formatter
    "@[<hov 2>Source(%S, %d byte%s, %d line%s)@]"
    source.filename
    source.length
    (if source.length = 1 then "" else "s")
    (line_count source)
    (if line_count source = 1 then "" else "s")