(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/merge.mli
 *
 * Public interface for the VFConf configuration merge engine.
 *)

(* ---------------------------------------------------------- *)
(* Merge policies                                             *)
(* ---------------------------------------------------------- *)

type conflict_policy =
  | Keep_left
  | Keep_right
  | Error

type array_policy =
  | Replace_array
  | Append_array
  | Unique_array

type object_policy =
  | Replace_object
  | Merge_object

type options = {
  conflict : conflict_policy;
  arrays : array_policy;
  objects : object_policy;
}

val default_options : options

(* ---------------------------------------------------------- *)
(* Conflicts                                                  *)
(* ---------------------------------------------------------- *)

type conflict = {
  path : Config.path;
  left : Value.t Node.t;
  right : Value.t Node.t;
}

type error =
  | Conflict of conflict
  | Invalid_value_merge of Config.path

exception Merge_error of error

(* ---------------------------------------------------------- *)
(* Value helpers                                              *)
(* ---------------------------------------------------------- *)

val unique_values :
  Value.t Node.t list ->
  Value.t Node.t list

(* ---------------------------------------------------------- *)
(* Object helpers                                             *)
(* ---------------------------------------------------------- *)

val object_key :
  Value.object_entry ->
  string

val find_object_entry :
  string ->
  Value.object_entry list ->
  Value.object_entry option

val remove_object_entry :
  string ->
  Value.object_entry list ->
  Value.object_entry list

(* ---------------------------------------------------------- *)
(* Recursive value merge                                      *)
(* ---------------------------------------------------------- *)

val merge_value :
  ?path:Config.path ->
  options ->
  Value.t Node.t ->
  Value.t Node.t ->
  Value.t Node.t

val resolve_conflict :
  path:Config.path ->
  options ->
  Value.t Node.t ->
  Value.t Node.t ->
  Value.t Node.t

val merge_object_entries :
  path:Config.path ->
  options ->
  Value.object_entry list ->
  Value.object_entry list ->
  Value.object_entry list

(* ---------------------------------------------------------- *)
(* Entry merge                                                *)
(* ---------------------------------------------------------- *)

val merge_entry :
  options ->
  Config.entry ->
  Config.entry ->
  Config.entry

(* ---------------------------------------------------------- *)
(* Configuration merge                                        *)
(* ---------------------------------------------------------- *)

val merge :
  ?options:options ->
  Config.t ->
  Config.t ->
  Config.t

val merge_many :
  ?options:options ->
  Config.t list ->
  Config.t

(* ---------------------------------------------------------- *)
(* Predefined merge strategies                                *)
(* ---------------------------------------------------------- *)

val overlay :
  Config.t ->
  Config.t ->
  Config.t

val preserve :
  Config.t ->
  Config.t ->
  Config.t

val strict :
  Config.t ->
  Config.t ->
  Config.t

val deep :
  Config.t ->
  Config.t ->
  Config.t

val deep_append :
  Config.t ->
  Config.t ->
  Config.t

val deep_unique :
  Config.t ->
  Config.t ->
  Config.t

(* ---------------------------------------------------------- *)
(* Conflict inspection                                        *)
(* ---------------------------------------------------------- *)

val conflicts :
  Config.t ->
  Config.t ->
  conflict list

val has_conflicts :
  Config.t ->
  Config.t ->
  bool

(* ---------------------------------------------------------- *)
(* Difference                                                 *)
(* ---------------------------------------------------------- *)

type difference =
  | Added of Config.entry
  | Removed of Config.entry
  | Changed of {
      path : Config.path;
      before : Config.entry;
      after : Config.entry;
    }

val diff :
  Config.t ->
  Config.t ->
  difference list

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

val string_of_conflict :
  conflict ->
  string

val string_of_error :
  error ->
  string

val pp_conflict :
  Format.formatter ->
  conflict ->
  unit

val pp_error :
  Format.formatter ->
  error ->
  unit

(* ---------------------------------------------------------- *)
(* Difference printing                                        *)
(* ---------------------------------------------------------- *)

val pp_difference :
  Format.formatter ->
  difference ->
  unit

val pp_diff :
  Format.formatter ->
  difference list ->
  unit