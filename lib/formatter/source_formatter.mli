(** Comment-preserving source formatting. *)

val comments : string -> string list

val format_source :
  ?options:Formatter.options ->
  ?filename:string ->
  string ->
  (string, Diagnostic.t list) result
