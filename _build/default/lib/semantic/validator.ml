(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/validator.ml
 *
 * High-level semantic validation pipeline.
 *)

type options = {
  resolve_references : bool;
  validate_schema : bool;
  allow_warnings : bool;
  maximum_reference_depth : int;
}

type result = {
  document : Statement.t Node.t list;
  config : Config.t option;
  environment : Environment.t;
  diagnostics : Diagnostic.t list;
}

type error =
  | Semantic_analysis_failed
  | Reference_resolution_failed
  | Schema_validation_failed
  | Configuration_unavailable

exception Validation_error of error

let default_options =
  {
    resolve_references = true;
    validate_schema = true;
    allow_warnings = true;
    maximum_reference_depth =
      Resolver.default_maximum_depth;
  }

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let is_error diagnostic =
  diagnostic.Diagnostic.severity
  = Diagnostic.Error

let is_warning diagnostic =
  diagnostic.Diagnostic.severity
  = Diagnostic.Warning

let errors diagnostics =
  List.filter
    is_error
    diagnostics

let warnings diagnostics =
  List.filter
    is_warning
    diagnostics

let has_errors diagnostics =
  List.exists
    is_error
    diagnostics

let has_warnings diagnostics =
  List.exists
    is_warning
    diagnostics

let diagnostic_equal left right =
  left.Diagnostic.severity
  = right.Diagnostic.severity
  && left.Diagnostic.code
     = right.Diagnostic.code
  && String.equal
       left.Diagnostic.message
       right.Diagnostic.message
  && left.Diagnostic.span
     = right.Diagnostic.span

let same_reference_diagnostic left right =
  left.Diagnostic.severity
  = Diagnostic.Error
  && right.Diagnostic.severity
     = Diagnostic.Error
  && left.Diagnostic.code
     = Some "VF0202"
  && right.Diagnostic.code
     = Some "VF0202"
  && String.equal
       left.Diagnostic.message
       right.Diagnostic.message
  && left.Diagnostic.span
     = right.Diagnostic.span

let remove_duplicate_reference_diagnostics
    semantic_diagnostics
    resolution_diagnostics =
  List.filter
    (fun resolution_diagnostic ->
      not
        (List.exists
           (fun semantic_diagnostic ->
             same_reference_diagnostic
               semantic_diagnostic
               resolution_diagnostic)
           semantic_diagnostics))
    resolution_diagnostics

let unique_diagnostics diagnostics =
  let rec loop accumulator = function
    | [] ->
        List.rev accumulator

    | diagnostic :: rest ->
        if
          List.exists
            (diagnostic_equal diagnostic)
            accumulator
        then
          loop
            accumulator
            rest
        else
          loop
            (diagnostic :: accumulator)
            rest
  in

  loop
    []
    diagnostics

let filter_diagnostics options diagnostics =
  if options.allow_warnings then
    diagnostics
  else
    List.filter
      (fun diagnostic ->
        not (is_warning diagnostic))
      diagnostics

let normalize_diagnostics options diagnostics =
  diagnostics
  |> unique_diagnostics
  |> filter_diagnostics options

let internal_error message =
  Error.make
    (Error.Internal_error message)
  |> Error.to_diagnostic

(* ---------------------------------------------------------- *)
(* Configuration construction                                 *)
(* ---------------------------------------------------------- *)

let config_of_environment environment =
  Environment.configurations environment
  |> List.fold_left
       (fun config binding ->
         Config.set
           binding.Environment.path
           binding.Environment.value
           config)
       (Config.empty ())

let config_of_analyzer_result analysis =
  analysis.Analyzer.symbols
  |> List.fold_left
       (fun config symbol ->
         match symbol.Analyzer.kind with
         | Analyzer.Definition ->
             config

         | Analyzer.Configuration ->
             Config.set
               symbol.Analyzer.path
               symbol.Analyzer.value
               config)
       (Config.empty ())

(* ---------------------------------------------------------- *)
(* Semantic analysis                                          *)
(* ---------------------------------------------------------- *)

let analyze_document document =
  let analysis =
    Analyzer.analyze
      document
  in

  let environment =
    Environment.of_analyzer_result
      analysis
  in

  (analysis, environment)

(* ---------------------------------------------------------- *)
(* Reference resolution                                       *)
(* ---------------------------------------------------------- *)

let resolve_environment options environment =
  if not options.resolve_references then
    (environment, [])
  else
    let resolution =
      Resolver.analyze
        ~maximum_depth:
          options.maximum_reference_depth
        environment
    in

    if Resolver.has_errors resolution then
      (environment, resolution.Resolver.diagnostics)
    else
      try
        let environment =
          Resolver.resolve_environment
            ~maximum_depth:
              options.maximum_reference_depth
            environment
        in

        (environment, resolution.Resolver.diagnostics)

      with
      | Resolver.Resolution_error _ ->
          let diagnostic =
            internal_error
              "reference resolution failed after successful reference analysis"
          in

          ( environment,
            resolution.Resolver.diagnostics
            @ [diagnostic] )

(* ---------------------------------------------------------- *)
(* Schema validation                                          *)
(* ---------------------------------------------------------- *)

let validate_schema
    options
    schema
    config =
  if not options.validate_schema then
    (config, [])
  else
    match schema with
    | None ->
        (config, [])

    | Some schema ->
        let validation =
          Schema.validate
            schema
            config
        in

        ( validation.Schema.config,
          validation.Schema.diagnostics )

(* ---------------------------------------------------------- *)
(* Pipeline                                                   *)
(* ---------------------------------------------------------- *)

let validate
    ?(options = default_options)
    ?schema
    document =
  let analysis, environment =
    analyze_document
      document
  in

  let semantic_diagnostics =
    analysis.Analyzer.diagnostics
  in

  let environment, resolution_diagnostics =
    resolve_environment
      options
      environment
  in

  let resolution_diagnostics =
    remove_duplicate_reference_diagnostics
      semantic_diagnostics
      resolution_diagnostics
  in

  let config =
    if options.resolve_references then
      config_of_environment
        environment
    else
      config_of_analyzer_result
        analysis
  in

  let config, schema_diagnostics =
    validate_schema
      options
      schema
      config
  in

  let diagnostics =
    semantic_diagnostics
    @ resolution_diagnostics
    @ schema_diagnostics
    |> normalize_diagnostics options
  in

  {
    document;
    config = Some config;
    environment;
    diagnostics;
  }

let validate_config
    ?(options = default_options)
    ?schema
    config =
  let environment =
    Environment.of_config
      config
  in

  let environment, resolution_diagnostics =
    resolve_environment
      options
      environment
  in

  let config =
    if options.resolve_references then
      config_of_environment
        environment
    else
      config
  in

  let config, schema_diagnostics =
    validate_schema
      options
      schema
      config
  in

  let diagnostics =
    resolution_diagnostics
    @ schema_diagnostics
    |> normalize_diagnostics options
  in

  {
    document = [];
    config = Some config;
    environment;
    diagnostics;
  }

(* ---------------------------------------------------------- *)
(* Result inspection                                          *)
(* ---------------------------------------------------------- *)

let diagnostics result =
  result.diagnostics

let config result =
  result.config

let environment result =
  result.environment

let document result =
  result.document

let result_errors result =
  errors
    result.diagnostics

let result_warnings result =
  warnings
    result.diagnostics

let error_count result =
  List.length
    (result_errors result)

let warning_count result =
  List.length
    (result_warnings result)

let result_has_errors result =
  has_errors
    result.diagnostics

let result_has_warnings result =
  has_warnings
    result.diagnostics

let is_valid
    ?(allow_warnings = true)
    result =
  if result_has_errors result then
    false
  else if
    (not allow_warnings)
    && result_has_warnings result
  then
    false
  else
    true

let config_exn result =
  match result.config with
  | Some config ->
      config

  | None ->
      raise
        (Validation_error
           Configuration_unavailable)

(* ---------------------------------------------------------- *)
(* Option helpers                                             *)
(* ---------------------------------------------------------- *)

let with_reference_resolution enabled options =
  {
    options with
    resolve_references = enabled;
  }

let with_schema_validation enabled options =
  {
    options with
    validate_schema = enabled;
  }

let with_warnings enabled options =
  {
    options with
    allow_warnings = enabled;
  }

let with_maximum_reference_depth depth options =
  if depth <= 0 then
    invalid_arg
      "Validator.with_maximum_reference_depth: depth must be positive";

  {
    options with
    maximum_reference_depth = depth;
  }

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Semantic_analysis_failed ->
      "semantic analysis failed"

  | Reference_resolution_failed ->
      "reference resolution failed"

  | Schema_validation_failed ->
      "schema validation failed"

  | Configuration_unavailable ->
      "validated configuration is unavailable"

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

(* ---------------------------------------------------------- *)
(* Result formatting                                          *)
(* ---------------------------------------------------------- *)

let pp_summary formatter result =
  let error_count =
    error_count result
  in

  let warning_count =
    warning_count result
  in

  Format.fprintf
    formatter
    "%d error%s, %d warning%s"
    error_count
    (if error_count = 1 then "" else "s")
    warning_count
    (if warning_count = 1 then "" else "s")

let pp formatter result =
  Format.fprintf
    formatter
    "@[<v>";

  begin
    match result.config with
    | None ->
        ()

    | Some config ->
        Format.fprintf
          formatter
          "%a"
          Config.pp
          config
  end;

  if result.diagnostics <> [] then begin
    Format.fprintf
      formatter
      "@,@,diagnostics:@,";

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
    "@,@[%a@]@]"
    pp_summary
    result