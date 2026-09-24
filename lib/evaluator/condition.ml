(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/evaluator/condition.ml
 *
 * Evaluation of VFConf conditional expressions.
 *)

type error =
  | Undefined_reference of Statement.reference
  | Invalid_reference_value of Statement.reference
  | Invalid_comparison of {
      left : Value.t;
      operator : Statement.comparison_operator;
      right : Value.t;
    }

exception Condition_error of error

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let string_of_path path =
  String.concat "." path

(* ---------------------------------------------------------- *)
(* Value helpers                                              *)
(* ---------------------------------------------------------- *)

let value_to_bool = function
  | Value.Boolean value ->
      Some value

  | Value.Null ->
      Some false

  | Value.Integer value ->
      Some (Int64.compare value 0L <> 0)

  | Value.Float value ->
      Some (Float.compare value 0.0 <> 0)

  | Value.String value ->
      Some (value <> "")

  | Value.Array values ->
      Some (values <> [])

  | Value.Object values ->
      Some (values <> [])

  | Value.Reference _
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      None

let numeric_value = function
  | Value.Integer value ->
      Some (Int64.to_float value)

  | Value.Float value ->
      Some value

  | _ ->
      None

let compare_numeric operator left right =
  match operator with
  | Statement.Equal ->
      Float.compare left right = 0

  | Statement.Not_equal ->
      Float.compare left right <> 0

  | Statement.Less ->
      Float.compare left right < 0

  | Statement.Less_equal ->
      Float.compare left right <= 0

  | Statement.Greater ->
      Float.compare left right > 0

  | Statement.Greater_equal ->
      Float.compare left right >= 0

let compare_string operator left right =
  let comparison =
    String.compare left right
  in

  match operator with
  | Statement.Equal ->
      comparison = 0

  | Statement.Not_equal ->
      comparison <> 0

  | Statement.Less ->
      comparison < 0

  | Statement.Less_equal ->
      comparison <= 0

  | Statement.Greater ->
      comparison > 0

  | Statement.Greater_equal ->
      comparison >= 0

let compare_bool operator left right =
  let comparison =
    Bool.compare left right
  in

  match operator with
  | Statement.Equal ->
      comparison = 0

  | Statement.Not_equal ->
      comparison <> 0

  | Statement.Less ->
      comparison < 0

  | Statement.Less_equal ->
      comparison <= 0

  | Statement.Greater ->
      comparison > 0

  | Statement.Greater_equal ->
      comparison >= 0

(* ---------------------------------------------------------- *)
(* Value comparison                                           *)
(* ---------------------------------------------------------- *)

let compare_values operator left right =
  match numeric_value left, numeric_value right with
  | Some left, Some right ->
      compare_numeric
        operator
        left
        right

  | _ ->
      begin
        match left, right with
        | Value.String left,
          Value.String right ->
            compare_string
              operator
              left
              right

        | Value.Boolean left,
          Value.Boolean right ->
            compare_bool
              operator
              left
              right

        | Value.Null,
          Value.Null ->
            begin
              match operator with
              | Statement.Equal
              | Statement.Less_equal
              | Statement.Greater_equal ->
                  true

              | Statement.Not_equal
              | Statement.Less
              | Statement.Greater ->
                  false
            end

        | _ ->
            begin
              match operator with
              | Statement.Equal ->
                  Value.equal left right

              | Statement.Not_equal ->
                  not (Value.equal left right)

              | Statement.Less
              | Statement.Less_equal
              | Statement.Greater
              | Statement.Greater_equal ->
                  raise
                    (Condition_error
                       (Invalid_comparison
                          {
                            left;
                            operator;
                            right;
                          }))
            end
      end

(* ---------------------------------------------------------- *)
(* Reference resolution                                       *)
(* ---------------------------------------------------------- *)

let resolve_reference config reference =
  match Config.find_opt reference config with
  | Some value ->
      value

  | None ->
      raise
        (Condition_error
           (Undefined_reference reference))

let resolve_reference_value config reference =
  (resolve_reference config reference).Node.value

let reference_exists config reference =
  Config.mem reference config

let reference_truthy config reference =
  let value =
    resolve_reference_value
      config
      reference
  in

  match value_to_bool value with
  | Some result ->
      result

  | None ->
      raise
        (Condition_error
           (Invalid_reference_value reference))

(* ---------------------------------------------------------- *)
(* Evaluation                                                 *)
(* ---------------------------------------------------------- *)

let rec evaluate config condition =
  match condition.Node.value with
  | Statement.Reference reference ->
      reference_truthy
        config
        reference

  | Statement.Boolean value ->
      value

  | Statement.Not condition ->
      not
        (evaluate
           config
           condition)

  | Statement.Logical
      {
        left;
        operator = Statement.And;
        right;
      } ->
      evaluate config left
      &&
      evaluate config right

  | Statement.Logical
      {
        left;
        operator = Statement.Or;
        right;
      } ->
      evaluate config left
      ||
      evaluate config right

  | Statement.Compare
      {
        reference;
        operator;
        value;
      } ->
      let left =
        resolve_reference_value
          config
          reference
      in

      compare_values
        operator
        left
        value.Node.value

let evaluate_opt config condition =
  try
    Some
      (evaluate
         config
         condition)
  with
  | Condition_error _ ->
      None

let evaluate_default
    ~default
    config
    condition =
  match evaluate_opt config condition with
  | Some value ->
      value

  | None ->
      default

(* ---------------------------------------------------------- *)
(* Static condition inspection                                *)
(* ---------------------------------------------------------- *)

let rec is_constant condition =
  match condition.Node.value with
  | Statement.Boolean _ ->
      true

  | Statement.Reference _ ->
      false

  | Statement.Not inner ->
      is_constant inner

  | Statement.Logical { left; right; _ } ->
      is_constant left
      &&
      is_constant right

  | Statement.Compare _ ->
      false

let rec constant_value condition =
  match condition.Node.value with
  | Statement.Boolean value ->
      Some value

  | Statement.Reference _
  | Statement.Compare _ ->
      None

  | Statement.Not inner ->
      begin
        match constant_value inner with
        | Some value ->
            Some (not value)

        | None ->
            None
      end

  | Statement.Logical
      {
        left;
        operator;
        right;
      } ->
      begin
        match
          constant_value left,
          constant_value right
        with
        | Some left, Some right ->
            begin
              match operator with
              | Statement.And ->
                  Some (left && right)

              | Statement.Or ->
                  Some (left || right)
            end

        | _ ->
            None
      end

let is_always_true condition =
  constant_value condition = Some true

let is_always_false condition =
  constant_value condition = Some false

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let diagnostic_of_error ?span = function
  | Undefined_reference reference ->
      Error.undefined_reference
        ?span
        (string_of_path reference)
      |> Error.to_diagnostic

  | Invalid_reference_value reference ->
      Error.invalid_condition
        ?span
        (Printf.sprintf
           "reference '$%s' cannot be used as a boolean condition"
           (string_of_path reference))
      |> Error.to_diagnostic

  | Invalid_comparison
      {
        left;
        operator = _;
        right;
      } ->
      Error.invalid_condition
        ?span
        (Printf.sprintf
           "values of type '%s' and '%s' cannot be ordered"
           (Value.type_name left)
           (Value.type_name right))
      |> Error.to_diagnostic

let evaluate_diagnostic config condition =
  try
    Ok
      (evaluate
         config
         condition)
  with
  | Condition_error error ->
      Error
        (diagnostic_of_error
           ~span:condition.Node.span
           error)

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Undefined_reference reference ->
      Printf.sprintf
        "undefined reference '$%s'"
        (string_of_path reference)

  | Invalid_reference_value reference ->
      Printf.sprintf
        "reference '$%s' cannot be evaluated as a boolean"
        (string_of_path reference)

  | Invalid_comparison
      {
        left;
        operator = _;
        right;
      } ->
      Printf.sprintf
        "cannot compare %s with %s using an ordering operator"
        (Value.type_name left)
        (Value.type_name right)

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)