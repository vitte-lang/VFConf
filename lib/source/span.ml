(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/source/span.ml
 *
 * Source span representation and utilities.
 *)

type t = {
  filename : string;
  start_pos : Position.t;
  end_pos : Position.t;
}

type error =
  | Invalid_order of {
      start_pos : Position.t;
      end_pos : Position.t;
    }
  | Different_files of {
      left : string;
      right : string;
    }

exception Span_error of error

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let make
    ?(filename = "")
    start_pos
    end_pos =
  if Position.after start_pos end_pos then
    raise
      (Span_error
         (Invalid_order
            {
              start_pos;
              end_pos;
            }));

  {
    filename;
    start_pos;
    end_pos;
  }

let create =
  make

let dummy =
  {
    filename = "";
    start_pos = Position.dummy;
    end_pos = Position.dummy;
  }

let empty
    ?(filename = "")
    position =
  make
    ~filename
    position
    position

let of_positions =
  make

let of_lexing_positions
    start_pos
    end_pos =
  let filename =
    if start_pos.Lexing.pos_fname <> "" then
      start_pos.Lexing.pos_fname
    else
      end_pos.Lexing.pos_fname
  in

  make
    ~filename
    (Position.of_lexing_position start_pos)
    (Position.of_lexing_position end_pos)

let of_node_span
    (span : Node.span) =
  {
    filename = span.filename;
    start_pos =
      Position.of_node_position
        span.start_pos;
    end_pos =
      Position.of_node_position
        span.end_pos;
  }

let to_node_span span : Node.span =
  {
    filename = span.filename;
    start_pos =
      Position.to_node_position
        span.start_pos;
    end_pos =
      Position.to_node_position
        span.end_pos;
  }

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let filename span =
  span.filename

let start_position span =
  span.start_pos

let end_position span =
  span.end_pos

let start_offset span =
  Position.offset
    span.start_pos

let end_offset span =
  Position.offset
    span.end_pos

let start_line span =
  Position.line
    span.start_pos

let end_line span =
  Position.line
    span.end_pos

let start_column span =
  Position.column
    span.start_pos

let end_column span =
  Position.column
    span.end_pos

(* ---------------------------------------------------------- *)
(* Properties                                                 *)
(* ---------------------------------------------------------- *)

let length span =
  end_offset span
  - start_offset span

let is_empty span =
  length span = 0

let is_multiline span =
  start_line span
  <> end_line span

let line_count span =
  end_line span
  - start_line span
  + 1

let is_dummy span =
  String.equal span.filename ""
  && Position.equal
       span.start_pos
       Position.dummy
  && Position.equal
       span.end_pos
       Position.dummy

(* ---------------------------------------------------------- *)
(* Comparison                                                 *)
(* ---------------------------------------------------------- *)

let equal left right =
  String.equal
    left.filename
    right.filename
  && Position.equal
       left.start_pos
       right.start_pos
  && Position.equal
       left.end_pos
       right.end_pos

let compare left right =
  let filename_comparison =
    String.compare
      left.filename
      right.filename
  in

  if filename_comparison <> 0 then
    filename_comparison
  else
    let start_comparison =
      Position.compare
        left.start_pos
        right.start_pos
    in

    if start_comparison <> 0 then
      start_comparison
    else
      Position.compare
        left.end_pos
        right.end_pos

let same_file left right =
  String.equal
    left.filename
    right.filename

let before left right =
  same_file left right
  && Position.before_or_equal
       left.end_pos
       right.start_pos

let after left right =
  same_file left right
  && Position.after_or_equal
       left.start_pos
       right.end_pos

(* ---------------------------------------------------------- *)
(* Containment                                                *)
(* ---------------------------------------------------------- *)

let contains_position span position =
  Position.before_or_equal
    span.start_pos
    position
  && Position.after_or_equal
       span.end_pos
       position

let contains_offset span offset =
  offset >= start_offset span
  && offset <= end_offset span

let contains_span outer inner =
  same_file outer inner
  && Position.before_or_equal
       outer.start_pos
       inner.start_pos
  && Position.after_or_equal
       outer.end_pos
       inner.end_pos

let overlaps left right =
  same_file left right
  && not
       (Position.before
          left.end_pos
          right.start_pos
        || Position.after
             left.start_pos
             right.end_pos)

let intersects =
  overlaps

(* ---------------------------------------------------------- *)
(* Merge / intersection                                       *)
(* ---------------------------------------------------------- *)

let require_same_file left right =
  if not (same_file left right) then
    raise
      (Span_error
         (Different_files
            {
              left = left.filename;
              right = right.filename;
            }))

let merge left right =
  require_same_file left right;

  make
    ~filename:left.filename
    (Position.min
       left.start_pos
       right.start_pos)
    (Position.max
       left.end_pos
       right.end_pos)

let union =
  merge

let intersection left right =
  require_same_file left right;

  let start_pos =
    Position.max
      left.start_pos
      right.start_pos
  in

  let end_pos =
    Position.min
      left.end_pos
      right.end_pos
  in

  if Position.after start_pos end_pos then
    None
  else
    Some
      (make
         ~filename:left.filename
         start_pos
         end_pos)

let between left right =
  require_same_file left right;

  if Position.before_or_equal left.end_pos right.start_pos then
    make
      ~filename:left.filename
      left.end_pos
      right.start_pos
  else if Position.before_or_equal right.end_pos left.start_pos then
    make
      ~filename:left.filename
      right.end_pos
      left.start_pos
  else
    empty
      ~filename:left.filename
      (Position.max
         left.start_pos
         right.start_pos)

(* ---------------------------------------------------------- *)
(* Modification                                               *)
(* ---------------------------------------------------------- *)

let with_filename filename span =
  {
    span with
    filename;
  }

let with_start start_pos span =
  make
    ~filename:span.filename
    start_pos
    span.end_pos

let with_end end_pos span =
  make
    ~filename:span.filename
    span.start_pos
    end_pos

let map_positions function_ span =
  make
    ~filename:span.filename
    (function_ span.start_pos)
    (function_ span.end_pos)

(* ---------------------------------------------------------- *)
(* Source integration                                         *)
(* ---------------------------------------------------------- *)

let of_source_offsets
    source
    start_offset
    end_offset =
  Source.node_span
    source
    start_offset
    end_offset
  |> of_node_span

let full_source source =
  Source.full_span source
  |> of_node_span

let slice source span =
  if
    span.filename <> ""
    && Source.filename source <> ""
    && not
         (String.equal
            span.filename
            (Source.filename source))
  then
    raise
      (Span_error
         (Different_files
            {
              left = span.filename;
              right = Source.filename source;
            }));

  Source.slice
    source
    (start_offset span)
    (end_offset span)

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

let is_valid span =
  Position.is_valid span.start_pos
  && Position.is_valid span.end_pos
  && Position.before_or_equal
       span.start_pos
       span.end_pos

let validate span =
  if Position.after span.start_pos span.end_pos then
    Error
      (Invalid_order
         {
           start_pos = span.start_pos;
           end_pos = span.end_pos;
         })
  else
    Ok ()

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let to_string span =
  let location =
    if is_multiline span then
      Printf.sprintf
        "%d:%d-%d:%d"
        (start_line span)
        (start_column span)
        (end_line span)
        (end_column span)
    else
      Printf.sprintf
        "%d:%d-%d"
        (start_line span)
        (start_column span)
        (end_column span)
  in

  if String.equal span.filename "" then
    location
  else
    Printf.sprintf
      "%s:%s"
      span.filename
      location

let to_detailed_string span =
  Printf.sprintf
    "%s [%s -> %s]"
    (if String.equal span.filename "" then
       "<unknown>"
     else
       span.filename)
    (Position.to_detailed_string
       span.start_pos)
    (Position.to_detailed_string
       span.end_pos)

let string_of_error = function
  | Invalid_order
      {
        start_pos;
        end_pos;
      } ->
      Printf.sprintf
        "invalid source span: start position %s is after end position %s"
        (Position.to_detailed_string start_pos)
        (Position.to_detailed_string end_pos)

  | Different_files
      {
        left;
        right;
      } ->
      Printf.sprintf
        "cannot combine source spans from different files (%S and %S)"
        left
        right

let pp formatter span =
  Format.pp_print_string
    formatter
    (to_string span)

let pp_detailed formatter span =
  Format.pp_print_string
    formatter
    (to_detailed_string span)

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)