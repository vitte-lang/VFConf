(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/utils/string_utils.mli
 *
 * Public interface for general string manipulation utilities.
 *)

(* ---------------------------------------------------------- *)
(* Basic predicates                                           *)
(* ---------------------------------------------------------- *)

val is_empty :
  string ->
  bool

val is_blank :
  string ->
  bool

val equal :
  string ->
  string ->
  bool

val equal_case_insensitive :
  string ->
  string ->
  bool

(* ---------------------------------------------------------- *)
(* Prefix / suffix                                            *)
(* ---------------------------------------------------------- *)

val starts_with :
  prefix:string ->
  string ->
  bool

val ends_with :
  suffix:string ->
  string ->
  bool

val remove_prefix :
  prefix:string ->
  string ->
  string option

val remove_suffix :
  suffix:string ->
  string ->
  string option

val strip_prefix :
  prefix:string ->
  string ->
  string

val strip_suffix :
  suffix:string ->
  string ->
  string

(* ---------------------------------------------------------- *)
(* Whitespace                                                 *)
(* ---------------------------------------------------------- *)

val is_whitespace :
  char ->
  bool

val trim_left :
  string ->
  string

val trim_right :
  string ->
  string

val trim :
  string ->
  string

(* ---------------------------------------------------------- *)
(* Splitting                                                  *)
(* ---------------------------------------------------------- *)

val split_on_char :
  char ->
  string ->
  string list

val split :
  separator:string ->
  string ->
  string list

val split_lines :
  string ->
  string list

val words :
  string ->
  string list

(* ---------------------------------------------------------- *)
(* Joining                                                    *)
(* ---------------------------------------------------------- *)

val join :
  separator:string ->
  string list ->
  string

val join_lines :
  string list ->
  string

(* ---------------------------------------------------------- *)
(* Search                                                     *)
(* ---------------------------------------------------------- *)

val contains_char :
  char ->
  string ->
  bool

val index_opt :
  char ->
  string ->
  int option

val rindex_opt :
  char ->
  string ->
  int option

val contains :
  substring:string ->
  string ->
  bool

val count_char :
  char ->
  string ->
  int

(* ---------------------------------------------------------- *)
(* Replacement                                                *)
(* ---------------------------------------------------------- *)

val replace_char :
  target:char ->
  replacement:char ->
  string ->
  string

val replace_all :
  substring:string ->
  replacement:string ->
  string ->
  string

(* ---------------------------------------------------------- *)
(* Repetition / padding                                       *)
(* ---------------------------------------------------------- *)

val repeat :
  int ->
  string ->
  string

val pad_left :
  length:int ->
  character:char ->
  string ->
  string

val pad_right :
  length:int ->
  character:char ->
  string ->
  string

(* ---------------------------------------------------------- *)
(* Case conversion                                            *)
(* ---------------------------------------------------------- *)

val lowercase :
  string ->
  string

val uppercase :
  string ->
  string

val capitalize :
  string ->
  string

val uncapitalize :
  string ->
  string

(* ---------------------------------------------------------- *)
(* Identifier helpers                                         *)
(* ---------------------------------------------------------- *)

val is_ascii_letter :
  char ->
  bool

val is_ascii_digit :
  char ->
  bool

val is_identifier_start :
  char ->
  bool

val is_identifier_continue :
  char ->
  bool

val is_identifier :
  string ->
  bool

(* ---------------------------------------------------------- *)
(* Escaping                                                   *)
(* ---------------------------------------------------------- *)

val escape :
  string ->
  string

val quote :
  string ->
  string

(* ---------------------------------------------------------- *)
(* Numeric parsing                                            *)
(* ---------------------------------------------------------- *)

val int_opt :
  string ->
  int option

val int64_opt :
  string ->
  int64 option

val float_opt :
  string ->
  float option

(* ---------------------------------------------------------- *)
(* Miscellaneous                                              *)
(* ---------------------------------------------------------- *)

val non_empty :
  string ->
  string option

val default :
  string ->
  string option ->
  string

val map_non_empty :
  (string -> string) ->
  string ->
  string option

val compare :
  string ->
  string ->
  int

val pp :
  Format.formatter ->
  string ->
  unit

val pp_quoted :
  Format.formatter ->
  string ->
  unit