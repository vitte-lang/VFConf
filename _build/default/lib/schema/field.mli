(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/schema/field.mli
 *
 * Public interface for schema field definitions and validation.
 *)

type value_type =
  | Any
  | String
  | Integer
  | Float
  | Number
  | Boolean
  | Null
  | Array
  | Object
  | Reference
  | Color
  | Duration
  | Size

type constraint_ =
  | Min_integer of int64
  | Max_integer of int64
  | Min_number of float
  | Max_number of float
  | Min_length of int
  | Max_length of int
  | Non_empty
  | One_of of Value.t list
  | Custom of {
      name : string;
      validate : Value.t Node.t -> bool;
      message : string;
    }

type t = {
  name : string;
  value_type : value_type;
  required : bool;
  default : Value.t Node.t option;
  description : string option;
  deprecated : bool;
  replacement : string option;
  constraints : constraint_ list;
}

type validation_error =
  | Missing_required_field of string
  | Type_mismatch of {
      field : string;
      expected : value_type;
      found : value_type;
    }
  | Constraint_violation of {
      field : string;
      constraint_ : constraint_;
      message : string;
    }
  | Invalid_default of string

(* ---------------------------------------------------------- *)
(* Value types                                                *)
(* ---------------------------------------------------------- *)

val string_of_value_type :
  value_type ->
  string

val value_type_of_value :
  Value.t ->
  value_type

val type_matches :
  value_type ->
  Value.t Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

val make :
  ?value_type:value_type ->
  ?required:bool ->
  ?default:Value.t Node.t ->
  ?description:string ->
  ?deprecated:bool ->
  ?replacement:string ->
  ?constraints:constraint_ list ->
  string ->
  t

val required :
  ?value_type:value_type ->
  ?description:string ->
  ?deprecated:bool ->
  ?replacement:string ->
  ?constraints:constraint_ list ->
  string ->
  t

val optional :
  ?value_type:value_type ->
  ?default:Value.t Node.t ->
  ?description:string ->
  ?deprecated:bool ->
  ?replacement:string ->
  ?constraints:constraint_ list ->
  string ->
  t

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val name :
  t ->
  string

val value_type :
  t ->
  value_type

val is_required :
  t ->
  bool

val is_optional :
  t ->
  bool

val default :
  t ->
  Value.t Node.t option

val description :
  t ->
  string option

val is_deprecated :
  t ->
  bool

val replacement :
  t ->
  string option

val constraints :
  t ->
  constraint_ list

val has_default :
  t ->
  bool

val has_constraints :
  t ->
  bool

(* ---------------------------------------------------------- *)
(* Constraint helpers                                         *)
(* ---------------------------------------------------------- *)

val constraint_name :
  constraint_ ->
  string

val length_of_value :
  Value.t ->
  int option

val numeric_value :
  Value.t ->
  float option

val constraint_message :
  constraint_ ->
  string

val validate_constraint :
  constraint_ ->
  Value.t Node.t ->
  bool

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

val validate_value :
  t ->
  Value.t Node.t ->
  validation_error list

val validate_default :
  t ->
  validation_error list

val validate_presence :
  t ->
  Value.t Node.t option ->
  validation_error list

val validate :
  t ->
  Value.t Node.t option ->
  validation_error list

val is_valid :
  t ->
  Value.t Node.t option ->
  bool

(* ---------------------------------------------------------- *)
(* Defaults                                                   *)
(* ---------------------------------------------------------- *)

val apply_default :
  t ->
  Value.t Node.t option ->
  Value.t Node.t option

(* ---------------------------------------------------------- *)
(* Mutation helpers                                           *)
(* ---------------------------------------------------------- *)

val with_type :
  value_type ->
  t ->
  t

val with_required :
  bool ->
  t ->
  t

val with_default :
  Value.t Node.t ->
  t ->
  t

val without_default :
  t ->
  t

val with_description :
  string ->
  t ->
  t

val with_deprecated :
  bool ->
  t ->
  t

val with_replacement :
  string ->
  t ->
  t

val add_constraint :
  constraint_ ->
  t ->
  t

val add_constraints :
  constraint_ list ->
  t ->
  t

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

val diagnostic_of_validation_error :
  ?span:Node.span ->
  validation_error ->
  Diagnostic.t

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

val string_of_validation_error :
  validation_error ->
  string

val pp_value_type :
  Format.formatter ->
  value_type ->
  unit

val pp_validation_error :
  Format.formatter ->
  validation_error ->
  unit

val pp :
  Format.formatter ->
  t ->
  unit