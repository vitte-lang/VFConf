(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/schema/rule.mli
 *
 * Public interface for reusable schema validation rules.
 *)

type severity =
  | Error
  | Warning

type context = {
  config : Config.t;
  path : Config.path option;
}

type violation = {
  rule : string;
  message : string;
  severity : severity;
  path : Config.path option;
  span : Node.span option;
}

type validator =
  context ->
  violation list

type t = {
  name : string;
  description : string option;
  severity : severity;
  validator : validator;
}

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val make :
  ?description:string ->
  ?severity:severity ->
  string ->
  validator ->
  t

val error :
  ?description:string ->
  string ->
  validator ->
  t

val warning :
  ?description:string ->
  string ->
  validator ->
  t

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val name :
  t ->
  string

val description :
  t ->
  string option

val severity :
  t ->
  severity

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

val context :
  ?path:Config.path ->
  Config.t ->
  context

val with_path :
  Config.path ->
  context ->
  context

val clear_path :
  context ->
  context

(* ---------------------------------------------------------- *)
(* Violation construction                                     *)
(* ---------------------------------------------------------- *)

val violation :
  ?path:Config.path ->
  ?span:Node.span ->
  ?severity:severity ->
  rule:string ->
  string ->
  violation

val violation_for_entry :
  ?severity:severity ->
  rule:string ->
  string ->
  Config.entry ->
  violation

(* ---------------------------------------------------------- *)
(* Running rules                                              *)
(* ---------------------------------------------------------- *)

val validate :
  t ->
  context ->
  violation list

val validate_config :
  t ->
  Config.t ->
  violation list

val validate_rules :
  t list ->
  Config.t ->
  violation list

val passes :
  t ->
  context ->
  bool

val passes_config :
  t ->
  Config.t ->
  bool

(* ---------------------------------------------------------- *)
(* Lookup helpers                                             *)
(* ---------------------------------------------------------- *)

val entry :
  context ->
  Config.path ->
  Config.entry option

val value :
  context ->
  Config.path ->
  Value.t Node.t option

val value_raw :
  context ->
  Config.path ->
  Value.t option

val exists :
  context ->
  Config.path ->
  bool

(* ---------------------------------------------------------- *)
(* Basic rules                                                *)
(* ---------------------------------------------------------- *)

val required_path :
  ?severity:severity ->
  Config.path ->
  t

val forbidden_path :
  ?severity:severity ->
  Config.path ->
  t

val deprecated_path :
  ?replacement:Config.path ->
  Config.path ->
  t

(* ---------------------------------------------------------- *)
(* Field rule                                                 *)
(* ---------------------------------------------------------- *)

val field :
  Config.path ->
  Field.t ->
  t

(* ---------------------------------------------------------- *)
(* Dependency rules                                           *)
(* ---------------------------------------------------------- *)

val requires :
  ?severity:severity ->
  Config.path ->
  Config.path ->
  t

val conflicts :
  ?severity:severity ->
  Config.path ->
  Config.path ->
  t

val exactly_one_of :
  ?severity:severity ->
  Config.path list ->
  t

val at_least_one_of :
  ?severity:severity ->
  Config.path list ->
  t

val at_most_one_of :
  ?severity:severity ->
  Config.path list ->
  t

(* ---------------------------------------------------------- *)
(* Conditional rules                                          *)
(* ---------------------------------------------------------- *)

val when_present :
  Config.path ->
  t ->
  t

val unless_present :
  Config.path ->
  t ->
  t

val when_value :
  Config.path ->
  (Value.t Node.t -> bool) ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Custom predicates                                          *)
(* ---------------------------------------------------------- *)

val predicate :
  ?severity:severity ->
  ?description:string ->
  string ->
  (context -> bool) ->
  string ->
  t

val value_predicate :
  ?severity:severity ->
  ?description:string ->
  Config.path ->
  string ->
  (Value.t Node.t -> bool) ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Violation utilities                                        *)
(* ---------------------------------------------------------- *)

val is_error :
  violation ->
  bool

val is_warning :
  violation ->
  bool

val errors :
  violation list ->
  violation list

val warnings :
  violation list ->
  violation list

val has_errors :
  violation list ->
  bool

val has_warnings :
  violation list ->
  bool

val count_errors :
  violation list ->
  int

val count_warnings :
  violation list ->
  int

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val diagnostic_of_violation :
  violation ->
  Diagnostic.t

val diagnostics :
  violation list ->
  Diagnostic.t list

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

val string_of_severity :
  severity ->
  string

val string_of_violation :
  violation ->
  string

val pp_severity :
  Format.formatter ->
  severity ->
  unit

val pp_violation :
  Format.formatter ->
  violation ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit