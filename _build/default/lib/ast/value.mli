(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/value.mli
 *
 * Public interface for canonical VFConf values.
 *)

type path = string list
type reference = path

(* ---------------------------------------------------------- *)
(* Units                                                      *)
(* ---------------------------------------------------------- *)

type duration_unit =
  | Nanosecond
  | Microsecond
  | Millisecond
  | Second
  | Minute
  | Hour

type size_unit =
  | Byte
  | Kilobyte
  | Megabyte
  | Gigabyte
  | Kibibyte
  | Mebibyte
  | Gibibyte

(* ---------------------------------------------------------- *)
(* Colors                                                     *)
(* ---------------------------------------------------------- *)

type color =
  | Hex of string
  | Rgb of {
      red : int;
      green : int;
      blue : int;
    }
  | Rgba of {
      red : int;
      green : int;
      blue : int;
      alpha : float;
    }

(* ---------------------------------------------------------- *)
(* Values                                                     *)
(* ---------------------------------------------------------- *)

type t =
  | String of string
  | Integer of int64
  | Float of float
  | Boolean of bool
  | Null
  | Array of t Node.t list
  | Object of object_entry list
  | Reference of reference
  | Color of color
  | Duration of float * duration_unit
  | Size of float * size_unit

and object_entry = {
  key : path;
  value : t Node.t;
  span : Node.span;
}

(* ---------------------------------------------------------- *)
(* Constructors                                               *)
(* ---------------------------------------------------------- *)

val string :
  string ->
  t

val integer :
  int64 ->
  t

val int :
  int ->
  t

val float :
  float ->
  t

val boolean :
  bool ->
  t

val true_ : t
val false_ : t
val null : t

val array :
  t Node.t list ->
  t

val object_ :
  object_entry list ->
  t

val reference :
  reference ->
  t

val hex :
  string ->
  color

val rgb :
  int ->
  int ->
  int ->
  color

val rgba :
  int ->
  int ->
  int ->
  float ->
  color

val color :
  color ->
  t

val duration :
  float ->
  duration_unit ->
  t

val size :
  float ->
  size_unit ->
  t

val object_entry :
  ?span:Node.span ->
  path ->
  t Node.t ->
  object_entry

(* ---------------------------------------------------------- *)
(* Located constructors                                       *)
(* ---------------------------------------------------------- *)

val located :
  Node.span ->
  t ->
  t Node.t

val located_string :
  Node.span ->
  string ->
  t Node.t

val located_integer :
  Node.span ->
  int64 ->
  t Node.t

val located_float :
  Node.span ->
  float ->
  t Node.t

val located_boolean :
  Node.span ->
  bool ->
  t Node.t

val located_null :
  Node.span ->
  t Node.t

val located_array :
  Node.span ->
  t Node.t list ->
  t Node.t

val located_object :
  Node.span ->
  object_entry list ->
  t Node.t

val located_reference :
  Node.span ->
  reference ->
  t Node.t

val located_color :
  Node.span ->
  color ->
  t Node.t

val located_duration :
  Node.span ->
  float ->
  duration_unit ->
  t Node.t

val located_size :
  Node.span ->
  float ->
  size_unit ->
  t Node.t

(* ---------------------------------------------------------- *)
(* Predicates                                                 *)
(* ---------------------------------------------------------- *)

val is_string : t -> bool
val is_integer : t -> bool
val is_float : t -> bool
val is_number : t -> bool
val is_boolean : t -> bool
val is_null : t -> bool
val is_array : t -> bool
val is_object : t -> bool
val is_reference : t -> bool
val is_color : t -> bool
val is_duration : t -> bool
val is_size : t -> bool

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val as_string :
  t ->
  string option

val as_integer :
  t ->
  int64 option

val as_float :
  t ->
  float option

val as_boolean :
  t ->
  bool option

val as_array :
  t ->
  t Node.t list option

val as_object :
  t ->
  object_entry list option

val as_reference :
  t ->
  reference option

val as_color :
  t ->
  color option

val as_duration :
  t ->
  (float * duration_unit) option

val as_size :
  t ->
  (float * size_unit) option

(* ---------------------------------------------------------- *)
(* Unit conversion                                            *)
(* ---------------------------------------------------------- *)

val string_of_duration_unit :
  duration_unit ->
  string

val string_of_size_unit :
  size_unit ->
  string

val duration_multiplier :
  duration_unit ->
  float

val duration_to_seconds :
  float ->
  duration_unit ->
  float

val size_multiplier :
  size_unit ->
  float

val size_to_bytes :
  float ->
  size_unit ->
  float

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

val string_of_path :
  path ->
  string

(* ---------------------------------------------------------- *)
(* Color validation                                           *)
(* ---------------------------------------------------------- *)

val valid_rgb_component :
  int ->
  bool

val valid_alpha :
  float ->
  bool

val is_hex_digit :
  char ->
  bool

val valid_hex :
  string ->
  bool

val valid_color :
  color ->
  bool

(* ---------------------------------------------------------- *)
(* Equality                                                   *)
(* ---------------------------------------------------------- *)

val equal_duration_unit :
  duration_unit ->
  duration_unit ->
  bool

val equal_size_unit :
  size_unit ->
  size_unit ->
  bool

val equal_color :
  color ->
  color ->
  bool

val equal :
  t ->
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_path :
  Format.formatter ->
  path ->
  unit

val pp_color :
  Format.formatter ->
  color ->
  unit

val escape_string :
  string ->
  string

val pp :
  Format.formatter ->
  t ->
  unit

val to_string :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

val type_name :
  t ->
  string

val dump :
  Format.formatter ->
  int ->
  t ->
  unit