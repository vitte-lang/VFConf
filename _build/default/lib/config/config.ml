(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/config.ml
 *
 * Runtime representation of a loaded VFConf configuration.
 *)

module String_map = Map.Make (String)

type path = string list

(* ---------------------------------------------------------- *)
(* Configuration entries                                      *)
(* ---------------------------------------------------------- *)

type entry = {
  path : path;
  value : Value.t Node.t;
  span : Node.span;
}

(* ---------------------------------------------------------- *)
(* Configuration                                              *)
(* ---------------------------------------------------------- *)

type t = {
  filename : string option;
  entries : entry String_map.t;
}

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

type error =
  | Duplicate_key of path
  | Missing_key of path
  | Invalid_path of path

exception Config_error of error

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

let path_separator = "."

let string_of_path path =
  String.concat path_separator path

let path_of_string value =
  if String.equal value "" then
    []
  else
    String.split_on_char '.' value

let valid_path path =
  path <> []
  &&
  List.for_all
    (fun component ->
      not (String.equal component ""))
    path

let normalize_path path =
  List.filter
    (fun component ->
      not (String.equal component ""))
    path

let key_of_path path =
  string_of_path path

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let empty ?filename () =
  {
    filename;
    entries = String_map.empty;
  }

let is_empty config =
  String_map.is_empty config.entries

let length config =
  String_map.cardinal config.entries

(* ---------------------------------------------------------- *)
(* Entry construction                                         *)
(* ---------------------------------------------------------- *)

let entry
    ?span
    path
    value =
  let span =
    match span with
    | Some span ->
        span
    | None ->
        value.Node.span
  in

  {
    path;
    value;
    span;
  }

(* ---------------------------------------------------------- *)
(* Lookup                                                     *)
(* ---------------------------------------------------------- *)

let find_entry_opt path config =
  if not (valid_path path) then
    None
  else
    String_map.find_opt
      (key_of_path path)
      config.entries

let find_opt path config =
  match find_entry_opt path config with
  | None ->
      None

  | Some entry ->
      Some entry.value

let find_value_opt path config =
  match find_opt path config with
  | None ->
      None

  | Some value ->
      Some value.Node.value

let mem path config =
  match find_entry_opt path config with
  | Some _ ->
      true
  | None ->
      false

let find_entry path config =
  match find_entry_opt path config with
  | Some entry ->
      entry

  | None ->
      raise
        (Config_error
           (Missing_key path))

let find path config =
  (find_entry path config).value

let find_value path config =
  (find path config).Node.value

(* ---------------------------------------------------------- *)
(* Modification                                               *)
(* ---------------------------------------------------------- *)

let add_entry entry config =
  if not (valid_path entry.path) then
    raise
      (Config_error
         (Invalid_path entry.path));

  let key =
    key_of_path entry.path
  in

  if String_map.mem key config.entries then
    raise
      (Config_error
         (Duplicate_key entry.path));

  {
    config with
    entries =
      String_map.add
        key
        entry
        config.entries;
  }

let add
    ?span
    path
    value
    config =
  add_entry
    (entry ?span path value)
    config

let set_entry entry config =
  if not (valid_path entry.path) then
    raise
      (Config_error
         (Invalid_path entry.path));

  {
    config with
    entries =
      String_map.add
        (key_of_path entry.path)
        entry
        config.entries;
  }

let set
    ?span
    path
    value
    config =
  set_entry
    (entry ?span path value)
    config

let remove path config =
  {
    config with
    entries =
      String_map.remove
        (key_of_path path)
        config.entries;
  }

(* ---------------------------------------------------------- *)
(* Update                                                     *)
(* ---------------------------------------------------------- *)

let update
    path
    function_
    config =
  let current =
    find_opt path config
  in

  match function_ current with
  | None ->
      remove path config

  | Some value ->
      set path value config

(* ---------------------------------------------------------- *)
(* Iteration                                                  *)
(* ---------------------------------------------------------- *)

let iter function_ config =
  String_map.iter
    (fun _ entry ->
      function_ entry)
    config.entries

let fold function_ config initial =
  String_map.fold
    (fun _ entry accumulator ->
      function_ accumulator entry)
    config.entries
    initial

let entries config =
  String_map.bindings config.entries
  |> List.map snd

let paths config =
  fold
    (fun accumulator entry ->
      entry.path :: accumulator)
    config
    []
  |> List.rev

let values config =
  fold
    (fun accumulator entry ->
      entry.value :: accumulator)
    config
    []
  |> List.rev

(* ---------------------------------------------------------- *)
(* Filtering                                                  *)
(* ---------------------------------------------------------- *)

let filter predicate config =
  {
    config with
    entries =
      String_map.filter
        (fun _ entry ->
          predicate entry)
        config.entries;
  }

let filter_map function_ config =
  let entries =
    String_map.fold
      (fun key entry accumulator ->
        match function_ entry with
        | None ->
            accumulator

        | Some entry ->
            String_map.add
              key
              entry
              accumulator)
      config.entries
      String_map.empty
  in

  {
    config with
    entries;
  }

(* ---------------------------------------------------------- *)
(* Sections                                                   *)
(* ---------------------------------------------------------- *)

let path_has_prefix prefix path =
  let rec loop prefix path =
    match prefix, path with
    | [], _ ->
        true

    | _, [] ->
        false

    | prefix_head :: prefix_tail,
      path_head :: path_tail ->
        String.equal prefix_head path_head
        && loop prefix_tail path_tail
  in

  loop prefix path

let section prefix config =
  filter
    (fun entry ->
      path_has_prefix prefix entry.path)
    config

let direct_section prefix config =
  let prefix_length =
    List.length prefix
  in

  filter
    (fun entry ->
      path_has_prefix prefix entry.path
      && List.length entry.path = prefix_length + 1)
    config

(* ---------------------------------------------------------- *)
(* Merge                                                      *)
(* ---------------------------------------------------------- *)

let merge
    ?(override = true)
    left
    right =
  let entries =
    String_map.fold
      (fun key entry accumulator ->
        if
          (not override)
          && String_map.mem key accumulator
        then
          accumulator
        else
          String_map.add
            key
            entry
            accumulator)
      right.entries
      left.entries
  in

  {
    filename =
      begin
        match right.filename with
        | Some _ ->
            right.filename
        | None ->
            left.filename
      end;
    entries;
  }

(* ---------------------------------------------------------- *)
(* Conversion                                                 *)
(* ---------------------------------------------------------- *)

let of_entries
    ?filename
    entries =
  List.fold_left
    (fun config entry ->
      add_entry entry config)
    (empty ?filename ())
    entries

let to_entries config =
  entries config

(* ---------------------------------------------------------- *)
(* Typed access                                               *)
(* ---------------------------------------------------------- *)

let get_string path config =
  match find_value_opt path config with
  | Some (Value.String value) ->
      Some value
  | _ ->
      None

let get_integer path config =
  match find_value_opt path config with
  | Some (Value.Integer value) ->
      Some value
  | _ ->
      None

let get_float path config =
  match find_value_opt path config with
  | Some (Value.Float value) ->
      Some value

  | Some (Value.Integer value) ->
      Some (Int64.to_float value)

  | _ ->
      None

let get_boolean path config =
  match find_value_opt path config with
  | Some (Value.Boolean value) ->
      Some value
  | _ ->
      None

let get_array path config =
  match find_value_opt path config with
  | Some (Value.Array values) ->
      Some values
  | _ ->
      None

let get_object path config =
  match find_value_opt path config with
  | Some (Value.Object entries) ->
      Some entries
  | _ ->
      None

let get_reference path config =
  match find_value_opt path config with
  | Some (Value.Reference reference) ->
      Some reference
  | _ ->
      None

let get_color path config =
  match find_value_opt path config with
  | Some (Value.Color color) ->
      Some color
  | _ ->
      None

let get_duration path config =
  match find_value_opt path config with
  | Some (Value.Duration (value, unit)) ->
      Some (value, unit)
  | _ ->
      None

let get_size path config =
  match find_value_opt path config with
  | Some (Value.Size (value, unit)) ->
      Some (value, unit)
  | _ ->
      None

(* ---------------------------------------------------------- *)
(* Default values                                             *)
(* ---------------------------------------------------------- *)

let get_string_or
    ~default
    path
    config =
  match get_string path config with
  | Some value ->
      value
  | None ->
      default

let get_integer_or
    ~default
    path
    config =
  match get_integer path config with
  | Some value ->
      value
  | None ->
      default

let get_float_or
    ~default
    path
    config =
  match get_float path config with
  | Some value ->
      value
  | None ->
      default

let get_boolean_or
    ~default
    path
    config =
  match get_boolean path config with
  | Some value ->
      value
  | None ->
      default

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_entry formatter entry =
  Format.fprintf
    formatter
    "%s = %a"
    (string_of_path entry.path)
    Value.pp
    entry.value.Node.value

let pp formatter config =
  let all_entries =
    entries config
  in

  Format.fprintf formatter "@[<v>";

  List.iteri
    (fun index entry ->
      if index > 0 then
        Format.fprintf formatter "@,";

      pp_entry formatter entry)
    all_entries;

  Format.fprintf formatter "@]"

let to_string config =
  Format.asprintf
    "%a"
    pp
    config

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Duplicate_key path ->
      Printf.sprintf
        "duplicate configuration key: %s"
        (string_of_path path)

  | Missing_key path ->
      Printf.sprintf
        "missing configuration key: %s"
        (string_of_path path)

  | Invalid_path path ->
      Printf.sprintf
        "invalid configuration path: %s"
        (string_of_path path)

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

let dump formatter config =
  Format.fprintf
    formatter
    "VFConf.Config";

  begin
    match config.filename with
    | None ->
        ()

    | Some filename ->
        Format.fprintf
          formatter
          "(%S)"
          filename
  end;

  Format.fprintf formatter "@.";

  iter
    (fun entry ->
      Format.fprintf
        formatter
        "  %s = %a [%a]@."
        (string_of_path entry.path)
        Value.pp
        entry.value.Node.value
        Node.pp_span
        entry.span)
    config