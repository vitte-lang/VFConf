(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/schema/field.ml
 *
 * Schema field definitions and validation helpers.
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

let string_of_value_type = function
  | Any ->
      "any"
  | String ->
      "string"
  | Integer ->
      "integer"
  | Float ->
      "float"
  | Number ->
      "number"
  | Boolean ->
      "boolean"
  | Null ->
      "null"
  | Array ->
      "array"
  | Object ->
      "object"
  | Reference ->
      "reference"
  | Color ->
      "color"
  | Duration ->
      "duration"
  | Size ->
      "size"

let value_type_of_value = function
  | Value.String _ ->
      String
  | Value.Integer _ ->
      Integer
  | Value.Float _ ->
      Float
  | Value.Boolean _ ->
      Boolean
  | Value.Null ->
      Null
  | Value.Array _ ->
      Array
  | Value.Object _ ->
      Object
  | Value.Reference _ ->
      Reference
  | Value.Color _ ->
      Color
  | Value.Duration _ ->
      Duration
  | Value.Size _ ->
      Size

let type_matches expected value =
  match expected, value.Node.value with
  | Any, _ ->
      true

  | Number, (Value.Integer _ | Value.Float _) ->
      true

  | String, Value.String _
  | Integer, Value.Integer _
  | Float, Value.Float _
  | Boolean, Value.Boolean _
  | Null, Value.Null
  | Array, Value.Array _
  | Object, Value.Object _
  | Reference, Value.Reference _
  | Color, Value.Color _
  | Duration, Value.Duration _
  | Size, Value.Size _ ->
      true

  | _ ->
      false

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let make
    ?(value_type = Any)
    ?(required = false)
    ?default
    ?description
    ?(deprecated = false)
    ?replacement
    ?(constraints = [])
    name =
  {
    name;
    value_type;
    required;
    default;
    description;
    deprecated;
    replacement;
    constraints;
  }

let required
    ?(value_type = Any)
    ?description
    ?(deprecated = false)
    ?replacement
    ?(constraints = [])
    name =
  make
    ~value_type
    ~required:true
    ?description
    ~deprecated
    ?replacement
    ~constraints
    name

let optional
    ?(value_type = Any)
    ?default
    ?description
    ?(deprecated = false)
    ?replacement
    ?(constraints = [])
    name =
  make
    ~value_type
    ~required:false
    ?default
    ?description
    ~deprecated
    ?replacement
    ~constraints
    name

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let name field =
  field.name

let value_type field =
  field.value_type

let is_required field =
  field.required

let is_optional field =
  not field.required

let default field =
  field.default

let description field =
  field.description

let is_deprecated field =
  field.deprecated

let replacement field =
  field.replacement

let constraints field =
  field.constraints

let has_default field =
  Option.is_some field.default

let has_constraints field =
  field.constraints <> []

(* ---------------------------------------------------------- *)
(* Constraint helpers                                         *)
(* ---------------------------------------------------------- *)

let constraint_name = function
  | Min_integer _ ->
      "min_integer"
  | Max_integer _ ->
      "max_integer"
  | Min_number _ ->
      "min_number"
  | Max_number _ ->
      "max_number"
  | Min_length _ ->
      "min_length"
  | Max_length _ ->
      "max_length"
  | Non_empty ->
      "non_empty"
  | One_of _ ->
      "one_of"
  | Custom { name; _ } ->
      name

let length_of_value = function
  | Value.String value ->
      Some (String.length value)
  | Value.Array values ->
      Some (List.length values)
  | Value.Object entries ->
      Some (List.length entries)
  | _ ->
      None

let numeric_value = function
  | Value.Integer value ->
      Some (Int64.to_float value)
  | Value.Float value ->
      Some value
  | _ ->
      None

let constraint_message constraint_ =
  match constraint_ with
  | Min_integer value ->
      Printf.sprintf
        "value must be greater than or equal to %Ld"
        value

  | Max_integer value ->
      Printf.sprintf
        "value must be less than or equal to %Ld"
        value

  | Min_number value ->
      Printf.sprintf
        "value must be greater than or equal to %g"
        value

  | Max_number value ->
      Printf.sprintf
        "value must be less than or equal to %g"
        value

  | Min_length value ->
      Printf.sprintf
        "value length must be at least %d"
        value

  | Max_length value ->
      Printf.sprintf
        "value length must be at most %d"
        value

  | Non_empty ->
      "value must not be empty"

  | One_of _ ->
      "value is not one of the allowed values"

  | Custom { message; _ } ->
      message

let validate_constraint constraint_ value =
  match constraint_, value.Node.value with
  | Min_integer minimum, Value.Integer current ->
      Int64.compare current minimum >= 0

  | Max_integer maximum, Value.Integer current ->
      Int64.compare current maximum <= 0

  | Min_integer minimum, Value.Float current ->
      current >= Int64.to_float minimum

  | Max_integer maximum, Value.Float current ->
      current <= Int64.to_float maximum

  | Min_number minimum, current ->
      begin
        match numeric_value current with
        | Some current ->
            current >= minimum
        | None ->
            false
      end

  | Max_number maximum, current ->
      begin
        match numeric_value current with
        | Some current ->
            current <= maximum
        | None ->
            false
      end

  | Min_length minimum, current ->
      begin
        match length_of_value current with
        | Some length ->
            length >= minimum
        | None ->
            false
      end

  | Max_length maximum, current ->
      begin
        match length_of_value current with
        | Some length ->
            length <= maximum
        | None ->
            false
      end

  | Non_empty, Value.String value ->
      value <> ""

  | Non_empty, Value.Array values ->
      values <> []

  | Non_empty, Value.Object entries ->
      entries <> []

  | Non_empty, _ ->
      true

  | One_of allowed, current ->
      List.exists
        (fun allowed ->
          Value.equal allowed current)
        allowed

  | Custom { validate; _ }, _ ->
      validate value

  | _ ->
      false

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

let validate_value field value =
  if not (type_matches field.value_type value) then
    [
      Type_mismatch
        {
          field = field.name;
          expected = field.value_type;
          found = value_type_of_value value.Node.value;
        };
    ]
  else
    field.constraints
    |> List.filter_map
         (fun constraint_ ->
           if validate_constraint constraint_ value then
             None
           else
             Some
               (Constraint_violation
                  {
                    field = field.name;
                    constraint_;
                    message =
                      constraint_message constraint_;
                  }))

let validate_default field =
  match field.default with
  | None ->
      []

  | Some value ->
      if validate_value field value = [] then
        []
      else
        [Invalid_default field.name]

let validate_presence field value =
  match value with
  | None when field.required ->
      [Missing_required_field field.name]

  | None ->
      []

  | Some value ->
      validate_value field value

let validate field value =
  validate_presence field value
  @ validate_default field

let is_valid field value =
  validate field value = []

(* ---------------------------------------------------------- *)
(* Defaults                                                   *)
(* ---------------------------------------------------------- *)

let apply_default field value =
  match value with
  | Some value ->
      Some value

  | None ->
      field.default

(* ---------------------------------------------------------- *)
(* Mutation helpers                                           *)
(* ---------------------------------------------------------- *)

let with_type value_type field =
  {
    field with
    value_type;
  }

let with_required required field =
  {
    field with
    required;
  }

let with_default default field =
  {
    field with
    default = Some default;
  }

let without_default field =
  {
    field with
    default = None;
  }

let with_description description field =
  {
    field with
    description = Some description;
  }

let with_deprecated deprecated field =
  {
    field with
    deprecated;
  }

let with_replacement replacement field =
  {
    field with
    replacement = Some replacement;
  }

let add_constraint constraint_ field =
  {
    field with
    constraints =
      field.constraints @ [constraint_];
  }

let add_constraints constraints field =
  {
    field with
    constraints =
      field.constraints @ constraints;
  }

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let diagnostic_of_validation_error
    ?span
    error =
  match error with
  | Missing_required_field field ->
      Error.to_diagnostic
        (Error.make
           ?span
           (Error.Missing_required_field field))

  | Type_mismatch { field; expected; found } ->
      Error.to_diagnostic_with_notes
        ~notes:[
          Printf.sprintf
            "Schema field: %s"
            field;
        ]
        (Error.make
           ?span
           (Error.Type_mismatch
              {
                expected =
                  string_of_value_type expected;
                found =
                  string_of_value_type found;
              }))

  | Constraint_violation
      {
        field;
        message;
        _;
      } ->
      Error.to_diagnostic_with_notes
        ~notes:[
          Printf.sprintf
            "Schema field: %s"
            field;
        ]
        (Error.make
           ?span
           (Error.Schema_violation message))

  | Invalid_default field ->
      Error.to_diagnostic
        (Error.make
           ?span
           (Error.Schema_violation
              (Printf.sprintf
                 "invalid default value for field '%s'"
                 field)))

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_validation_error = function
  | Missing_required_field field ->
      Printf.sprintf
        "missing required field '%s'"
        field

  | Type_mismatch
      {
        field;
        expected;
        found;
      } ->
      Printf.sprintf
        "field '%s' expects %s but found %s"
        field
        (string_of_value_type expected)
        (string_of_value_type found)

  | Constraint_violation
      {
        field;
        message;
        _;
      } ->
      Printf.sprintf
        "field '%s': %s"
        field
        message

  | Invalid_default field ->
      Printf.sprintf
        "field '%s' has an invalid default value"
        field

let pp_value_type formatter value_type =
  Format.pp_print_string
    formatter
    (string_of_value_type value_type)

let pp_validation_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_validation_error error)

let pp formatter field =
  Format.fprintf
    formatter
    "%s: %s%s"
    field.name
    (string_of_value_type field.value_type)
    (if field.required then " (required)" else "")
