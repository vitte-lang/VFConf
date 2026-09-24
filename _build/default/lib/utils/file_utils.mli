(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/utils/file_utils.mli
 *
 * Public interface for portable filesystem and file I/O utilities.
 *)

type error =
  | Not_found of string
  | Not_a_file of string
  | Not_a_directory of string
  | Already_exists of string
  | Permission_denied of string
  | Io_error of {
      path : string;
      message : string;
    }

exception File_error of error

(* ---------------------------------------------------------- *)
(* Error handling                                             *)
(* ---------------------------------------------------------- *)

val classify_sys_error :
  string ->
  string ->
  error

val protect_sys_error :
  string ->
  (unit -> 'a) ->
  'a

(* ---------------------------------------------------------- *)
(* Existence and kind                                         *)
(* ---------------------------------------------------------- *)

val exists :
  string ->
  bool

val stat_opt :
  string ->
  Unix.stats option

val is_file :
  string ->
  bool

val is_directory :
  string ->
  bool

val is_symlink :
  string ->
  bool

val require_exists :
  string ->
  unit

val require_file :
  string ->
  unit

val require_directory :
  string ->
  unit

(* ---------------------------------------------------------- *)
(* File reading                                               *)
(* ---------------------------------------------------------- *)

val read_all :
  in_channel ->
  string

val with_input_file :
  string ->
  (in_channel -> 'a) ->
  'a

val read_file :
  string ->
  string

val read_lines :
  string ->
  string list

(* ---------------------------------------------------------- *)
(* File writing                                               *)
(* ---------------------------------------------------------- *)

val ensure_parent_directory :
  string ->
  unit

val with_output_file :
  ?append:bool ->
  string ->
  (out_channel -> 'a) ->
  'a

val write_file :
  string ->
  string ->
  unit

val append_file :
  string ->
  string ->
  unit

val write_lines :
  string ->
  string list ->
  unit

(* ---------------------------------------------------------- *)
(* Atomic writing                                             *)
(* ---------------------------------------------------------- *)

val temporary_path :
  string ->
  string

val write_file_atomic :
  string ->
  string ->
  unit

(* ---------------------------------------------------------- *)
(* Directories                                                *)
(* ---------------------------------------------------------- *)

val create_directory :
  ?permissions:int ->
  string ->
  unit

val create_directories :
  ?permissions:int ->
  string ->
  unit

val list_directory :
  string ->
  string list

val list_directory_paths :
  string ->
  string list

val list_files :
  string ->
  string list

val list_directories :
  string ->
  string list

(* ---------------------------------------------------------- *)
(* Recursive traversal                                        *)
(* ---------------------------------------------------------- *)

val walk_files :
  string ->
  string list

val find_files :
  ?recursive:bool ->
  (string -> bool) ->
  string ->
  string list

(* ---------------------------------------------------------- *)
(* VFConf helpers                                             *)
(* ---------------------------------------------------------- *)

val vfconf_extension :
  string

val has_suffix :
  string ->
  string ->
  bool

val is_vfconf_file :
  string ->
  bool

val find_vfconf_files :
  ?recursive:bool ->
  string ->
  string list

(* ---------------------------------------------------------- *)
(* Copy / rename / remove                                     *)
(* ---------------------------------------------------------- *)

val copy_file :
  ?overwrite:bool ->
  string ->
  string ->
  unit

val rename :
  ?overwrite:bool ->
  string ->
  string ->
  unit

val remove_file :
  string ->
  unit

val remove_tree :
  string ->
  unit

(* ---------------------------------------------------------- *)
(* Metadata                                                   *)
(* ---------------------------------------------------------- *)

val file_size :
  string ->
  int

val modification_time :
  string ->
  float

val permissions :
  string ->
  int

val set_permissions :
  string ->
  int ->
  unit

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

val string_of_error :
  error ->
  string

val pp_error :
  Format.formatter ->
  error ->
  unit