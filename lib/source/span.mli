(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/source/span.mli
 *
 * Public interface for source spans.
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

val make :
  ?filename:string ->
  Position.t ->
  Position.t ->
  t

val create :
  ?filename:string ->
  Position.t ->
  Position.t ->
  t

val dummy :
  t

val empty :
  ?filename:string ->
  Position.t ->
  t

val of_positions :
  ?filename:string ->
  Position.t ->
  Position.t ->
  t

val of_lexing_positions :
  Lexing.position ->
  Lexing.position ->
  t

val of_node_span :
  Node.span ->
  t

val to_node_span :
  t ->
  Node.span

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val filename :
  t ->
  string

val start_position :
  t ->
  Position.t

val end_position :
  t ->
  Position.t

val start_offset :
  t ->
  int

val end_offset :
  t ->
  int

val start_line :
  t ->
  int

val end_line :
  t ->
  int

val start_column :
  t ->
  int

val end_column :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Properties                                                 *)
(* ---------------------------------------------------------- *)

val length :
  t ->
  int

val is_empty :
  t ->
  bool

val is_multiline :
  t ->
  bool

val line_count :
  t ->
  int

val is_dummy :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Comparison                                                 *)
(* ---------------------------------------------------------- *)

val equal :
  t ->
  t ->
  bool

val compare :
  t ->
  t ->
  int

val same_file :
  t ->
  t ->
  bool

val before :
  t ->
  t ->
  bool

val after :
  t ->
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Containment                                                *)
(* ---------------------------------------------------------- *)

val contains_position :
  t ->
  Position.t ->
  bool

val contains_offset :
  t ->
  int ->
  bool

val contains_span :
  t ->
  t ->
  bool

val overlaps :
  t ->
  t ->
  bool

val intersects :
  t ->
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Merge / intersection                                       *)
(* ---------------------------------------------------------- *)

val require_same_file :
  t ->
  t ->
  unit

val merge :
  t ->
  t ->
  t

val union :
  t ->
  t ->
  t

val intersection :
  t ->
  t ->
  t option

val between :
  t ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Modification                                               *)
(* ---------------------------------------------------------- *)

val with_filename :
  string ->
  t ->
  t

val with_start :
  Position.t ->
  t ->
  t

val with_end :
  Position.t ->
  t ->
  t

val map_positions :
  (Position.t -> Position.t) ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Source integration                                         *)
(* ---------------------------------------------------------- *)

val of_source_offsets :
  Source.t ->
  int ->
  int ->
  t

val full_source :
  Source.t ->
  t

val slice :
  Source.t ->
  t ->
  string

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

val is_valid :
  t ->
  bool

val validate :
  t ->
  (unit, error) result

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val to_string :
  t ->
  string

val to_detailed_string :
  t ->
  string

val string_of_error :
  error ->
  string

val pp :
  Format.formatter ->
  t ->
  unit

val pp_detailed :
  Format.formatter ->
  t ->
  unit

val pp_error :
  Format.formatter ->
  error ->
  unit