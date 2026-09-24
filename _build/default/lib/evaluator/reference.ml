(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/evaluator/reference.ml
 *
 * Reference resolution for VFConf values.
 *
 * References use dotted paths:
 *
 *   $editor.font.size
 *   $terminal.shell
 *   $THEME
 *
 * Resolution supports configuration entries and named
 * definitions while detecting unresolved references and cycles.
 *)

module String_set = Set.Make (String)

type path = Statement.reference

type source =
  | Configuration
  | Definition

type resolved = {
  path : path;
  value : Value.t Node.t;
  source : source;
}

type error =
  | Empty_reference
  | Undefined_reference of path
  | Invalid_definition_reference of path
  | Reference_cycle of path list
  | Maximum_depth_exceeded of {
      maximum : int;
      path : path;
    }

exception Reference_error of error

type context = {
  config : Config.t;
  definitions : Value.t Node.t Evaluator.String_map.t;
  stack : path list;
  visited : String_set.t;
  maximum_depth : int;
}

let default_maximum_depth = 128

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let string_of_path path =
  String.concat "." path

let key_of_path path =
  string_of_path path

let valid_path path =
  match path with
  | [] ->
      false

  | components ->
      List.for_all
        (fun component ->
          component <> "")
        components

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

let create
    ?(maximum_depth = default_maximum_depth)
    ~config
    ~definitions
    () =
  {
    config;
    definitions;
    stack = [];
    visited = String_set.empty;
    maximum_depth;
  }

let of_environment
    ?maximum_depth
    ~config
    environment =
  create
    ?maximum_depth
    ~config
    ~definitions:environment.Evaluator.definitions
    ()

let depth context =
  List.length context.stack

let current_path context =
  match context.stack with
  | path :: _ ->
      Some path

  | [] ->
      None

(* ---------------------------------------------------------- *)
(* Stack                                                      *)
(* ---------------------------------------------------------- *)

let cycle_from_stack path stack =
  let rec collect accumulator = function
    | [] ->
        List.rev (path :: accumulator)

    | current :: rest ->
        if current = path then
          List.rev (path :: current :: accumulator)
        else
          collect (current :: accumulator) rest
  in

  collect [] stack

let push path context =
  if not (valid_path path) then
    raise
      (Reference_error Empty_reference);

  if depth context >= context.maximum_depth then
    raise
      (Reference_error
         (Maximum_depth_exceeded
            {
              maximum = context.maximum_depth;
              path;
            }));

  let key =
    key_of_path path
  in

  if String_set.mem key context.visited then
    raise
      (Reference_error
         (Reference_cycle
            (cycle_from_stack
               path
               context.stack)));

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
            (key_of_path path)
            context.visited;
      }

(* ---------------------------------------------------------- *)
(* Direct lookup                                              *)
(* ---------------------------------------------------------- *)

let find_config context path =
  match Config.find_opt path context.config with
  | None ->
      None

  | Some value ->
      Some
        {
          path;
          value;
          source = Configuration;
        }

let find_definition context path =
  match path with
  | [name] ->
      begin
        match
          Evaluator.String_map.find_opt
            name
            context.definitions
        with
        | None ->
            None

        | Some value ->
            Some
              {
                path;
                value;
                source = Definition;
              }
      end

  | [] ->
      None

  | _ ->
      None

let find_direct context path =
  match find_config context path with
  | Some resolved ->
      Some resolved

  | None ->
      find_definition
        context
        path

let exists context path =
  match find_direct context path with
  | Some _ ->
      true

  | None ->
      false

(* ---------------------------------------------------------- *)
(* Resolution                                                 *)
(* ---------------------------------------------------------- *)

let rec resolve_value context value =
  match value.Node.value with
  | Value.Reference path ->
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
              Value.key = entry.Value.key;
              value =
                resolve_value
                  context
                  entry.Value.value;
              span = entry.Value.span;
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

and resolve context path =
  if not (valid_path path) then
    raise
      (Reference_error Empty_reference);

  let context =
    push path context
  in

  match find_direct context path with
  | None ->
      raise
        (Reference_error
           (Undefined_reference path))

  | Some resolved ->
      let value =
        resolve_value
          context
          resolved.value
      in

      {
        resolved with
        value;
      }

let resolve_opt context path =
  try
    Some (resolve context path)
  with
  | Reference_error _ ->
      None

let resolve_value_opt context value =
  try
    Some (resolve_value context value)
  with
  | Reference_error _ ->
      None

(* ---------------------------------------------------------- *)
(* Bulk resolution                                            *)
(* ---------------------------------------------------------- *)

let resolve_entry context entry =
  {
    entry with
    Config.value =
      resolve_value
        context
        entry.Config.value;
  }

let resolve_config context =
  Config.fold
    (fun config entry ->
      let entry =
        resolve_entry
          context
          entry
      in

      Config.set_entry
        entry
        config)
    context.config
    (Config.empty
       ?filename:context.config.Config.filename
       ())

let resolve_all
    ?maximum_depth
    ~config
    ~environment
    () =
  let context =
    of_environment
      ?maximum_depth
      ~config
      environment
  in

  resolve_config context

(* ---------------------------------------------------------- *)
(* Dependency inspection                                      *)
(* ---------------------------------------------------------- *)

let rec references_of_value value =
  match value.Node.value with
  | Value.Reference path ->
      [path]

  | Value.Array values ->
      List.concat_map
        references_of_value
        values

  | Value.Object entries ->
      List.concat_map
        (fun entry ->
          references_of_value
            entry.Value.value)
        entries

  | Value.String _
  | Value.Integer _
  | Value.Float _
  | Value.Boolean _
  | Value.Null
  | Value.Color _
  | Value.Duration _
  | Value.Size _ ->
      []

let references_of_entry entry =
  references_of_value
    entry.Config.value

let dependencies config =
  Config.fold
    (fun dependencies entry ->
      let references =
        references_of_entry entry
      in

      (entry.Config.path, references)
      :: dependencies)
    config
    []
  |> List.rev

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let diagnostic_of_error ?span = function
  | Empty_reference ->
      Error.invalid_reference
        ?span
        ""
      |> Error.to_diagnostic

  | Undefined_reference path ->
      Error.undefined_reference
        ?span
        (string_of_path path)
      |> Error.to_diagnostic

  | Invalid_definition_reference path ->
      Error.invalid_reference
        ?span
        (string_of_path path)
      |> Error.to_diagnostic

  | Reference_cycle paths ->
      Error.invalid_reference
        ?span
        (Printf.sprintf
           "reference cycle: %s"
           (String.concat
              " -> "
              (List.map
                 string_of_path
                 paths)))
      |> Error.to_diagnostic

  | Maximum_depth_exceeded { maximum; path } ->
      Error.evaluation_failed
        ?span
        (Printf.sprintf
           "maximum reference resolution depth (%d) exceeded while resolving '$%s'"
           maximum
           (string_of_path path))
      |> Error.to_diagnostic

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Empty_reference ->
      "empty reference"

  | Undefined_reference path ->
      Printf.sprintf
        "undefined reference '$%s'"
        (string_of_path path)

  | Invalid_definition_reference path ->
      Printf.sprintf
        "invalid definition reference '$%s'"
        (string_of_path path)

  | Reference_cycle paths ->
      Printf.sprintf
        "reference cycle detected: %s"
        (String.concat
           " -> "
           (List.map
              (fun path ->
                "$" ^ string_of_path path)
              paths))

  | Maximum_depth_exceeded { maximum; path } ->
      Printf.sprintf
        "maximum reference resolution depth (%d) exceeded while resolving '$%s'"
        maximum
        (string_of_path path)

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)