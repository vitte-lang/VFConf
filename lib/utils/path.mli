(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/utils/path.mli
 *
 * Public interface for portable path manipulation utilities.
 *)

type t = string

type error =
  | Empty_path
  | Invalid_path of string
  | Outside_root of {
      root : string;
      path : string;
    }

exception Path_error of error

val separator :
  string

val vfconf_extension :
  string

(* ---------------------------------------------------------- *)
(* Basic properties                                           *)
(* ---------------------------------------------------------- *)

val is_empty :
  t ->
  bool

val is_absolute :
  t ->
  bool

val is_relative :
  t ->
  bool

val basename :
  t ->
  string

val dirname :
  t ->
  string

val concat :
  t ->
  t ->
  t

val join :
  t list ->
  t

val parent :
  t ->
  t option

(* ---------------------------------------------------------- *)
(* String helpers                                             *)
(* ---------------------------------------------------------- *)

val has_prefix :
  string ->
  string ->
  bool

val has_suffix :
  string ->
  string ->
  bool

(* ---------------------------------------------------------- *)
(* Components                                                 *)
(* ---------------------------------------------------------- *)

val split :
  t ->
  string list

val components :
  t ->
  string list

val component_count :
  t ->
  int

(* ---------------------------------------------------------- *)
(* Normalization                                              *)
(* ---------------------------------------------------------- *)

val normalize_components :
  string list ->
  string list

val normalize :
  t ->
  t

val canonicalize :
  t ->
  t

val absolute :
  t ->
  t

(* ---------------------------------------------------------- *)
(* Extension                                                  *)
(* ---------------------------------------------------------- *)

val extension :
  t ->
  string option

val remove_extension :
  t ->
  t

val replace_extension :
  t ->
  string ->
  t

val has_extension :
  t ->
  string ->
  bool

val is_vfconf :
  t ->
  bool

val remove_vfconf_extension :
  t ->
  t

val with_vfconf_extension :
  t ->
  t

(* ---------------------------------------------------------- *)
(* Relative paths                                             *)
(* ---------------------------------------------------------- *)

val drop_common_prefix :
  string list ->
  string list ->
  string list * string list

val relative :
  from:t ->
  t ->
  t

val resolve :
  base:t ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Root containment                                           *)
(* ---------------------------------------------------------- *)

val components_equal_prefix :
  string list ->
  string list ->
  bool

val is_within :
  root:t ->
  t ->
  bool

val ensure_within :
  root:t ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Filesystem helpers                                         *)
(* ---------------------------------------------------------- *)

val exists :
  t ->
  bool

val is_file :
  t ->
  bool

val is_directory :
  t ->
  bool

val realpath :
  t ->
  t

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

val is_valid :
  t ->
  bool

val validate :
  t ->
  (unit, error) result

val require_valid :
  t ->
  unit

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

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val to_string :
  t ->
  string

val of_string :
  string ->
  t

val string_of_error :
  error ->
  string

val pp :
  Format.formatter ->
  t ->
  unit

val pp_error :
  Format.formatter ->
  error ->
  unit