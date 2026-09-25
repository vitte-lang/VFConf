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

type state = {
  config : Config.t;
  environment : environment;
  diagnostics : Diagnostic.t list;
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
  | Unsupported_statement of string

exception Evaluation_error of error

let empty_environment =
  {
    definitions = String_map.empty;
  }

let empty_state ?filename () =
  {
    config = Config.empty ?filename ();
    environment = empty_environment;
    diagnostics = [];
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

  | Value.String _
  | Value.Integer _
  | Value.Float _
  | Value.Boolean _
  | Value.Null
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      value

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
            begin
              match append_value current value with
              | Some result ->
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
            begin
              match subtract_value current value with
              | Some result ->
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
  try
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

let evaluate_document
    ?filename
    statements =
  let state =
    empty_state
      ?filename
      ()
  in

  evaluate_statements
    []
    state
    statements

let evaluate
    ?filename
    statements =
  (evaluate_document
     ?filename
     statements).config

let evaluate_with_diagnostics
    ?filename
    statements =
  try
    let state =
      evaluate_document
        ?filename
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