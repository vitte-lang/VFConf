(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/include.mli
 *
 * Public interface for VFConf include resolution,
 * validation, cycle detection and canonical diagnostics.
 *)

type path = string

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

type error =
  | Empty_path
  | Invalid_extension of path
  | File_not_found of path
  | Is_directory of path
  | Include_cycle of path list
  | Maximum_depth_exceeded of {
      maximum : int;
      path : path;
    }
  | Io_error of {
      path : path;
      message : string;
    }

exception Include_error of error

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

type context = {
  root : path;
  stack : path list;
  maximum_depth : int;
}

val default_maximum_depth : int

(* ---------------------------------------------------------- *)
(* String helpers                                             *)
(* ---------------------------------------------------------- *)

val has_suffix :
  string ->
  string ->
  bool

val is_vfconf_file :
  path ->
  bool

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

val is_absolute :
  path ->
  bool

val dirname :
  path ->
  path

val basename :
  path ->
  path

val concat :
  path ->
  path ->
  path

val normalize_components :
  path ->
  path

val normalize :
  path ->
  path

val absolute_path :
  path ->
  path

val canonicalize :
  path ->
  path

(* ---------------------------------------------------------- *)
(* Filesystem validation                                      *)
(* ---------------------------------------------------------- *)

val validate_extension :
  path ->
  unit

val validate_file :
  path ->
  unit

(* ---------------------------------------------------------- *)
(* Context construction                                       *)
(* ---------------------------------------------------------- *)

val create_context :
  ?maximum_depth:int ->
  path ->
  context

val empty_context :
  ?maximum_depth:int ->
  unit ->
  context

(* ---------------------------------------------------------- *)
(* Context inspection                                         *)
(* ---------------------------------------------------------- *)

val depth :
  context ->
  int

val current :
  context ->
  path option

val root :
  context ->
  path

val stack :
  context ->
  path list

val maximum_depth :
  context ->
  int

val contains :
  path ->
  context ->
  bool

(* ---------------------------------------------------------- *)
(* Include resolution                                         *)
(* ---------------------------------------------------------- *)

val base_directory :
  context ->
  path

val resolve :
  context ->
  path ->
  path

val resolve_from_file :
  path ->
  path ->
  path

(* ---------------------------------------------------------- *)
(* Cycle detection                                            *)
(* ---------------------------------------------------------- *)

val cycle_for :
  path ->
  context ->
  path list option

val check_cycle :
  path ->
  context ->
  unit

(* ---------------------------------------------------------- *)
(* Stack management                                           *)
(* ---------------------------------------------------------- *)

val push :
  path ->
  context ->
  context

val pop :
  context ->
  context

val enter :
  context ->
  path ->
  path * context

(* ---------------------------------------------------------- *)
(* Scoped include execution                                   *)
(* ---------------------------------------------------------- *)

val with_include :
  context ->
  path ->
  (context -> path -> 'a) ->
  'a

(* ---------------------------------------------------------- *)
(* File reading                                               *)
(* ---------------------------------------------------------- *)

val read_file :
  path ->
  string

val resolve_and_read :
  context ->
  path ->
  path * string

(* ---------------------------------------------------------- *)
(* Canonical diagnostics                                      *)
(* ---------------------------------------------------------- *)

val diagnostic_of_error :
  error ->
  Diagnostic.t

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

val string_of_cycle :
  path list ->
  string

val string_of_error :
  error ->
  string

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_error :
  Format.formatter ->
  error ->
  unit

val pp_context :
  Format.formatter ->
  context ->
  unit