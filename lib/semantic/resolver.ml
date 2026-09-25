(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/resolver.ml
 *
 * Semantic reference resolution.
 *)

module String_set = Set.Make (String)

type path = Statement.reference

type source =
  | Definition
  | Configuration

type resolved = {
  path : path;
  value : Value.t Node.t;
  source : source;
  span : Node.span;
}

type error =
  | Empty_reference
  | Undefined_reference of path
  | Reference_cycle of path list
  | Maximum_depth_exceeded of {
      maximum : int;
      path : path;
    }

exception Resolution_error of error

type context = {
  environment : Environment.t;
  stack : path list;
  visited : String_set.t;
  maximum_depth : int;
}

type result = {
  environment : Environment.t;
  diagnostics : Diagnostic.t list;
}

let default_maximum_depth = 128

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let path_key path =
  Config.string_of_path path

let path_is_empty path =
  path = []

let path_equal left right =
  left = right

let path_mem path paths =
  List.exists
    (path_equal path)
    paths

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

let create_context
    ?(maximum_depth = default_maximum_depth)
    environment =
  {
    environment;
    stack = [];
    visited = String_set.empty;
    maximum_depth;
  }

let depth context =
  List.length context.stack

let current_path context =
  match context.stack with
  | path :: _ ->
      Some path

  | [] ->
      None

let push path context =
  if path_is_empty path then
    raise
      (Resolution_error Empty_reference);

  if depth context >= context.maximum_depth then
    raise
      (Resolution_error
         (Maximum_depth_exceeded
            {
              maximum = context.maximum_depth;
              path;
            }));

  let key =
    path_key path
  in

  if
    String_set.mem key context.visited
    || path_mem path context.stack
  then
    raise
      (Resolution_error
         (Reference_cycle
            (List.rev (path :: context.stack))));

  {
    context with
    stack = path :: context.stack;
    visited =
      String_set.add
        key
        context.visited;
  }

let pop context =
  match context.stack with
  | [] ->
      context

  | path :: rest ->
      {
        context with
        stack = rest;
        visited =
          String_set.remove
            (path_key path)
            context.visited;
      }

(* ---------------------------------------------------------- *)
(* Binding conversion                                         *)
(* ---------------------------------------------------------- *)

let source_of_binding_kind = function
  | Environment.Definition ->
      Definition

  | Environment.Configuration ->
      Configuration

let resolved_of_binding path binding =
  {
    path;
    value = binding.Environment.value;
    source =
      source_of_binding_kind
        binding.Environment.kind;
    span = binding.Environment.span;
  }

(* ---------------------------------------------------------- *)
(* Direct lookup                                              *)
(* ---------------------------------------------------------- *)

let resolve_direct (context : context) path =
  if path_is_empty path then
    raise
      (Resolution_error Empty_reference);

  match
    Environment.resolve_reference
      context.environment
      path
  with
  | Some binding ->
      resolved_of_binding
        path
        binding

  | None ->
      raise
        (Resolution_error
           (Undefined_reference path))

let resolve_direct_opt (context : context) path =
  try
    Some (resolve_direct context path)
  with
  | Resolution_error
      (Undefined_reference _) ->
      None

  | Resolution_error Empty_reference ->
      None

(* ---------------------------------------------------------- *)
(* Scoped reference lookup                                    *)
(* ---------------------------------------------------------- *)

let parent_path path =
  match List.rev path with
  | [] ->
      []
  | _ :: rest ->
      List.rev rest

let scoped_reference_path
    (context : context)
    path =
  match current_path context with
  | None ->
      path

  | Some owner_path ->
      let prefix =
        parent_path owner_path
      in

      if prefix = [] then
        path
      else
        let local_path =
          prefix @ path
        in

        match
          Environment.resolve_reference
            context.environment
            local_path
        with
        | Some _ ->
            local_path

        | None ->
            path

(* ---------------------------------------------------------- *)
(* Recursive value resolution                                 *)
(* ---------------------------------------------------------- *)

let rec resolve_value (context : context) value =
  match value.Node.value with
  | Value.Reference path ->
      let path =
        scoped_reference_path
          context
          path
      in

      let resolved =
        resolve context path
      in

      Node.located
        value.Node.span
        resolved.value.Node.value

  | Value.Array values ->
      let values =
        List.map
          (resolve_value context)
          values
      in

      Node.located
        value.Node.span
        (Value.Array values)

  | Value.Object entries ->
      let entries =
        List.map
          (fun entry ->
            {
              entry with
              Value.value =
                resolve_value
                  context
                  entry.Value.value;
            })
          entries
      in

      Node.located
        value.Node.span
        (Value.Object entries)

  | Value.String _
  | Value.Integer _
  | Value.Float _
  | Value.Boolean _
  | Value.Null
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      value

and resolve (context : context) path =
  let context =
    push path context
  in

  let direct =
    resolve_direct
      context
      path
  in

  let value =
    resolve_value
      context
      direct.value
  in

  {
    direct with
    value;
  }

let resolve_opt (context : context) path =
  try
    Some (resolve context path)
  with
  | Resolution_error _ ->
      None

(* ---------------------------------------------------------- *)
(* Dependency analysis                                        *)
(* ---------------------------------------------------------- *)

let rec value_dependencies value =
  match value.Node.value with
  | Value.Reference path ->
      [path]

  | Value.Array values ->
      List.concat
        (List.map
           value_dependencies
           values)

  | Value.Object entries ->
      List.concat
        (List.map
           (fun entry ->
             value_dependencies
               entry.Value.value)
           entries)

  | Value.String _
  | Value.Integer _
  | Value.Float _
  | Value.Boolean _
  | Value.Null
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      []

let dependencies context path =
  let direct =
    resolve_direct
      context
      path
  in

  value_dependencies
    direct.value

let transitive_dependencies context path =
  let rec visit seen accumulator path =
    let key =
      path_key path
    in

    if String_set.mem key seen then
      (seen, accumulator)
    else
      let seen =
        String_set.add
          key
          seen
      in

      let dependencies =
        try
          dependencies context path
        with
        | Resolution_error
            (Undefined_reference _) ->
            []
      in

      List.fold_left
        (fun (seen, accumulator) dependency ->
          let seen, accumulator =
            visit
              seen
              accumulator
              dependency
          in

          (seen, dependency :: accumulator))
        (seen, accumulator)
        dependencies
  in

  let _, dependencies =
    visit
      String_set.empty
      []
      path
  in

  List.rev dependencies

(* ---------------------------------------------------------- *)
(* Environment resolution                                     *)
(* ---------------------------------------------------------- *)

let resolve_binding context binding =
  let path =
    match binding.Environment.kind with
    | Environment.Definition ->
        [binding.Environment.name]

    | Environment.Configuration ->
        binding.Environment.path
  in

  let resolved =
    resolve
      context
      path
  in

  match binding.Environment.kind with
  | Environment.Definition ->
      Environment.definition
        ~name:binding.Environment.name
        ~value:resolved.value
        ~span:binding.Environment.span

  | Environment.Configuration ->
      Environment.configuration
        ~path:binding.Environment.path
        ~value:resolved.value
        ~span:binding.Environment.span

let resolve_environment
    ?(maximum_depth = default_maximum_depth)
    environment =
  let original =
    create_context
      ~maximum_depth
      environment
  in

  Environment.bindings environment
  |> List.fold_left
       (fun resolved_environment binding ->
         let binding =
           resolve_binding
             original
             binding
         in

         match binding.Environment.kind with
         | Environment.Definition ->
             Environment.set_definition
               ~name:binding.Environment.name
               ~value:binding.Environment.value
               ~span:binding.Environment.span
               resolved_environment

         | Environment.Configuration ->
             Environment.set_configuration
               ~path:binding.Environment.path
               ~value:binding.Environment.value
               ~span:binding.Environment.span
               resolved_environment)
       Environment.empty

(* ---------------------------------------------------------- *)
(* Config resolution                                          *)
(* ---------------------------------------------------------- *)

let resolve_config
    ?(maximum_depth = default_maximum_depth)
    environment
    config =
  let environment =
    Environment.add_config
      config
      environment
  in

  let context =
    create_context
      ~maximum_depth
      environment
  in

  Config.fold
    (fun resolved_config entry ->
      let value =
        resolve_value
          context
          entry.Config.value
      in

      Config.set
        entry.Config.path
        value
        resolved_config)
    config
    (Config.empty ?filename:config.Config.filename ())

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let string_of_path path =
  Config.string_of_path path

let string_of_cycle paths =
  paths
  |> List.map string_of_path
  |> String.concat " -> "

let string_of_error = function
  | Empty_reference ->
      "reference path cannot be empty"

  | Undefined_reference path ->
      Printf.sprintf
        "undefined reference '%s'"
        (string_of_path path)

  | Reference_cycle paths ->
      Printf.sprintf
        "reference cycle detected: %s"
        (string_of_cycle paths)

  | Maximum_depth_exceeded
      {
        maximum;
        path;
      } ->
      Printf.sprintf
        "maximum reference resolution depth %d exceeded while resolving '%s'"
        maximum
        (string_of_path path)

let diagnostic_of_error
    ?span
    error =
  match error with
  | Empty_reference ->
      Error.to_diagnostic
        (Error.make
           ?span
           (Error.Undefined_reference ""))

  | Undefined_reference path ->
      Error.to_diagnostic
        (Error.make
           ?span
           (Error.Undefined_reference
              (string_of_path path)))

  | Reference_cycle paths ->
      Error.to_diagnostic
        (Error.make
           ?span
           (Error.Invalid_reference
              (string_of_cycle paths)))

  | Maximum_depth_exceeded
      {
        maximum;
        path;
      } ->
      Error.to_diagnostic
        (Error.make
           ?span
           (Error.Invalid_reference
              (Printf.sprintf
                 "maximum depth %d exceeded while resolving %s"
                 maximum
                 (string_of_path path))))

let collect_diagnostics
    ?(maximum_depth = default_maximum_depth)
    environment =
  let context =
    create_context
      ~maximum_depth
      environment
  in

  Environment.bindings environment
  |> List.fold_left
       (fun diagnostics binding ->
         let path =
           match binding.Environment.kind with
           | Environment.Definition ->
               [binding.Environment.name]

           | Environment.Configuration ->
               binding.Environment.path
         in

         try
           ignore
             (resolve context path);
           diagnostics
         with
         | Resolution_error error ->
             diagnostic_of_error
               ~span:binding.Environment.span
               error
             :: diagnostics)
       []
  |> List.rev

let analyze
    ?(maximum_depth = default_maximum_depth)
    environment =
  let diagnostics =
    collect_diagnostics
      ~maximum_depth
      environment
  in

  {
    environment;
    diagnostics;
  }

let has_errors result =
  List.exists
    (fun diagnostic ->
      diagnostic.Diagnostic.severity
      = Diagnostic.Error)
    result.diagnostics

let is_valid result =
  not (has_errors result)

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let string_of_source = function
  | Definition ->
      "definition"

  | Configuration ->
      "configuration"

let pp_source formatter source =
  Format.pp_print_string
    formatter
    (string_of_source source)

let pp_resolved formatter resolved =
  Format.fprintf
    formatter
    "@[<hov 2>%a %s = %a@]"
    pp_source
    resolved.source
    (string_of_path resolved.path)
    Value.pp
    resolved.value.Node.value

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

let pp formatter result =
  Format.fprintf
    formatter
    "@[<v>";

  List.iter
    (fun diagnostic ->
      Format.fprintf
        formatter
        "%a@,"
        Diagnostic.pp
        diagnostic)
    result.diagnostics;

  Format.fprintf
    formatter
    "@]"