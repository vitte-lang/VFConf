(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/source/source.mli
 *
 * Public interface for source file representation and utilities.
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

val compute_line_offsets :
  string ->
  int array

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val make :
  ?filename:string ->
  string ->
  t

val empty :
  ?filename:string ->
  unit ->
  t

val of_string :
  ?filename:string ->
  string ->
  t

val read_file :
  string ->
  t

val of_file :
  string ->
  t

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val filename :
  t ->
  string

val text :
  t ->
  string

val length :
  t ->
  int

val is_empty :
  t ->
  bool

val line_count :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Offset validation                                          *)
(* ---------------------------------------------------------- *)

val valid_offset :
  t ->
  int ->
  bool

val check_offset :
  t ->
  int ->
  unit

val valid_character_offset :
  t ->
  int ->
  bool

val check_character_offset :
  t ->
  int ->
  unit

(* ---------------------------------------------------------- *)
(* Line lookup                                                *)
(* ---------------------------------------------------------- *)

val valid_line :
  t ->
  int ->
  bool

val check_line :
  t ->
  int ->
  unit

val line_start_offset :
  t ->
  int ->
  int

val line_end_offset :
  t ->
  int ->
  int

val line_length :
  t ->
  int ->
  int

val line :
  t ->
  int ->
  string

val lines :
  t ->
  string list

(* ---------------------------------------------------------- *)
(* Offset -> position                                         *)
(* ---------------------------------------------------------- *)

val line_of_offset :
  t ->
  int ->
  int

val position_of_offset :
  t ->
  int ->
  Position.t

(* ---------------------------------------------------------- *)
(* Position -> offset                                         *)
(* ---------------------------------------------------------- *)

val offset_of_position :
  t ->
  Position.t ->
  int

val position_is_valid :
  t ->
  Position.t ->
  bool

(* ---------------------------------------------------------- *)
(* Characters                                                 *)
(* ---------------------------------------------------------- *)

val char_at :
  t ->
  int ->
  char

val char_at_opt :
  t ->
  int ->
  char option

(* ---------------------------------------------------------- *)
(* Slices                                                     *)
(* ---------------------------------------------------------- *)

val slice :
  t ->
  int ->
  int ->
  string

val slice_positions :
  t ->
  Position.t ->
  Position.t ->
  string

val slice_node_span :
  t ->
  Node.span ->
  string

(* ---------------------------------------------------------- *)
(* Lexing                                                     *)
(* ---------------------------------------------------------- *)

val lexbuf :
  t ->
  Lexing.lexbuf

(* ---------------------------------------------------------- *)
(* Node positions                                             *)
(* ---------------------------------------------------------- *)

val node_position_of_offset :
  t ->
  int ->
  Node.position

val node_span :
  t ->
  int ->
  int ->
  Node.span

val full_span :
  t ->
  Node.span

(* ---------------------------------------------------------- *)
(* Line / column utilities                                    *)
(* ---------------------------------------------------------- *)

val line_and_column :
  t ->
  int ->
  int * int

val offset_of_line_column :
  t ->
  line:int ->
  column:int ->
  int

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val string_of_error :
  error ->
  string

val pp_error :
  Format.formatter ->
  error ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit