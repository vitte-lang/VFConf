(** Stable, result-based public API for VFConf consumers.

    Lower-level modules remain available for compatibility in the 0.x series,
    but new integrations should prefer this module. *)

type document = Statement.t Node.t list
type 'a outcome = ('a, Diagnostic.t list) result

val parse : ?filename:string -> string -> document outcome
val validate : document -> Validator.result outcome
val check : ?filename:string -> string -> document outcome
val format : ?options:Formatter.options -> ?filename:string -> string -> string outcome
val load :
  ?security_root:string ->
  ?allow_symlinks:bool ->
  ?maximum_include_depth:int ->
  string ->
  Loader.result outcome
