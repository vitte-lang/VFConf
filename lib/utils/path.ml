(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/utils/path.ml
 *
 * Portable path manipulation utilities.
 *)

type t = string

type error =
  | Empty_path
  | Invalid_path of string
  | Outside_root of {
      root : string;
      path : string;
    }

exception Path_error of error

let separator =
  Filename.dir_sep

let vfconf_extension =
  ".vf.conf"

(* ---------------------------------------------------------- *)
(* Basic properties                                           *)
(* ---------------------------------------------------------- *)

let is_empty path =
  String.equal path ""

let is_absolute =
  fun path -> not (Filename.is_relative path)

let is_relative =
  Filename.is_relative

let basename =
  Filename.basename

let dirname =
  Filename.dirname

let concat =
  Filename.concat

let join parts =
  match parts with
  | [] ->
      ""

  | first :: rest ->
      List.fold_left
        Filename.concat
        first
        rest

let parent path =
  let result =
    Filename.dirname path
  in

  if String.equal result path then
    None
  else
    Some result

(* ---------------------------------------------------------- *)
(* String helpers                                             *)
(* ---------------------------------------------------------- *)

let has_prefix string prefix =
  let string_length =
    String.length string
  in
  let prefix_length =
    String.length prefix
  in
  string_length >= prefix_length
  && String.equal
       (String.sub string 0 prefix_length)
       prefix

let has_suffix string suffix =
  let string_length =
    String.length string
  in
  let suffix_length =
    String.length suffix
  in
  string_length >= suffix_length
  && String.equal
       (String.sub
          string
          (string_length - suffix_length)
          suffix_length)
       suffix

(* ---------------------------------------------------------- *)
(* Components                                                 *)
(* ---------------------------------------------------------- *)

let split path =
  let length =
    String.length path
  in

  let is_separator character =
    character = '/'
    || character = '\\'
  in

  let rec skip_separators index =
    if index < length && is_separator path.[index] then
      skip_separators (index + 1)
    else
      index
  in

  let rec find_separator index =
    if index >= length || is_separator path.[index] then
      index
    else
      find_separator (index + 1)
  in

  let rec loop index accumulator =
    let index =
      skip_separators index
    in

    if index >= length then
      List.rev accumulator
    else
      let finish =
        find_separator index
      in
      let component =
        String.sub path index (finish - index)
      in
      loop finish (component :: accumulator)
  in

  loop 0 []

let components =
  split

let component_count path =
  List.length (split path)

(* ---------------------------------------------------------- *)
(* Normalization                                              *)
(* ---------------------------------------------------------- *)

let normalize_components components =
  let rec loop accumulator = function
    | [] ->
        List.rev accumulator

    | "" :: rest
    | "." :: rest ->
        loop accumulator rest

    | ".." :: rest ->
        begin
          match accumulator with
          | component :: tail
            when not (String.equal component "..") ->
              loop tail rest

          | _ ->
              loop (".." :: accumulator) rest
        end

    | component :: rest ->
        loop (component :: accumulator) rest
  in

  loop [] components

let normalize path =
  if String.equal path "" then
    "."
  else
    let absolute =
      not (Filename.is_relative path)
    in

    let components =
      normalize_components (split path)
    in

    let body =
      String.concat separator components
    in

    if absolute then
      if String.equal body "" then
        separator
      else
        separator ^ body
    else if String.equal body "" then
      "."
    else
      body

let canonicalize path =
  let path =
    if Filename.is_relative path then
      Filename.concat
        (Sys.getcwd ())
        path
    else
      path
  in
  normalize path

let absolute path =
  canonicalize path

(* ---------------------------------------------------------- *)
(* Extension                                                  *)
(* ---------------------------------------------------------- *)

let extension path =
  let name =
    basename path
  in

  match String.rindex_opt name '.' with
  | None ->
      None

  | Some 0 ->
      None

  | Some index ->
      Some
        (String.sub
           name
           index
           (String.length name - index))

let remove_extension path =
  let directory =
    dirname path
  in
  let name =
    basename path
  in

  let result_name =
    match String.rindex_opt name '.' with
    | None
    | Some 0 ->
        name

    | Some index ->
        String.sub name 0 index
  in

  if String.equal directory "." then
    result_name
  else
    Filename.concat directory result_name

let replace_extension path extension =
  remove_extension path ^ extension

let has_extension path extension =
  has_suffix
    (basename path)
    extension

let is_vfconf path =
  has_suffix
    (basename path)
    vfconf_extension

let remove_vfconf_extension path =
  if is_vfconf path then
    String.sub
      path
      0
      (String.length path - String.length vfconf_extension)
  else
    path

let with_vfconf_extension path =
  if is_vfconf path then
    path
  else
    path ^ vfconf_extension

(* ---------------------------------------------------------- *)
(* Relative paths                                             *)
(* ---------------------------------------------------------- *)

let drop_common_prefix left right =
  let rec loop left right =
    match left, right with
    | left_head :: left_tail,
      right_head :: right_tail
      when String.equal left_head right_head ->
        loop left_tail right_tail

    | _ ->
        (left, right)
  in
  loop left right

let relative
    ~from
    target =
  let from =
    canonicalize from
  in
  let target =
    canonicalize target
  in

  let from_components =
    split from
  in
  let target_components =
    split target
  in

  let remaining_from, remaining_target =
    drop_common_prefix
      from_components
      target_components
  in

  let parents =
    List.map
      (fun _ -> "..")
      remaining_from
  in

  let result =
    parents @ remaining_target
  in

  match result with
  | [] ->
      "."

  | _ ->
      String.concat separator result

let resolve
    ~base
    path =
  if Filename.is_relative path then
    normalize
      (Filename.concat base path)
  else
    normalize path

(* ---------------------------------------------------------- *)
(* Root containment                                           *)
(* ---------------------------------------------------------- *)

let components_equal_prefix prefix path =
  let rec loop prefix path =
    match prefix, path with
    | [], _ ->
        true

    | _, [] ->
        false

    | left :: left_rest,
      right :: right_rest ->
        String.equal left right
        && loop left_rest right_rest
  in

  loop prefix path

let is_within
    ~root
    path =
  let root =
    canonicalize root
  in
  let path =
    canonicalize path
  in

  components_equal_prefix
    (split root)
    (split path)

let ensure_within
    ~root
    path =
  let root =
    canonicalize root
  in
  let path =
    canonicalize path
  in

  if is_within ~root path then
    path
  else
    raise
      (Path_error
         (Outside_root
            {
              root;
              path;
            }))

(* ---------------------------------------------------------- *)
(* Filesystem helpers                                         *)
(* ---------------------------------------------------------- *)

let exists =
  Sys.file_exists

let is_file path =
  try
    (Unix.stat path).Unix.st_kind = Unix.S_REG
  with
  | Unix.Unix_error _ ->
      false

let is_directory path =
  try
    (Unix.stat path).Unix.st_kind = Unix.S_DIR
  with
  | Unix.Unix_error _ ->
      false

let realpath path =
  try
    Unix.realpath path
  with
  | Unix.Unix_error _ ->
      canonicalize path

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

let is_valid path =
  not (String.equal path "")
  && not (String.contains path '\000')

let validate path =
  if String.equal path "" then
    Error Empty_path
  else if String.contains path '\000' then
    Error (Invalid_path path)
  else
    Ok ()

let require_valid path =
  match validate path with
  | Ok () ->
      ()

  | Error error ->
      raise
        (Path_error error)

(* ---------------------------------------------------------- *)
(* Comparison                                                 *)
(* ---------------------------------------------------------- *)

let equal left right =
  String.equal
    (normalize left)
    (normalize right)

let compare left right =
  String.compare
    (normalize left)
    (normalize right)

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let to_string path =
  path

let of_string path =
  require_valid path;
  path

let string_of_error = function
  | Empty_path ->
      "path cannot be empty"

  | Invalid_path path ->
      Printf.sprintf
        "invalid path: %S"
        path

  | Outside_root
      {
        root;
        path;
      } ->
      Printf.sprintf
        "path %S is outside root %S"
        path
        root

let pp formatter path =
  Format.pp_print_string
    formatter
    path

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)