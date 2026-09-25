(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/schema/schema.ml
 *
 * Schema definition, composition and configuration validation.
 *)

module String_map = Map.Make (String)

type path = Config.path

type section = {
  path : path;
  description : string option;
  fields : Field.t String_map.t;
  allow_unknown_fields : bool;
}

type t = {
  name : string;
  version : string option;
  description : string option;
  sections : section String_map.t;
  rules : Rule.t list;
  allow_unknown_sections : bool;
}

type validation_result = {
  config : Config.t;
  violations : Rule.violation list;
  diagnostics : Diagnostic.t list;
}

type error =
  | Duplicate_section of path
  | Duplicate_field of {
      section : path;
      field : string;
    }
  | Unknown_section of path
  | Unknown_field of {
      section : path;
      field : string;
    }
  | Invalid_schema of string

exception Schema_error of error

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let root_key = ""

let path_key path =
  Config.string_of_path path

let field_path section field =
  section @ [field]

let split_field_path path =
  match List.rev path with
  | [] ->
      None

  | field :: reversed_section ->
      Some (List.rev reversed_section, field)

let path_starts_with prefix path =
  let rec loop prefix path =
    match prefix, path with
    | [], _ ->
        true

    | _, [] ->
        false

    | expected :: prefix, actual :: path ->
        String.equal expected actual
        && loop prefix path
  in

  loop prefix path

(* ---------------------------------------------------------- *)
(* Sections                                                   *)
(* ---------------------------------------------------------- *)

let make_section
    ?description
    ?(allow_unknown_fields = false)
    path =
  {
    path;
    description;
    fields = String_map.empty;
    allow_unknown_fields;
  }

let section_path (section : section) =
  section.path

let section_description (section : section) =
  section.description

let section_allows_unknown_fields (section : section) =
  section.allow_unknown_fields

let section_fields (section : section) =
  String_map.bindings section.fields
  |> List.map snd

let find_field (section : section) name =
  String_map.find_opt name section.fields

let mem_field (section : section) name =
  String_map.mem name section.fields

let add_field field (section : section) =
  let name =
    Field.name field
  in

  if String_map.mem name section.fields then
    raise
      (Schema_error
         (Duplicate_field
            {
              section = section.path;
              field = name;
            }));

  {
    section with
    fields =
      String_map.add
        name
        field
        section.fields;
  }

let add_fields fields section =
  List.fold_left
    (fun section field ->
      add_field field section)
    section
    fields

let set_field field (section : section) =
  {
    section with
    fields =
      String_map.add
        (Field.name field)
        field
        section.fields;
  }

let remove_field name (section : section) =
  {
    section with
    fields =
      String_map.remove
        name
        section.fields;
  }

let with_unknown_fields allowed (section : section) =
  {
    section with
    allow_unknown_fields = allowed;
  }

let with_section_description description (section : section) =
  {
    section with
    description = Some description;
  }

(* ---------------------------------------------------------- *)
(* Schema construction                                        *)
(* ---------------------------------------------------------- *)

let make
    ?version
    ?description
    ?(allow_unknown_sections = false)
    name =
  {
    name;
    version;
    description;
    sections = String_map.empty;
    rules = [];
    allow_unknown_sections;
  }

let empty =
  make "vfconf"

let name schema =
  schema.name

let version schema =
  schema.version

let description schema =
  schema.description

let allows_unknown_sections schema =
  schema.allow_unknown_sections

let with_version version schema =
  {
    schema with
    version = Some version;
  }

let with_description description schema =
  {
    schema with
    description = Some description;
  }

let with_unknown_sections allowed schema =
  {
    schema with
    allow_unknown_sections = allowed;
  }

(* ---------------------------------------------------------- *)
(* Schema sections                                            *)
(* ---------------------------------------------------------- *)

let find_section schema path =
  String_map.find_opt
    (path_key path)
    schema.sections

let mem_section schema path =
  String_map.mem
    (path_key path)
    schema.sections

let sections schema =
  String_map.bindings schema.sections
  |> List.map snd

let add_section section schema =
  let key =
    path_key section.path
  in

  if String_map.mem key schema.sections then
    raise
      (Schema_error
         (Duplicate_section section.path));

  {
    schema with
    sections =
      String_map.add
        key
        section
        schema.sections;
  }

let add_sections sections schema =
  List.fold_left
    (fun schema section ->
      add_section section schema)
    schema
    sections

let set_section section schema =
  {
    schema with
    sections =
      String_map.add
        (path_key section.path)
        section
        schema.sections;
  }

let remove_section path schema =
  {
    schema with
    sections =
      String_map.remove
        (path_key path)
        schema.sections;
  }

let ensure_section path schema =
  if mem_section schema path then
    schema
  else
    add_section
      (make_section path)
      schema

(* ---------------------------------------------------------- *)
(* Schema fields                                              *)
(* ---------------------------------------------------------- *)

let find_schema_field schema path =
  match split_field_path path with
  | None ->
      None

  | Some (section_path, field_name) ->
      begin
        match find_section schema section_path with
        | None ->
            None

        | Some section ->
            find_field
              section
              field_name
      end

let mem_schema_field schema path =
  Option.is_some
    (find_schema_field schema path)

let add_schema_field path field schema =
  match split_field_path path with
  | None ->
      raise
        (Schema_error
           (Invalid_schema
              "field path cannot be empty"))

  | Some (section_path, field_name) ->
      let field =
        if String.equal (Field.name field) field_name then
          field
        else
          {
            field with
            Field.name = field_name;
          }
      in

      let section =
        match find_section schema section_path with
        | Some section ->
            section

        | None ->
            make_section section_path
      in

      let section =
        add_field field section
      in

      set_section
        section
        schema

let set_schema_field path field schema =
  match split_field_path path with
  | None ->
      raise
        (Schema_error
           (Invalid_schema
              "field path cannot be empty"))

  | Some (section_path, field_name) ->
      let field =
        if String.equal (Field.name field) field_name then
          field
        else
          {
            field with
            Field.name = field_name;
          }
      in

      let section =
        match find_section schema section_path with
        | Some section ->
            section

        | None ->
            make_section section_path
      in

      set_section
        (set_field field section)
        schema

let remove_schema_field path schema =
  match split_field_path path with
  | None ->
      schema

  | Some (section_path, field_name) ->
      begin
        match find_section schema section_path with
        | None ->
            schema

        | Some section ->
            set_section
              (remove_field field_name section)
              schema
      end

(* ---------------------------------------------------------- *)
(* Rules                                                      *)
(* ---------------------------------------------------------- *)

let rules schema =
  schema.rules

let add_rule rule schema =
  {
    schema with
    rules =
      schema.rules @ [rule];
  }

let add_rules rules schema =
  {
    schema with
    rules =
      schema.rules @ rules;
  }

let clear_rules schema =
  {
    schema with
    rules = [];
  }

(* ---------------------------------------------------------- *)
(* Field validation                                           *)
(* ---------------------------------------------------------- *)

let violation_of_field_error
    path
    span
    error =
  Rule.violation
    ?span
    ~path
    ~rule:
      ("schema-field:"
       ^ Config.string_of_path path)
    (Field.string_of_validation_error error)

let validate_field
    config
    section
    field =
  let path =
    field_path
      section.path
      (Field.name field)
  in

  let entry =
    Config.find_entry_opt
      path
      config
  in

  let value =
    Option.map
      (fun entry ->
        entry.Config.value)
      entry
  in

  let span =
    Option.map
      (fun entry ->
        entry.Config.span)
      entry
  in

  Field.validate
    field
    value
  |> List.map
       (violation_of_field_error
          path
          span)

let validate_section_fields
    config
    section =
  section_fields section
  |> List.concat_map
       (validate_field
          config
          section)

(* ---------------------------------------------------------- *)
(* Unknown path validation                                    *)
(* ---------------------------------------------------------- *)

let section_for_entry schema entry =
  let rec search best = function
    | [] ->
        best

    | section :: rest ->
        if
          path_starts_with
            section.path
            entry.Config.path
          && List.length section.path
             < List.length entry.Config.path
        then
          let best =
            match best with
            | None ->
                Some section

            | Some current ->
                if
                  List.length section.path
                  > List.length current.path
                then
                  Some section
                else
                  best
          in
          search best rest
        else
          search best rest
  in

  search
    None
    (sections schema)

let relative_field_name section entry =
  let section_length =
    List.length section.path
  in

  let rec drop count values =
    if count <= 0 then
      values
    else
      match values with
      | [] ->
          []
      | _ :: rest ->
          drop (count - 1) rest
  in

  match drop section_length entry.Config.path with
  | [field] ->
      Some field

  | _ ->
      None

let unknown_entry_violation schema entry =
  match section_for_entry schema entry with
  | None ->
      if schema.allow_unknown_sections then
        None
      else
        Some
          (Rule.violation
             ~span:entry.Config.span
             ~path:entry.Config.path
             ~rule:"unknown-section"
             (Printf.sprintf
                "configuration path '%s' belongs to an unknown section"
                (Config.string_of_path
                   entry.Config.path)))

  | Some section ->
      if section.allow_unknown_fields then
        None
      else
        begin
          match relative_field_name section entry with
          | Some field_name
            when mem_field section field_name ->
              None

          | _ ->
              Some
                (Rule.violation
                   ~span:entry.Config.span
                   ~path:entry.Config.path
                   ~rule:"unknown-field"
                   (Printf.sprintf
                      "unknown configuration field '%s'"
                      (Config.string_of_path
                         entry.Config.path)))
        end

let validate_unknown_entries schema config =
  Config.entries config
  |> List.filter_map
       (unknown_entry_violation schema)

(* ---------------------------------------------------------- *)
(* Defaults                                                   *)
(* ---------------------------------------------------------- *)

let apply_field_default
    section
    config
    field =
  let path =
    field_path
      section.path
      (Field.name field)
  in

  if Config.mem path config then
    config
  else
    match Field.default field with
    | None ->
        config

    | Some value ->
        Config.set
          path
          value
          config

let apply_section_defaults
    section
    config =
  List.fold_left
    (apply_field_default section)
    config
    (section_fields section)

let apply_defaults schema config =
  List.fold_left
    (fun config section ->
      apply_section_defaults
        section
        config)
    config
    (sections schema)

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

let validate_without_defaults schema config =
  let field_violations =
    sections schema
    |> List.concat_map
         (validate_section_fields config)
  in

  let unknown_violations =
    validate_unknown_entries
      schema
      config
  in

  let rule_violations =
    Rule.validate_rules
      schema.rules
      config
  in

  let violations =
    field_violations
    @ unknown_violations
    @ rule_violations
  in

  {
    config;
    violations;
    diagnostics =
      Rule.diagnostics violations;
  }

let validate schema config =
  let config =
    apply_defaults
      schema
      config
  in

  validate_without_defaults
    schema
    config

let is_valid schema config =
  let result =
    validate schema config
  in

  not
    (Rule.has_errors
       result.violations)

let violations schema config =
  (validate schema config).violations

let diagnostics schema config =
  (validate schema config).diagnostics

(* ---------------------------------------------------------- *)
(* Schema validation                                          *)
(* ---------------------------------------------------------- *)

let validate_field_definition
    section
    field =
  Field.validate_default field
  |> List.map
       (fun error ->
         Invalid_schema
           (Printf.sprintf
              "%s.%s: %s"
              (Config.string_of_path section.path)
              (Field.name field)
              (Field.string_of_validation_error
                 error)))

let validate_definition schema =
  sections schema
  |> List.concat_map
       (fun section ->
         section_fields section
         |> List.concat_map
              (validate_field_definition
                 section))

let definition_is_valid schema =
  validate_definition schema = []

(* ---------------------------------------------------------- *)
(* Composition                                                *)
(* ---------------------------------------------------------- *)

let merge_section left right =
  let fields =
    String_map.union
      (fun _ _ right ->
        Some right)
      left.fields
      right.fields
  in

  {
    path = right.path;
    description =
      begin
        match right.description with
        | Some _ ->
            right.description

        | None ->
            left.description
      end;
    fields;
    allow_unknown_fields =
      right.allow_unknown_fields;
  }

let merge left right =
  let sections =
    String_map.union
      (fun _ left right ->
        Some
          (merge_section
             left
             right))
      left.sections
      right.sections
  in

  {
    name =
      if right.name <> "" then
        right.name
      else
        left.name;

    version =
      begin
        match right.version with
        | Some _ ->
            right.version

        | None ->
            left.version
      end;

    description =
      begin
        match right.description with
        | Some _ ->
            right.description

        | None ->
            left.description
      end;

    sections;

    rules =
      left.rules
      @ right.rules;

    allow_unknown_sections =
      right.allow_unknown_sections;
  }

let merge_many schemas =
  match schemas with
  | [] ->
      empty

  | first :: rest ->
      List.fold_left
        merge
        first
        rest

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Duplicate_section path ->
      Printf.sprintf
        "duplicate schema section '%s'"
        (Config.string_of_path path)

  | Duplicate_field { section; field } ->
      let section =
        Config.string_of_path section
      in

      if String.equal section "" then
        Printf.sprintf
          "duplicate schema field '%s'"
          field
      else
        Printf.sprintf
          "duplicate schema field '%s.%s'"
          section
          field

  | Unknown_section path ->
      Printf.sprintf
        "unknown schema section '%s'"
        (Config.string_of_path path)

  | Unknown_field { section; field } ->
      let section =
        Config.string_of_path section
      in

      if String.equal section "" then
        Printf.sprintf
          "unknown schema field '%s'"
          field
      else
        Printf.sprintf
          "unknown schema field '%s.%s'"
          section
          field

  | Invalid_schema message ->
      "invalid schema: " ^ message

(* ---------------------------------------------------------- *)
(* Canonical diagnostics                                      *)
(* ---------------------------------------------------------- *)

let diagnostic_of_error error =
  let canonical =
    match error with
    | Unknown_field { section; field } ->
        let path =
          field_path
            section
            field
          |> Config.string_of_path
        in

        Error.make
          (Error.Unknown_field path)

    | Duplicate_section path ->
        Error.make
          (Error.Schema_violation
             (Printf.sprintf
                "duplicate schema section '%s'"
                (Config.string_of_path path)))

    | Duplicate_field { section; field } ->
        let path =
          field_path
            section
            field
          |> Config.string_of_path
        in

        Error.make
          (Error.Schema_violation
             (Printf.sprintf
                "duplicate schema field '%s'"
                path))

    | Unknown_section path ->
        Error.make
          (Error.Schema_violation
             (Printf.sprintf
                "unknown schema section '%s'"
                (Config.string_of_path path)))

    | Invalid_schema message ->
        Error.make
          (Error.Schema_violation message)
  in

  Error.to_diagnostic canonical

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_section formatter section =
  Format.fprintf
    formatter
    "@[<v 2>[%s]"
    (Config.string_of_path section.path);

  begin
    match section.description with
    | None ->
        ()

    | Some description ->
        Format.fprintf
          formatter
          "@ description: %s"
          description
  end;

  List.iter
    (fun field ->
      Format.fprintf
        formatter
        "@ %a"
        Field.pp
        field)
    (section_fields section);

  Format.fprintf
    formatter
    "@]"

let pp formatter schema =
  Format.fprintf
    formatter
    "@[<v>schema %s"
    schema.name;

  begin
    match schema.version with
    | None ->
        ()

    | Some version ->
        Format.fprintf
          formatter
          " %s"
          version
  end;

  begin
    match schema.description with
    | None ->
        ()

    | Some description ->
        Format.fprintf
          formatter
          "@%s"
          description
  end;

  List.iter
    (fun section ->
      Format.fprintf
        formatter
        "@,@[%a@]"
        pp_section
        section)
    (sections schema);

  Format.fprintf
    formatter
    "@]"