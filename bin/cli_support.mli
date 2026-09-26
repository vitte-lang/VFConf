open Vfconf

type color_mode = Auto | Always | Never
type output_mode = Human | Json | Editor

type options = {
  color : color_mode;
  output : output_mode;
  quiet : bool;
}

val default_options : options
val parse : string list -> (options * string list, string) result
val read_input : string -> (string * string, string) result
val emit_diagnostics : options -> Diagnostic.t list -> unit
val json_string : string -> string
val color_enabled : options -> Unix.file_descr -> bool
