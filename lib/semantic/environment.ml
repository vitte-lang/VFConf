(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/semantic/environment.ml
 *
 * Semantic environment for configuration symbols, definitions
 * and lexical scopes.
 *)

module String_map = Map.Make (String)

type binding_kind =
  | Definition
  | Configuration

type binding = {
  name : string;
  path : Config.path;
  kind : binding_kind;
  value : Value.t Node.t;
  span : Node.span;
}

type scope = {
  name : string option;
  bindings : binding String_map.t;
}

type t = {
  scopes : scope list;
}

type error =
  | Duplicate_binding of string
  | Undefined_binding of string
  | Invalid_scope
  | Cannot_pop_root_scope

exception Environment_error of error

(* ---------------------------------------------------------- *)
(* Paths / keys                                               *)
(* ---------------------------------------------------------- *)

let path_key path =
  Config.string_of_path path

let key_of_binding binding =
  match binding.kind with
  | Definition ->
      "$" ^ binding.name

  | Configuration ->
      path_key binding.path

let key_of_definition name =
  "$" ^ name

let key_of_configuration path =
  path_key path

(* ---------------------------------------------------------- *)
(* Scopes                                                     *)
(* ---------------------------------------------------------- *)

let root_scope =
  {
    name = Some "root";
    bindings = String_map.empty;
  }

let empty =
  {
    scopes = [root_scope];
  }

let create () =
  empty

let depth environment =
  List.length environment.scopes

let current_scope environment =
  match environment.scopes with
  | scope :: _ ->
      scope

  | [] ->
      raise
        (Environment_error Invalid_scope)

let root environment =
  match List.rev environment.scopes with
  | scope :: _ ->
      scope

  | [] ->
      raise
        (Environment_error Invalid_scope)

let push_scope
    ?name
    environment =
  {
    scopes =
      {
        name;
        bindings = String_map.empty;
      }
      :: environment.scopes;
  }

let pop_scope environment =
  match environment.scopes with
  | [] ->
      raise
        (Environment_error Invalid_scope)

  | [_] ->
      raise
        (Environment_error Cannot_pop_root_scope)

  | _ :: rest ->
      {
        scopes = rest;
      }

let with_scope
    ?name
    environment
    f =
  let scoped =
    push_scope
      ?name
      environment
  in

  f scoped

(* ---------------------------------------------------------- *)
(* Binding construction                                       *)
(* ---------------------------------------------------------- *)

let definition
    ~name
    ~value
    ~span =
  {
    name;
    path = [name];
    kind = Definition;
    value;
    span;
  }

let configuration
    ~path
    ~value
    ~span =
  {
    name = path_key path;
    path;
    kind = Configuration;
    value;
    span;
  }

(* ---------------------------------------------------------- *)
(* Scope mutation                                             *)
(* ---------------------------------------------------------- *)

let replace_current_scope scope environment =
  match environment.scopes with
  | [] ->
      raise
        (Environment_error Invalid_scope)

  | _ :: rest ->
      {
        scopes = scope :: rest;
      }

let add_binding binding environment =
  let scope =
    current_scope environment
  in

  let key =
    key_of_binding binding
  in

  if String_map.mem key scope.bindings then
    raise
      (Environment_error
         (Duplicate_binding key));

  let scope =
    {
      scope with
      bindings =
        String_map.add
          key
          binding
          scope.bindings;
    }
  in

  replace_current_scope
    scope
    environment

let set_binding binding environment =
  let scope =
    current_scope environment
  in

  let key =
    key_of_binding binding
  in

  let scope =
    {
      scope with
      bindings =
        String_map.add
          key
          binding
          scope.bindings;
    }
  in

  replace_current_scope
    scope
    environment

let remove_binding key environment =
  let scope =
    current_scope environment
  in

  let scope =
    {
      scope with
      bindings =
        String_map.remove
          key
          scope.bindings;
    }
  in

  replace_current_scope
    scope
    environment

(* ---------------------------------------------------------- *)
(* Lookup                                                     *)
(* ---------------------------------------------------------- *)

let rec find_in_scopes key = function
  | [] ->
      None

  | scope :: rest ->
      begin
        match
          String_map.find_opt
            key
            scope.bindings
        with
        | Some binding ->
            Some binding

        | None ->
            find_in_scopes
              key
              rest
      end

let find_binding environment key =
  find_in_scopes
    key
    environment.scopes

let find_binding_exn environment key =
  match find_binding environment key with
  | Some binding ->
      binding

  | None ->
      raise
        (Environment_error
           (Undefined_binding key))

let mem_binding environment key =
  Option.is_some
    (find_binding environment key)

let find_definition environment name =
  find_binding
    environment
    (key_of_definition name)

let find_configuration environment path =
  find_binding
    environment
    (key_of_configuration path)

let mem_definition environment name =
  Option.is_some
    (find_definition environment name)

let mem_configuration environment path =
  Option.is_some
    (find_configuration environment path)

(* ---------------------------------------------------------- *)
(* Current-scope lookup                                       *)
(* ---------------------------------------------------------- *)

let find_current environment key =
  let scope =
    current_scope environment
  in

  String_map.find_opt
    key
    scope.bindings

let mem_current environment key =
  Option.is_some
    (find_current environment key)

let find_current_definition environment name =
  find_current
    environment
    (key_of_definition name)

let find_current_configuration environment path =
  find_current
    environment
    (key_of_configuration path)

(* ---------------------------------------------------------- *)
(* Definitions                                                *)
(* ---------------------------------------------------------- *)

let add_definition
    ~name
    ~value
    ~span
    environment =
  add_binding
    (definition
       ~name
       ~value
       ~span)
    environment

let set_definition
    ~name
    ~value
    ~span
    environment =
  set_binding
    (definition
       ~name
       ~value
       ~span)
    environment

let remove_definition name environment =
  remove_binding
    (key_of_definition name)
    environment

(* ---------------------------------------------------------- *)
(* Configuration bindings                                     *)
(* ---------------------------------------------------------- *)

let add_configuration
    ~path
    ~value
    ~span
    environment =
  add_binding
    (configuration
       ~path
       ~value
       ~span)
    environment

let set_configuration
    ~path
    ~value
    ~span
    environment =
  set_binding
    (configuration
       ~path
       ~value
       ~span)
    environment

let remove_configuration path environment =
  remove_binding
    (key_of_configuration path)
    environment

(* ---------------------------------------------------------- *)
(* Enumeration                                                *)
(* ---------------------------------------------------------- *)

let scope_bindings scope =
  String_map.bindings scope.bindings
  |> List.map snd

let current_bindings environment =
  scope_bindings
    (current_scope environment)

let bindings environment =
  let seen =
    Hashtbl.create 32
  in

  let rec collect accumulator = function
    | [] ->
        List.rev accumulator

    | scope :: rest ->
        let accumulator =
          String_map.fold
            (fun key binding accumulator ->
              if Hashtbl.mem seen key then
                accumulator
              else begin
                Hashtbl.add seen key ();
                binding :: accumulator
              end)
            scope.bindings
            accumulator
        in

        collect
          accumulator
          rest
  in

  collect
    []
    environment.scopes

let definitions environment =
  bindings environment
  |> List.filter
       (fun binding ->
         binding.kind = Definition)

let configurations environment =
  bindings environment
  |> List.filter
       (fun binding ->
         binding.kind = Configuration)

(* ---------------------------------------------------------- *)
(* Folding / iteration                                        *)
(* ---------------------------------------------------------- *)

let iter f environment =
  List.iter
    f
    (bindings environment)

let fold f environment initial =
  List.fold_left
    f
    initial
    (bindings environment)

(* ---------------------------------------------------------- *)
(* Import                                                     *)
(* ---------------------------------------------------------- *)

let of_config config =
  Config.fold
    (fun environment entry ->
      set_configuration
        ~path:entry.Config.path
        ~value:entry.Config.value
        ~span:entry.Config.span
        environment)
    config
    empty

let add_config config environment =
  Config.fold
    (fun environment entry ->
      set_configuration
        ~path:entry.Config.path
        ~value:entry.Config.value
        ~span:entry.Config.span
        environment)
    config
    environment

let of_analyzer_result result =
  List.fold_left
    (fun environment symbol ->
      match symbol.Analyzer.kind with
      | Analyzer.Definition ->
          set_definition
            ~name:symbol.Analyzer.name
            ~value:symbol.Analyzer.value
            ~span:symbol.Analyzer.span
            environment

      | Analyzer.Configuration ->
          set_configuration
            ~path:symbol.Analyzer.path
            ~value:symbol.Analyzer.value
            ~span:symbol.Analyzer.span
            environment)
    empty
    result.Analyzer.symbols

(* ---------------------------------------------------------- *)
(* Resolution                                                 *)
(* ---------------------------------------------------------- *)

let resolve_reference environment path =
  match path with
  | [name] ->
      begin
        match find_definition environment name with
        | Some binding ->
            Some binding

        | None ->
            find_configuration
              environment
              path
      end

  | _ ->
      find_configuration
        environment
        path

let resolve_reference_exn environment path =
  match resolve_reference environment path with
  | Some binding ->
      binding

  | None ->
      raise
        (Environment_error
           (Undefined_binding
              (path_key path)))

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let string_of_binding_kind = function
  | Definition ->
      "definition"

  | Configuration ->
      "configuration"

let string_of_error = function
  | Duplicate_binding name ->
      Printf.sprintf
        "duplicate binding '%s'"
        name

  | Undefined_binding name ->
      Printf.sprintf
        "undefined binding '%s'"
        name

  | Invalid_scope ->
      "invalid semantic environment scope"

  | Cannot_pop_root_scope ->
      "cannot pop the root semantic environment scope"

let pp_binding_kind formatter kind =
  Format.pp_print_string
    formatter
    (string_of_binding_kind kind)

let pp_binding formatter binding =
  Format.fprintf
    formatter
    "@[<hov 2>%a %s = %a@]"
    pp_binding_kind
    binding.kind
    binding.name
    Value.pp
    binding.value.Node.value

let pp_scope formatter scope =
  let name =
    match scope.name with
    | None ->
        "<anonymous>"

    | Some name ->
        name
  in

  Format.fprintf
    formatter
    "@[<v 2>scope %s"
    name;

  List.iter
    (fun binding ->
      Format.fprintf
        formatter
        "@,%a"
        pp_binding
        binding)
    (scope_bindings scope);

  Format.fprintf
    formatter
    "@]"

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

let pp formatter environment =
  Format.fprintf
    formatter
    "@[<v>";

  List.iter
    (fun scope ->
      Format.fprintf
        formatter
        "%a@,"
        pp_scope
        scope)
    (List.rev environment.scopes);

  Format.fprintf
    formatter
    "@]"