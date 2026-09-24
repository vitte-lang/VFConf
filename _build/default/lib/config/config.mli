(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/config.mli
 *
 * Public interface for loaded VFConf configurations.
 *)

module String_map : Map.S with type key = string

type path = string list

(* ---------------------------------------------------------- *)
(* Configuration entries                                      *)
(* ---------------------------------------------------------- *)

type entry = {
  path : path;
  value : Value.t Node.t;
  span : Node.span;
}

(* ---------------------------------------------------------- *)
(* Configuration                                              *)
(* ---------------------------------------------------------- *)

type t = {
  filename : string option;
  entries : entry String_map.t;
}

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

type error =
  | Duplicate_key of path
  | Missing_key of path
  | Invalid_path of path

exception Config_error of error

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

val path_separator : string

val string_of_path :
  path ->
  string

val path_of_string :
  string ->
  path

val valid_path :
  path ->
  bool

val normalize_path :
  path ->
  path

val key_of_path :
  path ->
  string

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val empty :
  ?filename:string ->
  unit ->
  t

val is_empty :
  t ->
  bool

val length :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Entry construction                                         *)
(* ---------------------------------------------------------- *)

val entry :
  ?span:Node.span ->
  path ->
  Value.t Node.t ->
  entry

(* ---------------------------------------------------------- *)
(* Lookup                                                     *)
(* ---------------------------------------------------------- *)

val find_entry_opt :
  path ->
  t ->
  entry option

val find_opt :
  path ->
  t ->
  Value.t Node.t option

val find_value_opt :
  path ->
  t ->
  Value.t option

val mem :
  path ->
  t ->
  bool

val find_entry :
  path ->
  t ->
  entry

val find :
  path ->
  t ->
  Value.t Node.t

val find_value :
  path ->
  t ->
  Value.t

(* ---------------------------------------------------------- *)
(* Modification                                               *)
(* ---------------------------------------------------------- *)

val add_entry :
  entry ->
  t ->
  t

val add :
  ?span:Node.span ->
  path ->
  Value.t Node.t ->
  t ->
  t

val set_entry :
  entry ->
  t ->
  t

val set :
  ?span:Node.span ->
  path ->
  Value.t Node.t ->
  t ->
  t

val remove :
  path ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Update                                                     *)
(* ---------------------------------------------------------- *)

val update :
  path ->
  (Value.t Node.t option -> Value.t Node.t option) ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Iteration                                                  *)
(* ---------------------------------------------------------- *)

val iter :
  (entry -> unit) ->
  t ->
  unit

val fold :
  ('a -> entry -> 'a) ->
  t ->
  'a ->
  'a

val entries :
  t ->
  entry list

val paths :
  t ->
  path list

val values :
  t ->
  Value.t Node.t list

(* ---------------------------------------------------------- *)
(* Filtering                                                  *)
(* ---------------------------------------------------------- *)

val filter :
  (entry -> bool) ->
  t ->
  t

val filter_map :
  (entry -> entry option) ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Sections                                                   *)
(* ---------------------------------------------------------- *)

val path_has_prefix :
  path ->
  path ->
  bool

val section :
  path ->
  t ->
  t

val direct_section :
  path ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Merge                                                      *)
(* ---------------------------------------------------------- *)

val merge :
  ?override:bool ->
  t ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Conversion                                                 *)
(* ---------------------------------------------------------- *)

val of_entries :
  ?filename:string ->
  entry list ->
  t

val to_entries :
  t ->
  entry list

(* ---------------------------------------------------------- *)
(* Typed access                                               *)
(* ---------------------------------------------------------- *)

val get_string :
  path ->
  t ->
  string option

val get_integer :
  path ->
  t ->
  int64 option

val get_float :
  path ->
  t ->
  float option

val get_boolean :
  path ->
  t ->
  bool option

val get_array :
  path ->
  t ->
  Value.t Node.t list option

val get_object :
  path ->
  t ->
  Value.object_entry list option

val get_reference :
  path ->
  t ->
  Value.reference option

val get_color :
  path ->
  t ->
  Value.color option

val get_duration :
  path ->
  t ->
  (float * Value.duration_unit) option

val get_size :
  path ->
  t ->
  (float * Value.size_unit) option

(* ---------------------------------------------------------- *)
(* Default values                                             *)
(* ---------------------------------------------------------- *)

val get_string_or :
  default:string ->
  path ->
  t ->
  string

val get_integer_or :
  default:int64 ->
  path ->
  t ->
  int64

val get_float_or :
  default:float ->
  path ->
  t ->
  float

val get_boolean_or :
  default:bool ->
  path ->
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_entry :
  Format.formatter ->
  entry ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit

val to_string :
  t ->
  string

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

val string_of_error :
  error ->
  string

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

val dump :
  Format.formatter ->
  t ->
  unit