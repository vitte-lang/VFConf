(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/evaluator/evaluator.ml
 *
 * Main VFConf evaluator.
 *
 * Evaluates parsed VFConf statements into a Config.t while
 * resolving sections, definitions, references, conditions and
 * assignment operators.
 *)

module String_map = Map.Make (String)

type definition = Value.t Node.t

type environment = {
  definitions : definition String_map.t;
}

type options = {
  strict_types : bool;
  allow_numeric_conversions : bool;
  maximum_depth : int;
  maximum_operations : int;
}

let default_options =
  {
    strict_types = true;
    allow_numeric_conversions = true;
    maximum_depth = 128;
    maximum_operations = 100_000;
  }

type state = {
  config : Config.t;
  environment : environment;
  diagnostics : Diagnostic.t list;
  options : options;
}

type error =
  | Duplicate_definition of string
  | Undefined_definition of string
  | Undefined_reference of Statement.reference
  | Invalid_assignment of {
      path : Config.path;
      operator : Statement.assignment_operator;
    }
  | Invalid_condition of Condition.error
  | Invalid_value of string
  | Division_by_zero
  | Type_mismatch of { expected : string; found : string }
  | Limit_exceeded of { limit : string; maximum : int }
  | Unsupported_statement of string

exception Evaluation_error of error

let empty_environment =
  {
    definitions = String_map.empty;
  }

let empty_state ?filename ?(options = default_options) () =
  if options.maximum_depth < 1 || options.maximum_operations < 1 then
    invalid_arg "Evaluator options require positive limits";
  {
    config = Config.empty ?filename ();
    environment = empty_environment;
    diagnostics = [];
    options;
  }

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let path_to_string path =
  Config.string_of_path path

let qualify prefix path =
  prefix @ path

(* ---------------------------------------------------------- *)
(* Environment                                                *)
(* ---------------------------------------------------------- *)

let define environment name value =
  if String_map.mem name environment.definitions then
    raise
      (Evaluation_error
         (Duplicate_definition name));

  {
    definitions =
      String_map.add
        name
        value
        environment.definitions;
  }

let set_definition environment name value =
  {
    definitions =
      String_map.add
        name
        value
        environment.definitions;
  }

let find_definition_opt environment name =
  String_map.find_opt
    name
    environment.definitions

let find_definition environment name =
  match find_definition_opt environment name with
  | Some value ->
      value

  | None ->
      raise
        (Evaluation_error
           (Undefined_definition name))

let mem_definition environment name =
  String_map.mem
    name
    environment.definitions

let definitions environment =
  String_map.bindings
    environment.definitions

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let add_diagnostic diagnostic state =
  {
    state with
    diagnostics =
      diagnostic :: state.diagnostics;
  }

let add_diagnostics diagnostics state =
  {
    state with
    diagnostics =
      List.rev_append
        diagnostics
        state.diagnostics;
  }

let diagnostics state =
  Diagnostic.sort
    (List.rev state.diagnostics)

let add_warning ?span kind state =
  Warning.make ?span kind
  |> Warning.to_diagnostic
  |> fun diagnostic -> add_diagnostic diagnostic state

(* ---------------------------------------------------------- *)
(* Reference resolution                                       *)
(* ---------------------------------------------------------- *)

let resolve_config_reference config reference =
  Config.find_opt
    reference
    config

let resolve_definition_reference environment reference =
  match reference with
  | [] ->
      None

  | [name] ->
      find_definition_opt
        environment
        name

  | _ ->
      None

let resolve_reference state reference =
  match
    resolve_config_reference
      state.config
      reference
  with
  | Some value ->
      value

  | None ->
      begin
        match
          resolve_definition_reference
            state.environment
            reference
        with
        | Some value ->
            value

        | None ->
            raise
              (Evaluation_error
                 (Undefined_reference reference))
      end

(* ---------------------------------------------------------- *)
(* Value evaluation                                           *)
(* ---------------------------------------------------------- *)

let rec evaluate_value state value =
  match value.Node.value with
  | Value.Reference reference ->
      resolve_reference
        state
        reference

  | Value.Array values ->
      let values =
        List.map
          (evaluate_value state)
          values
      in

      Node.with_span
        value.Node.span
        (Node.make
           (Value.Array values))

  | Value.Object entries ->
      let entries =
        List.map
          (fun entry ->
            {
              Value.key =
                entry.Value.key;
              value =
                evaluate_value
                  state
                  entry.Value.value;
              span =
                entry.Value.span;
            })
          entries
      in

      Node.with_span
        value.Node.span
        (Node.make
           (Value.Object entries))

  | Value.Float number
    when classify_float number = FP_nan
         || classify_float number = FP_infinite ->
      raise (Evaluation_error (Invalid_value "non-finite floating-point value"))

  | Value.Color (Value.Rgb {red; green; blue})
    when List.exists (fun channel -> channel < 0 || channel > 255) [red; green; blue] ->
      raise (Evaluation_error (Invalid_value "RGB channel outside 0..255"))

  | Value.Color (Value.Rgba {red; green; blue; alpha})
    when List.exists (fun channel -> channel < 0 || channel > 255) [red; green; blue]
         || alpha < 0.0 || alpha > 1.0
         || classify_float alpha = FP_nan ->
      raise (Evaluation_error (Invalid_value "RGBA component outside its valid range"))

  | Value.Duration (amount, _)
  | Value.Size (amount, _)
    when amount < 0.0
         || classify_float amount = FP_nan
         || classify_float amount = FP_infinite ->
      raise (Evaluation_error (Invalid_value "negative or non-finite quantity"))

  | Value.String _
  | Value.Integer _
  | Value.Float _
  | Value.Boolean _
  | Value.Null
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      value

let divide_numbers left right =
  if right = 0.0 then
    raise (Evaluation_error Division_by_zero)
  else
    left /. right

let value_type = function
  | Value.String _ -> "string"
  | Value.Integer _ -> "integer"
  | Value.Float _ -> "float"
  | Value.Boolean _ -> "boolean"
  | Value.Null -> "null"
  | Value.Array _ -> "array"
  | Value.Object _ -> "object"
  | Value.Reference _ -> "reference"
  | Value.Color _ -> "color"
  | Value.Duration _ -> "duration"
  | Value.Size _ -> "size"

let numeric_pair left right =
  match left, right with
  | Value.Integer _, Value.Float _
  | Value.Float _, Value.Integer _ -> true
  | _ -> false

let ensure_compatible state left right =
  let left_type = value_type left.Node.value in
  let right_type = value_type right.Node.value in
  if
    state.options.strict_types
    && not (String.equal left_type right_type)
    && not
         (state.options.allow_numeric_conversions
          && numeric_pair left.Node.value right.Node.value)
  then
    raise
      (Evaluation_error
         (Type_mismatch {expected = left_type; found = right_type}))

let add_conversion_warning state left right =
  if numeric_pair left.Node.value right.Node.value then
    add_warning
      ~span:right.Node.span
      (Warning.Implicit_conversion
         {from_type = "integer"; to_type = "float"})
      state
  else
    state

(* ---------------------------------------------------------- *)
(* Assignment operations                                      *)
(* ---------------------------------------------------------- *)

let append_value left right =
  match left.Node.value, right.Node.value with
  | Value.Array left_values,
    Value.Array right_values ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Array
              (left_values @ right_values)))

  | Value.String left_value,
    Value.String right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.String
              (left_value ^ right_value)))

  | Value.Integer left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Integer
              (Int64.add
                 left_value
                 right_value)))

  | Value.Float left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value +. right_value)))

  | Value.Integer left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (Int64.to_float left_value
               +. right_value)))

  | Value.Float left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value
               +. Int64.to_float right_value)))

  | _ ->
      None

let subtract_value left right =
  match left.Node.value, right.Node.value with
  | Value.Integer left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Integer
              (Int64.sub
                 left_value
                 right_value)))

  | Value.Float left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value -. right_value)))

  | Value.Integer left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (Int64.to_float left_value
               -. right_value)))

  | Value.Float left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value
               -. Int64.to_float right_value)))

  | Value.Array left_values,
    Value.Array right_values ->
      let values =
        List.filter
          (fun candidate ->
            not
              (List.exists
                 (fun removed ->
                   Value.equal
                     candidate.Node.value
                     removed.Node.value)
                 right_values))
          left_values
      in

      Some
        (Node.located
           (Node.merge left right)
           (Value.Array values))

  | _ ->
      None

let invalid_assignment path operator =
  raise
    (Evaluation_error
       (Invalid_assignment
          {
            path;
            operator;
          }))

let apply_assignment
    state
    path
    operator
    value =
  match operator with
  | Statement.Assign ->
      let state =
        match Config.find_opt path state.config with
        | None -> state
        | Some current ->
            ensure_compatible state current value;
            let state = add_conversion_warning state current value in
            if Value.equal current.Node.value value.Node.value then
            add_warning
              ~span:value.Node.span
              (Warning.Redundant_assignment (path_to_string path))
              state
            else
            add_warning
              ~span:value.Node.span
              (Warning.Overwritten_value (path_to_string path))
              state
      in
      {
        state with
        config =
          Config.set
            path
            value
            state.config;
      }

  | Statement.Define_assign ->
      if Config.mem path state.config then
        invalid_assignment
          path
          operator;

      {
        state with
        config =
          Config.add
            path
            value
            state.config;
      }

  | Statement.Add_assign ->
      begin
        match Config.find_opt path state.config with
        | None ->
            invalid_assignment
              path
              operator

        | Some current ->
            ensure_compatible state current value;
            begin
              match append_value current value with
              | Some result ->
                  let state = add_conversion_warning state current value in
                  {
                    state with
                    config =
                      Config.set
                        path
                        result
                        state.config;
                  }

              | None ->
                  invalid_assignment
                    path
                    operator
            end
      end

  | Statement.Sub_assign ->
      begin
        match Config.find_opt path state.config with
        | None ->
            invalid_assignment
              path
              operator

        | Some current ->
            ensure_compatible state current value;
            begin
              match subtract_value current value with
              | Some result ->
                  let state = add_conversion_warning state current value in
                  {
                    state with
                    config =
                      Config.set
                        path
                        result
                        state.config;
                  }

              | None ->
                  invalid_assignment
                    path
                    operator
            end
      end

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

let evaluate_condition prefix state condition =
  let rec validate condition =
    match condition.Node.value with
    | Statement.Boolean _ -> ()
    | Statement.Reference reference ->
        let value = Condition.resolve_reference prefix state.config reference in
        if state.options.strict_types then
          begin
            match value.Node.value with
            | Value.Boolean _ -> ()
            | found ->
                raise
                  (Evaluation_error
                     (Type_mismatch
                        {expected = "boolean"; found = value_type found}))
          end
    | Statement.Not nested -> validate nested
    | Statement.Logical {left; right; _} ->
        validate left;
        validate right
    | Statement.Compare {reference; value; _} ->
        let left = Condition.resolve_reference prefix state.config reference in
        ensure_compatible state left value
  in
  try
    validate condition;
    Condition.evaluate
      prefix
      state.config
      condition
  with
  | Condition.Condition_error error ->
      raise
        (Evaluation_error
           (Invalid_condition error))

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

let rec evaluate_statements
    prefix
    state
    statements =
  List.fold_left
    (evaluate_statement prefix)
    state
    statements

and evaluate_statement
    prefix
    state
    statement =
  match statement.Node.value with
  | Statement.Assignment assignment ->
      let path =
        qualify
          prefix
          assignment.Statement.key
      in

      let value =
        evaluate_value
          state
          assignment.Statement.value
      in

      apply_assignment
        state
        path
        assignment.Statement.operator
        value

  | Statement.Define definition ->
      let value =
        evaluate_value
          state
          definition.Statement.value
      in

      {
        state with
        environment =
          define
            state.environment
            definition.Statement.name
            value;
      }

  | Statement.Section section ->
      let section_prefix =
        qualify
          prefix
          section.Statement.name
      in

      evaluate_statements
        section_prefix
        state
        section.Statement.body

  | Statement.Conditional conditional ->
      if
        evaluate_condition
          prefix
          state
          conditional.Statement.condition
      then
        evaluate_statements
          prefix
          state
          conditional.Statement.then_branch
      else
        begin
          match conditional.Statement.else_branch with
          | Some branch ->
              evaluate_statements
                prefix
                state
                branch

          | None ->
              state
        end

  | Statement.Include include_statement ->
      raise
        (Evaluation_error
           (Unsupported_statement
              (Printf.sprintf
                 "include %S must be resolved by the configuration loader"
                 include_statement.Statement.path)))

(* ---------------------------------------------------------- *)
(* Document evaluation                                        *)
(* ---------------------------------------------------------- *)

let rec value_complexity value =
  match value.Node.value with
  | Value.Array values ->
      1 + List.fold_left (fun total value -> total + value_complexity value) 0 values
  | Value.Object entries ->
      1
      + List.fold_left
          (fun total entry -> total + value_complexity entry.Value.value)
          0
          entries
  | _ -> 1

let rec condition_complexity condition =
  match condition.Node.value with
  | Statement.Boolean _ | Statement.Reference _ -> 1
  | Statement.Not nested -> 1 + condition_complexity nested
  | Statement.Logical {left; right; _} ->
      1 + condition_complexity left + condition_complexity right
  | Statement.Compare {value; _} -> 1 + value_complexity value

let rec statement_complexity statement =
  match statement.Node.value with
  | Statement.Assignment assignment -> 1 + value_complexity assignment.Statement.value
  | Statement.Define definition -> 1 + value_complexity definition.Statement.value
  | Statement.Include _ -> 1
  | Statement.Section section ->
      1 + List.fold_left (fun total item -> total + statement_complexity item) 0 section.Statement.body
  | Statement.Conditional conditional ->
      let else_complexity =
        match conditional.Statement.else_branch with
        | None -> 0
        | Some statements ->
            List.fold_left (fun total item -> total + statement_complexity item) 0 statements
      in
      1
      + condition_complexity conditional.Statement.condition
      + List.fold_left (fun total item -> total + statement_complexity item) 0 conditional.Statement.then_branch
      + else_complexity

let rec value_depth depth value =
  match value.Node.value with
  | Value.Array values ->
      List.fold_left (fun maximum value -> max maximum (value_depth (depth + 1) value)) depth values
  | Value.Object entries ->
      List.fold_left
        (fun maximum entry -> max maximum (value_depth (depth + 1) entry.Value.value))
        depth
        entries
  | _ -> depth

let rec condition_depth depth condition =
  match condition.Node.value with
  | Statement.Boolean _ | Statement.Reference _ -> depth
  | Statement.Not nested -> condition_depth (depth + 1) nested
  | Statement.Logical {left; right; _} ->
      max
        (condition_depth (depth + 1) left)
        (condition_depth (depth + 1) right)
  | Statement.Compare {value; _} -> value_depth (depth + 1) value

let rec statement_depth depth statement =
  match statement.Node.value with
  | Statement.Assignment assignment -> value_depth depth assignment.Statement.value
  | Statement.Define definition -> value_depth depth definition.Statement.value
  | Statement.Include _ -> depth
  | Statement.Section section ->
      List.fold_left
        (fun maximum item -> max maximum (statement_depth (depth + 1) item))
        depth
        section.Statement.body
  | Statement.Conditional conditional ->
      let branch_depth statements =
        List.fold_left
          (fun maximum item -> max maximum (statement_depth (depth + 1) item))
          depth
          statements
      in
      let else_depth =
        match conditional.Statement.else_branch with
        | None -> depth
        | Some statements -> branch_depth statements
      in
      max
        (condition_depth (depth + 1) conditional.Statement.condition)
        (max (branch_depth conditional.Statement.then_branch) else_depth)

let validate_limits options statements =
  if options.maximum_depth < 1 || options.maximum_operations < 1 then
    invalid_arg "Evaluator options require positive limits";
  let complexity =
    List.fold_left (fun total item -> total + statement_complexity item) 0 statements
  in
  if complexity > options.maximum_operations then
    raise
      (Evaluation_error
         (Limit_exceeded
            {limit = "operation count"; maximum = options.maximum_operations}));
  let depth =
    List.fold_left (fun maximum item -> max maximum (statement_depth 1 item)) 0 statements
  in
  if depth > options.maximum_depth then
    raise
      (Evaluation_error
         (Limit_exceeded {limit = "nesting depth"; maximum = options.maximum_depth}))

let evaluate_document
    ?filename
    ?(options = default_options)
    statements =
  validate_limits options statements;
  let state =
    empty_state
      ?filename
      ~options
      ()
  in

  evaluate_statements
    []
    state
    statements

let evaluate
    ?filename
    ?options
    statements =
  (evaluate_document
     ?filename
     ?options
     statements).config

let evaluate_with_diagnostics
    ?filename
    ?options
    statements =
  try
    let state =
      evaluate_document
        ?filename
        ?options
        statements
    in

    Ok
      ( state.config,
        diagnostics state )
  with
  | Evaluation_error error ->
      Error error

(* ---------------------------------------------------------- *)
(* Error conversion                                           *)
(* ---------------------------------------------------------- *)

let string_of_assignment_operator operator =
  Statement.string_of_assignment_operator
    operator

let diagnostic_of_error ?span = function
  | Duplicate_definition name ->
      Warning.duplicate_definition
        ?span
        name
      |> Warning.to_diagnostic

  | Undefined_definition name ->
      Error.undefined_reference
        ?span
        name
      |> Error.to_diagnostic

  | Undefined_reference reference ->
      Error.undefined_reference
        ?span
        (path_to_string reference)
      |> Error.to_diagnostic

  | Invalid_assignment { path; operator } ->
      Error.invalid_assignment
        ?span
        ~key:(path_to_string path)
        ~operator:
          (string_of_assignment_operator
             operator)
        ()
      |> Error.to_diagnostic

  | Invalid_condition error ->
      Condition.diagnostic_of_error
        ?span
        error

  | Invalid_value message ->
      Error.invalid_value ?span message
      |> Error.to_diagnostic

  | Division_by_zero ->
      Error.division_by_zero ?span ()
      |> Error.to_diagnostic

  | Type_mismatch {expected; found} ->
      Error.type_mismatch ?span ~expected ~found ()
      |> Error.to_diagnostic

  | Limit_exceeded {limit; maximum} ->
      Error.evaluation_failed
        ?span
        (Printf.sprintf "%s limit (%d) exceeded" limit maximum)
      |> Error.to_diagnostic

  | Unsupported_statement message ->
      Error.evaluation_failed
        ?span
        message
      |> Error.to_diagnostic

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Duplicate_definition name ->
      Printf.sprintf
        "definition '%s' is already defined"
        name

  | Undefined_definition name ->
      Printf.sprintf
        "undefined definition '%s'"
        name

  | Undefined_reference reference ->
      Printf.sprintf
        "undefined reference '$%s'"
        (path_to_string reference)

  | Invalid_assignment { path; operator } ->
      Printf.sprintf
        "invalid assignment '%s' for configuration key '%s'"
        (string_of_assignment_operator
           operator)
        (path_to_string path)

  | Invalid_condition error ->
      Condition.string_of_error
        error

  | Invalid_value message ->
      "invalid value: " ^ message

  | Division_by_zero ->
      "division by zero"

  | Type_mismatch {expected; found} ->
      Printf.sprintf "type mismatch: expected %s, found %s" expected found

  | Limit_exceeded {limit; maximum} ->
      Printf.sprintf "%s limit (%d) exceeded" limit maximum

  | Unsupported_statement message ->
      message

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

(* ---------------------------------------------------------- *)
(* State inspection                                           *)
(* ---------------------------------------------------------- *)

let config state =
  state.config

let environment state =
  state.environment

let definition_count environment =
  String_map.cardinal
    environment.definitions
