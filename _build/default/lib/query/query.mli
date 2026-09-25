type component =
  | Exact of string
  | Wildcard
  | Recursive

type t = component list

type error =
  | Empty_query
  | Empty_component

exception Query_error of error

val parse :
  string ->
  t

val matches :
  t ->
  Config.path ->
  bool

val select :
  t ->
  Config.t ->
  Config.entry list

val execute :
  string ->
  Config.t ->
  Config.entry list

val string_of_error :
  error ->
  string
