(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/source/position.mli
 *
 * Public interface for source positions.
 *)

type t = {
  offset : int;
  line : int;
  column : int;
}

val make :
  offset:int ->
  line:int ->
  column:int ->
  t

val zero :
  t

val dummy :
  t

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val offset :
  t ->
  int

val line :
  t ->
  int

val column :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Construction from Lexing                                   *)
(* ---------------------------------------------------------- *)

val of_lexing_position :
  Lexing.position ->
  t

val to_lexing_position :
  ?filename:string ->
  t ->
  Lexing.position

(* ---------------------------------------------------------- *)
(* Comparison                                                 *)
(* ---------------------------------------------------------- *)

val compare :
  t ->
  t ->
  int

val equal :
  t ->
  t ->
  bool

val before :
  t ->
  t ->
  bool

val before_or_equal :
  t ->
  t ->
  bool

val after :
  t ->
  t ->
  bool

val after_or_equal :
  t ->
  t ->
  bool

val min :
  t ->
  t ->
  t

val max :
  t ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Movement                                                   *)
(* ---------------------------------------------------------- *)

val advance_bytes :
  int ->
  t ->
  t

val advance_column :
  t ->
  t

val advance_columns :
  int ->
  t ->
  t

val next_line :
  t ->
  t

val advance_newline :
  ?bytes:int ->
  t ->
  t

val advance_char :
  char ->
  t ->
  t

val advance_string :
  string ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Distance                                                   *)
(* ---------------------------------------------------------- *)

val distance :
  t ->
  t ->
  int

val absolute_distance :
  t ->
  t ->
  int

val same_line :
  t ->
  t ->
  bool

val line_distance :
  t ->
  t ->
  int

val column_distance :
  t ->
  t ->
  int option

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

val is_valid :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Node conversion                                            *)
(* ---------------------------------------------------------- *)

val of_node_position :
  Node.position ->
  t

val to_node_position :
  t ->
  Node.position

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val to_string :
  t ->
  string

val to_detailed_string :
  t ->
  string

val pp :
  Format.formatter ->
  t ->
  unit

val pp_detailed :
  Format.formatter ->
  t ->
  unit