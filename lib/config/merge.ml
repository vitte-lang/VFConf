(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/merge.ml
 *
 * Configuration merge engine.
 *
 * Provides deterministic merging of Config.t values with explicit
 * conflict policies and optional recursive object/array merging.
 *)

type conflict_policy =
  | Keep_left
  | Keep_right
  | Error

type array_policy =
  | Replace_array
  | Append_array
  | Unique_array

type object_policy =
  | Replace_object
  | Merge_object

type options = {
  conflict : conflict_policy;
  arrays : array_policy;
  objects : object_policy;
}

type conflict = {
  path : Config.path;
  left : Value.t Node.t;
  right : Value.t Node.t;
}

type error =
  | Conflict of conflict
  | Invalid_value_merge of Config.path

exception Merge_error of error

let default_options =
  {
    conflict = Keep_right;
    arrays = Replace_array;
    objects = Merge_object;
  }

(* ---------------------------------------------------------- *)
(* Value helpers                                              *)
(* ---------------------------------------------------------- *)

let node value span =
  Node.located span value

let merged_span left right =
  Node.merge left right

let unique_values values =
  List.fold_left
    (fun result value ->
      if
        List.exists
          (fun existing ->
            Value.equal
              existing.Node.value
              value.Node.value)
          result
      then
        result
      else
        result @ [value])
    []
    values

(* ---------------------------------------------------------- *)
(* Object helpers                                             *)
(* ---------------------------------------------------------- *)

let object_key entry =
  Value.string_of_path entry.Value.key

let find_object_entry key entries =
  List.find_opt
    (fun entry ->
      String.equal
        (object_key entry)
        key)
    entries

let remove_object_entry key entries =
  List.filter
    (fun entry ->
      not
        (String.equal
           (object_key entry)
           key))
    entries

(* ---------------------------------------------------------- *)
(* Recursive value merge                                      *)
(* ---------------------------------------------------------- *)

let rec merge_value
    ?(path = [])
    options
    left
    right =
  match left.Node.value, right.Node.value with
  | Value.Object left_entries,
    Value.Object right_entries ->
      begin
        match options.objects with
        | Replace_object ->
            resolve_conflict
              ~path
              options
              left
              right

        | Merge_object ->
            let entries =
              merge_object_entries
                ~path
                options
                left_entries
                right_entries
            in

            node
              (Value.Object entries)
              (merged_span left right)
      end

  | Value.Array left_values,
    Value.Array right_values ->
      begin
        match options.arrays with
        | Replace_array ->
            resolve_conflict
              ~path
              options
              left
              right

        | Append_array ->
            node
              (Value.Array
                 (left_values @ right_values))
              (merged_span left right)

        | Unique_array ->
            node
              (Value.Array
                 (unique_values
                    (left_values @ right_values)))
              (merged_span left right)
      end

  | _ ->
      if Value.equal left.Node.value right.Node.value then
        right
      else
        resolve_conflict
          ~path
          options
          left
          right

and resolve_conflict
    ~path
    options
    left
    right =
  match options.conflict with
  | Keep_left ->
      left

  | Keep_right ->
      right

  | Error ->
      raise
        (Merge_error
           (Conflict
              {
                path;
                left;
                right;
              }))

and merge_object_entries
    ~path
    options
    left_entries
    right_entries =
  List.fold_left
    (fun result right_entry ->
      let key =
        object_key right_entry
      in

      match find_object_entry key result with
      | None ->
          result @ [right_entry]

      | Some left_entry ->
          let child_path =
            path @ right_entry.Value.key
          in

          let value =
            merge_value
              ~path:child_path
              options
              left_entry.Value.value
              right_entry.Value.value
          in

          let span =
            Node.merge_spans
              left_entry.Value.span
              right_entry.Value.span
          in

          let merged_entry =
            {
              Value.key = right_entry.Value.key;
              value;
              span;
            }
          in

          let without_old =
            remove_object_entry
              key
              result
          in

          without_old @ [merged_entry])
    left_entries
    right_entries

(* ---------------------------------------------------------- *)
(* Entry merge                                                *)
(* ---------------------------------------------------------- *)

let merge_entry
    options
    left
    right =
  if left.Config.path <> right.Config.path then
    invalid_arg
      "Merge.merge_entry: entries have different paths";

  let value =
    merge_value
      ~path:left.Config.path
      options
      left.Config.value
      right.Config.value
  in

  {
    Config.path = left.Config.path;
    value;
    span =
      Node.merge_spans
        left.Config.span
        right.Config.span;
  }

(* ---------------------------------------------------------- *)
(* Configuration merge                                        *)
(* ---------------------------------------------------------- *)

let merge
    ?(options = default_options)
    left
    right =
  Config.fold
    (fun config right_entry ->
      match
        Config.find_entry_opt
          right_entry.Config.path
          config
      with
      | None ->
          Config.set_entry
            right_entry
            config

      | Some left_entry ->
          let merged =
            merge_entry
              options
              left_entry
              right_entry
          in

          Config.set_entry
            merged
            config)
    right
    left

let merge_many
    ?(options = default_options)
    configs =
  match configs with
  | [] ->
      Config.empty ()

  | first :: rest ->
      List.fold_left
        (merge ~options)
        first
        rest

(* ---------------------------------------------------------- *)
(* Overlay                                                    *)
(* ---------------------------------------------------------- *)

let overlay left right =
  merge
    ~options:
      {
        conflict = Keep_right;
        arrays = Replace_array;
        objects = Replace_object;
      }
    left
    right

let preserve left right =
  merge
    ~options:
      {
        conflict = Keep_left;
        arrays = Replace_array;
        objects = Replace_object;
      }
    left
    right

let strict left right =
  merge
    ~options:
      {
        conflict = Error;
        arrays = Replace_array;
        objects = Merge_object;
      }
    left
    right

let deep left right =
  merge
    ~options:
      {
        conflict = Keep_right;
        arrays = Replace_array;
        objects = Merge_object;
      }
    left
    right

let deep_append left right =
  merge
    ~options:
      {
        conflict = Keep_right;
        arrays = Append_array;
        objects = Merge_object;
      }
    left
    right

let deep_unique left right =
  merge
    ~options:
      {
        conflict = Keep_right;
        arrays = Unique_array;
        objects = Merge_object;
      }
    left
    right

(* ---------------------------------------------------------- *)
(* Conflict inspection                                        *)
(* ---------------------------------------------------------- *)

let conflicts left right =
  Config.fold
    (fun result right_entry ->
      match
        Config.find_entry_opt
          right_entry.Config.path
          left
      with
      | None ->
          result

      | Some left_entry ->
          if
            Value.equal
              left_entry.Config.value.Node.value
              right_entry.Config.value.Node.value
          then
            result
          else
            {
              path = right_entry.Config.path;
              left = left_entry.Config.value;
              right = right_entry.Config.value;
            }
            :: result)
    right
    []
  |> List.rev

let has_conflicts left right =
  conflicts left right <> []

(* ---------------------------------------------------------- *)
(* Difference                                                 *)
(* ---------------------------------------------------------- *)

type difference =
  | Added of Config.entry
  | Removed of Config.entry
  | Changed of {
      path : Config.path;
      before : Config.entry;
      after : Config.entry;
    }

let diff left right =
  let removed_or_changed =
    Config.fold
      (fun result left_entry ->
        match
          Config.find_entry_opt
            left_entry.Config.path
            right
        with
        | None ->
            Removed left_entry :: result

        | Some right_entry ->
            if
              Value.equal
                left_entry.Config.value.Node.value
                right_entry.Config.value.Node.value
            then
              result
            else
              Changed
                {
                  path = left_entry.Config.path;
                  before = left_entry;
                  after = right_entry;
                }
              :: result)
      left
      []
  in

  let added =
    Config.fold
      (fun result right_entry ->
        if
          Config.mem
            right_entry.Config.path
            left
        then
          result
        else
          Added right_entry :: result)
      right
      []
  in

  List.rev
    (added @ removed_or_changed)

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_conflict conflict =
  Printf.sprintf
    "configuration conflict at '%s': %s <> %s"
    (Config.string_of_path conflict.path)
    (Value.to_string conflict.left.Node.value)
    (Value.to_string conflict.right.Node.value)

let string_of_error = function
  | Conflict conflict ->
      string_of_conflict conflict

  | Invalid_value_merge path ->
      Printf.sprintf
        "values cannot be merged at configuration path '%s'"
        (Config.string_of_path path)

let pp_conflict formatter conflict =
  Format.fprintf
    formatter
    "%s"
    (string_of_conflict conflict)

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

(* ---------------------------------------------------------- *)
(* Difference printing                                        *)
(* ---------------------------------------------------------- *)

let pp_difference formatter = function
  | Added entry ->
      Format.fprintf
        formatter
        "+ %s = %a"
        (Config.string_of_path entry.Config.path)
        Value.pp
        entry.Config.value.Node.value

  | Removed entry ->
      Format.fprintf
        formatter
        "- %s = %a"
        (Config.string_of_path entry.Config.path)
        Value.pp
        entry.Config.value.Node.value

  | Changed
      {
        path;
        before;
        after;
      } ->
      Format.fprintf
        formatter
        "~ %s: %a -> %a"
        (Config.string_of_path path)
        Value.pp
        before.Config.value.Node.value
        Value.pp
        after.Config.value.Node.value

let pp_diff formatter differences =
  Format.fprintf formatter "@[<v>";

  List.iteri
    (fun index difference ->
      if index > 0 then
        Format.fprintf formatter "@,";

      pp_difference
        formatter
        difference)
    differences;

  Format.fprintf formatter "@]"