type family =
  | Lexical
  | Syntax
  | Semantic
  | Reference
  | Include
  | Schema
  | Evaluation
  | Configuration
  | Style
  | Compatibility
  | Io
  | Internal

type entry = {
  code : string;
  family : family;
  title : string;
  description : string;
}

val string_of_family :
  family ->
  string

val entries :
  entry list

val find :
  string ->
  entry option

val mem :
  string ->
  bool

val codes :
  unit ->
  string list

val duplicate_codes :
  unit ->
  string list

val validate :
  unit ->
  (unit, string list) result
