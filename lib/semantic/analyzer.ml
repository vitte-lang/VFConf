(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/analyzer.ml
 *
 * Semantic analysis for VFConf documents.
 *)

module String_map = Map.Make (String)
module String_set = Set.Make (String)

type symbol_kind =
  | Definition
  | Configuration

type symbol = {
  name : string;
  path : Config.path;
  kind : symbol_kind;
  value : Value.t Node.t;
  span : Node.span;
}

type state = {
  symbols : symbol String_map.t;
  definitions : symbol String_map.t;
  schema_fields : String_set.t;
  diagnostics : Diagnostic.t list;
}

type result = {
  document : Statement.t Node.t list;
  symbols : symbol list;
  diagnostics : Diagnostic.t list;
}

let empty_state =
  {
    symbols = String_map.empty;
    definitions = String_map.empty;
    schema_fields = String_set.empty;
    diagnostics = [];
  }

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let path_key path =
  Config.string_of_path path

let qualify prefix path =
  prefix @ path

let definition_key name =
  name

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let add_diagnostic diagnostic (state : state) =
  {
    state with
    diagnostics =
      diagnostic :: state.diagnostics;
  }

let add_error ?span kind (state : state) =
  Error.make
    ?span
    kind
  |> Error.to_diagnostic
  |> fun diagnostic ->
       add_diagnostic diagnostic state

let add_warning warning (state : state) =
  Warning.to_diagnostic warning
  |> fun diagnostic ->
       add_diagnostic diagnostic state

let duplicate_key path span state =
  add_error
    ~span
    (Error.Duplicate_key
       (Config.string_of_path path))
    state

let duplicate_definition name span state =
  add_warning
    (Warning.duplicate_definition
       ~span
       name)
    state

let undefined_reference path span state =
  add_error
    ~span
    (Error.Undefined_reference
       (Config.string_of_path path))
    state

let invalid_assignment path operator span state =
  add_error
    ~span
    (Error.Invalid_assignment
       {
         key =
           Config.string_of_path path;
         operator =
           Statement.string_of_assignment_operator
             operator;
       })
    state

(* ---------------------------------------------------------- *)
(* Symbols                                                    *)
(* ---------------------------------------------------------- *)

let add_configuration_symbol
    path
    value
    span
    (state : state) =
  let key =
    path_key path
  in

  if String_map.mem key state.symbols then
    duplicate_key
      path
      span
      state
  else
    let symbol =
      {
        name = key;
        path;
        kind = Configuration;
        value;
        span;
      }
    in

    {
      state with
      symbols =
        String_map.add
          key
          symbol
          state.symbols;
    }

let add_definition_symbol
    name
    value
    span
    (state : state) =
  let key =
    definition_key name
  in

  if String_map.mem key state.definitions then
    duplicate_definition
      name
      span
      state
  else
    let symbol =
      {
        name;
        path = [name];
        kind = Definition;
        value;
        span;
      }
    in

    {
      state with
      definitions =
        String_map.add
          key
          symbol
          state.definitions;
    }

let find_configuration_symbol
    (state : state)
    path =
  String_map.find_opt
    (path_key path)
    state.symbols

let find_definition_symbol
    (state : state)
    name =
  String_map.find_opt
    (definition_key name)
    state.definitions

(* ---------------------------------------------------------- *)
(* Schema field symbols                                       *)
(* ---------------------------------------------------------- *)

let schema_field_path = function
  | "schema" :: section :: "fields" :: field :: _ ->
      Some [section; field]

  | _ ->
      None

let add_schema_field path (state : state) =
  match schema_field_path path with
  | None ->
      state

  | Some logical_path ->
      {
        state with
        schema_fields =
          String_set.add
            (path_key logical_path)
            state.schema_fields;
      }

let schema_reference_exists
    (state : state)
    path =
  let direct =
    String_set.mem
      (path_key path)
      state.schema_fields
  in

  if direct then
    true
  else
    match path with
    | "schema" :: "root" :: rest ->
        String_set.mem
          (path_key ("root" :: rest))
          state.schema_fields

    | _ ->
        false

(* ---------------------------------------------------------- *)
(* Reference analysis                                         *)
(* ---------------------------------------------------------- *)

let reference_exists
    (state : state)
    path =
  match path with
  | [name]
    when Option.is_some
           (find_definition_symbol state name) ->
      true

  | _ ->
      Option.is_some
        (find_configuration_symbol
           state
           path)
      || schema_reference_exists
           state
           path

let reference_exists_in_scope
    (state : state)
    prefix
    path =
  let local_path =
    qualify prefix path
  in

  let local_exists =
    prefix <> []
    && Option.is_some
         (find_configuration_symbol
            state
            local_path)
  in

  if local_exists then
    true
  else
    reference_exists
      state
      path

let rec analyze_value
    prefix
    (state : state)
    value =
  match value.Node.value with
  | Value.Reference path ->
      if
        reference_exists_in_scope
          state
          prefix
          path
      then
        state
      else
        undefined_reference
          path
          value.Node.span
          state

  | Value.Array values ->
      List.fold_left
        (analyze_value prefix)
        state
        values

  | Value.Object entries ->
      List.fold_left
        (fun state entry ->
          analyze_value
            prefix
            state
            entry.Value.value)
        state
        entries

  | Value.String _
  | Value.Integer _
  | Value.Float _
  | Value.Boolean _
  | Value.Null
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      state

let analyze_condition
    prefix
    (state : state)
    condition =
  let rec walk state condition =
    match condition.Node.value with
    | Statement.Reference path ->
        if
          reference_exists_in_scope
            state
            prefix
            path
        then
          state
        else
          undefined_reference
            path
            condition.Node.span
            state

    | Statement.Boolean _ ->
        state

    | Statement.Not condition ->
        walk
          state
          condition

    | Statement.Logical
        {
          left;
          right;
          _;
        } ->
        let state =
          walk
            state
            left
        in

        walk
          state
          right

    | Statement.Compare
        {
          reference;
          value;
          _;
        } ->
        let state =
          if
            reference_exists_in_scope
              state
              prefix
              reference
          then
            state
          else
            undefined_reference
              reference
              condition.Node.span
              state
        in

        analyze_value
          prefix
          state
          value
  in

  walk
    state
    condition

(* ---------------------------------------------------------- *)
(* Declaration pass                                           *)
(* ---------------------------------------------------------- *)

let rec declare_statement
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

      begin
        match assignment.Statement.operator with
        | Statement.Assign
        | Statement.Define_assign ->
            let state =
              add_configuration_symbol
                path
                assignment.Statement.value
                statement.Node.span
                state
            in

            add_schema_field
              path
              state

        | Statement.Add_assign
        | Statement.Sub_assign ->
            state
      end

  | Statement.Define definition ->
      add_definition_symbol
        definition.Statement.name
        definition.Statement.value
        statement.Node.span
        state

  | Statement.Include _ ->
      state

  | Statement.Section section ->
      let section_prefix =
        qualify
          prefix
          section.Statement.name
      in

      List.fold_left
        (declare_statement section_prefix)
        state
        section.Statement.body

  | Statement.Conditional conditional ->
      let state =
        List.fold_left
          (declare_statement prefix)
          state
          conditional.Statement.then_branch
      in

      begin
        match conditional.Statement.else_branch with
        | None ->
            state

        | Some statements ->
            List.fold_left
              (declare_statement prefix)
              state
              statements
      end

let declare_document document =
  List.fold_left
    (declare_statement [])
    empty_state
    document

(* ---------------------------------------------------------- *)
(* Reference pass                                             *)
(* ---------------------------------------------------------- *)

let rec analyze_statement
    prefix
    state
    statement =
  match statement.Node.value with
  | Statement.Assignment assignment ->
      analyze_value
        prefix
        state
        assignment.Statement.value

  | Statement.Define definition ->
      analyze_value
        prefix
        state
        definition.Statement.value

  | Statement.Include _ ->
      state

  | Statement.Section section ->
      let section_prefix =
        qualify
          prefix
          section.Statement.name
      in

      List.fold_left
        (analyze_statement section_prefix)
        state
        section.Statement.body

  | Statement.Conditional conditional ->
      let state =
        analyze_condition
          prefix
          state
          conditional.Statement.condition
      in

      let state =
        List.fold_left
          (analyze_statement prefix)
          state
          conditional.Statement.then_branch
      in

      begin
        match conditional.Statement.else_branch with
        | None ->
            state

        | Some statements ->
            List.fold_left
              (analyze_statement prefix)
              state
              statements
      end

(* ---------------------------------------------------------- *)
(* Assignment semantics                                       *)
(* ---------------------------------------------------------- *)

let rec validate_statement
    prefix
    state
    statement =
  let state =
    match statement.Node.value with
    | Statement.Assignment assignment ->
        begin
          match assignment.Statement.operator with
          | Statement.Assign
          | Statement.Define_assign ->
              state

          | Statement.Add_assign
          | Statement.Sub_assign ->
              let path =
                qualify
                  prefix
                  assignment.Statement.key
              in

              if
                Option.is_some
                  (find_configuration_symbol
                     state
                     path)
              then
                state
              else
                invalid_assignment
                  path
                  assignment.Statement.operator
                  statement.Node.span
                  state
        end

    | _ ->
        state
  in

  match statement.Node.value with
  | Statement.Section section ->
      let section_prefix =
        qualify
          prefix
          section.Statement.name
      in

      List.fold_left
        (validate_statement section_prefix)
        state
        section.Statement.body

  | Statement.Conditional conditional ->
      let state =
        List.fold_left
          (validate_statement prefix)
          state
          conditional.Statement.then_branch
      in

      begin
        match conditional.Statement.else_branch with
        | None ->
            state

        | Some statements ->
            List.fold_left
              (validate_statement prefix)
              state
              statements
      end

  | Statement.Assignment _
  | Statement.Define _
  | Statement.Include _ ->
      state

(* ---------------------------------------------------------- *)
(* Analysis                                                   *)
(* ---------------------------------------------------------- *)

let analyze document =
  let state =
    declare_document document
  in

  let state =
    List.fold_left
      (analyze_statement [])
      state
      document
  in

  let state =
    List.fold_left
      (validate_statement [])
      state
      document
  in

  let symbols =
    String_map.bindings state.symbols
    |> List.map snd
  in

  let definitions =
    String_map.bindings state.definitions
    |> List.map snd
  in

  {
    document;
    symbols =
      definitions @ symbols;
    diagnostics =
      List.rev state.diagnostics;
  }

(* ---------------------------------------------------------- *)
(* Result inspection                                          *)
(* ---------------------------------------------------------- *)

let has_errors result =
  List.exists
    (fun diagnostic ->
      diagnostic.Diagnostic.severity
      = Diagnostic.Error)
    result.diagnostics

let is_valid result =
  not
    (has_errors result)

let diagnostics result =
  result.diagnostics

let symbols result =
  result.symbols

let document result =
  result.document

let find_symbol result path =
  let key =
    path_key path
  in

  List.find_opt
    (fun symbol ->
      match symbol.kind with
      | Configuration ->
          String.equal
            symbol.name
            key

      | Definition ->
          false)
    result.symbols

let find_definition result name =
  List.find_opt
    (fun symbol ->
      match symbol.kind with
      | Definition ->
          String.equal
            symbol.name
            name

      | Configuration ->
          false)
    result.symbols

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let string_of_symbol_kind = function
  | Definition ->
      "definition"

  | Configuration ->
      "configuration"

let pp_symbol_kind formatter kind =
  Format.pp_print_string
    formatter
    (string_of_symbol_kind kind)

let pp_symbol formatter symbol =
  Format.fprintf
    formatter
    "@[<hov 2>%s %s = %a@]"
    (string_of_symbol_kind symbol.kind)
    symbol.name
    Value.pp
    symbol.value.Node.value

let pp formatter result =
  Format.fprintf
    formatter
    "@[<v>";

  List.iter
    (fun symbol ->
      Format.fprintf
        formatter
        "%a@,"
        pp_symbol
        symbol)
    result.symbols;

  if result.diagnostics <> [] then begin
    Format.fprintf
      formatter
      "@,diagnostics:@,";

    List.iter
      (fun diagnostic ->
        Format.fprintf
          formatter
          "%a@,"
          Diagnostic.pp
          diagnostic)
      result.diagnostics
  end;

  Format.fprintf
    formatter
    "@]"