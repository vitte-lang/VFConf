(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/include.ml
 *
 * Include path resolution and include-cycle protection.
 *
 * This module deliberately does not parse VFConf files.
 * Loading/parsing belongs to Loader. This module is responsible for:
 *
 *   - resolving relative include paths;
 *   - canonicalizing paths;
 *   - validating *.vf.conf files;
 *   - tracking the include stack;
 *   - detecting recursive includes;
 *   - enforcing a maximum include depth;
 *   - converting include failures to canonical diagnostics.
 *)

type path = string

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

type error =
  | Empty_path
  | Invalid_extension of path
  | File_not_found of path
  | Is_directory of path
  | Include_cycle of path list
  | Maximum_depth_exceeded of {
      maximum : int;
      path : path;
    }
  | Io_error of {
      path : path;
      message : string;
    }

exception Include_error of error

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

type context = {
  root : path;
  stack : path list;
  maximum_depth : int;
}

let default_maximum_depth = 64

(* ---------------------------------------------------------- *)
(* String helpers                                             *)
(* ---------------------------------------------------------- *)

let has_suffix value suffix =
  let value_length =
    String.length value
  in

  let suffix_length =
    String.length suffix
  in

  value_length >= suffix_length
  &&
  String.sub
    value
    (value_length - suffix_length)
    suffix_length
  = suffix

let is_vfconf_file path =
  has_suffix path ".vf.conf"

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

let is_absolute path =
  not (Filename.is_relative path)

let dirname path =
  Filename.dirname path

let basename path =
  Filename.basename path

let concat left right =
  Filename.concat left right

let normalize_components path =
  let absolute =
    is_absolute path
  in

  let components =
    String.split_on_char '/' path
  in

  let rec loop stack = function
    | [] ->
        List.rev stack

    | "" :: rest ->
        loop stack rest

    | "." :: rest ->
        loop stack rest

    | ".." :: rest ->
        begin
          match stack with
          | []
          | ".." :: _ ->
              if absolute then
                loop stack rest
              else
                loop (".." :: stack) rest

          | _ :: stack ->
              loop stack rest
        end

    | component :: rest ->
        loop
          (component :: stack)
          rest
  in

  let normalized =
    String.concat
      Filename.dir_sep
      (loop [] components)
  in

  if absolute then
    if String.equal normalized "" then
      Filename.dir_sep
    else
      Filename.dir_sep ^ normalized
  else if String.equal normalized "" then
    "."
  else
    normalized

let normalize path =
  normalize_components path

let absolute_path path =
  if is_absolute path then
    normalize path
  else
    normalize
      (Filename.concat
         (Sys.getcwd ())
         path)

let canonicalize path =
  (*
   * Unix.realpath is intentionally avoided here so the module
   * remains usable on platforms where only the standard OCaml
   * Filename/Sys APIs are available.
   *
   * Existing files are therefore canonicalized lexically.
   *)
  absolute_path path

(* ---------------------------------------------------------- *)
(* Filesystem validation                                      *)
(* ---------------------------------------------------------- *)

let validate_extension path =
  if not (is_vfconf_file path) then
    raise
      (Include_error
         (Invalid_extension path))

let validate_file path =
  if String.equal path "" then
    raise
      (Include_error Empty_path);

  validate_extension path;

  if not (Sys.file_exists path) then
    raise
      (Include_error
         (File_not_found path));

  if Sys.is_directory path then
    raise
      (Include_error
         (Is_directory path))

(* ---------------------------------------------------------- *)
(* Context construction                                       *)
(* ---------------------------------------------------------- *)

let create_context
    ?(maximum_depth = default_maximum_depth)
    root =
  if maximum_depth < 1 then
    invalid_arg
      "Include.create_context: maximum_depth must be positive";

  let root =
    canonicalize root
  in

  {
    root;
    stack = [];
    maximum_depth;
  }

let empty_context
    ?(maximum_depth = default_maximum_depth)
    () =
  create_context
    ~maximum_depth
    (Sys.getcwd ())

(* ---------------------------------------------------------- *)
(* Context inspection                                         *)
(* ---------------------------------------------------------- *)

let depth context =
  List.length context.stack

let current context =
  match context.stack with
  | path :: _ ->
      Some path
  | [] ->
      None

let root context =
  context.root

let stack context =
  List.rev context.stack

let maximum_depth context =
  context.maximum_depth

let contains path context =
  let path =
    canonicalize path
  in

  List.exists
    (String.equal path)
    context.stack

(* ---------------------------------------------------------- *)
(* Include resolution                                         *)
(* ---------------------------------------------------------- *)

let base_directory context =
  match current context with
  | Some current_file ->
      dirname current_file

  | None ->
      context.root

let resolve context include_path =
  if String.equal include_path "" then
    raise
      (Include_error Empty_path);

  let resolved =
    if is_absolute include_path then
      include_path
    else
      concat
        (base_directory context)
        include_path
  in

  canonicalize resolved

let resolve_from_file
    source_file
    include_path =
  if String.equal include_path "" then
    raise
      (Include_error Empty_path);

  let source_file =
    canonicalize source_file
  in

  let resolved =
    if is_absolute include_path then
      include_path
    else
      concat
        (dirname source_file)
        include_path
  in

  canonicalize resolved

(* ---------------------------------------------------------- *)
(* Cycle detection                                            *)
(* ---------------------------------------------------------- *)

let cycle_for path context =
  let path =
    canonicalize path
  in

  if not (contains path context) then
    None
  else
    let ordered =
      stack context
    in

    let rec collect = function
      | [] ->
          [path]

      | current :: rest ->
          if String.equal current path then
            current :: rest @ [path]
          else
            collect rest
    in

    Some (collect ordered)

let check_cycle path context =
  match cycle_for path context with
  | None ->
      ()

  | Some cycle ->
      raise
        (Include_error
           (Include_cycle cycle))

(* ---------------------------------------------------------- *)
(* Stack management                                           *)
(* ---------------------------------------------------------- *)

let push path context =
  let path =
    canonicalize path
  in

  validate_file path;
  check_cycle path context;

  let next_depth =
    depth context + 1
  in

  if next_depth > context.maximum_depth then
    raise
      (Include_error
         (Maximum_depth_exceeded
            {
              maximum = context.maximum_depth;
              path;
            }));

  {
    context with
    stack = path :: context.stack;
  }

let pop context =
  match context.stack with
  | [] ->
      context

  | _ :: rest ->
      {
        context with
        stack = rest;
      }

let enter context include_path =
  let path =
    resolve context include_path
  in

  let context =
    push path context
  in

  (path, context)

(* ---------------------------------------------------------- *)
(* Scoped include execution                                   *)
(* ---------------------------------------------------------- *)

let with_include
    context
    include_path
    function_ =
  let path, child_context =
    enter context include_path
  in

  function_
    child_context
    path

(* ---------------------------------------------------------- *)
(* File reading                                               *)
(* ---------------------------------------------------------- *)

let read_file path =
  let path =
    canonicalize path
  in

  validate_file path;

  try
    let channel =
      open_in_bin path
    in

    Fun.protect
      ~finally:(fun () ->
        close_in_noerr channel)
      (fun () ->
        let length =
          in_channel_length channel
        in

        really_input_string
          channel
          length)

  with
  | Sys_error message ->
      raise
        (Include_error
           (Io_error
              {
                path;
                message;
              }))

let resolve_and_read
    context
    include_path =
  let path =
    resolve context include_path
  in

  validate_file path;

  (path, read_file path)

(* ---------------------------------------------------------- *)
(* Canonical diagnostics                                      *)
(* ---------------------------------------------------------- *)

let diagnostic_of_error = function
  | Empty_path ->
      Error.make
        (Error.Invalid_include "")
      |> Error.to_diagnostic

  | Invalid_extension path ->
      Error.make
        (Error.Invalid_include path)
      |> Error.to_diagnostic

  | File_not_found path ->
      Error.make
        (Error.Include_not_found path)
      |> Error.to_diagnostic

  | Is_directory path ->
      Error.make
        (Error.Invalid_include path)
      |> Error.to_diagnostic

  | Include_cycle paths ->
      Error.make
        (Error.Include_cycle paths)
      |> Error.to_diagnostic

  | Maximum_depth_exceeded
      {
        maximum;
        path;
      } ->
      Error.make
        (Error.Include_depth_exceeded
           {
             maximum;
             path;
           })
      |> Error.to_diagnostic

  | Io_error { path; message } ->
      Error.make
        (Error.Cannot_read_file
           {
             path;
             message;
           })
      |> Error.to_diagnostic

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_cycle paths =
  String.concat
    " -> "
    paths

let string_of_error = function
  | Empty_path ->
      "empty include path"

  | Invalid_extension path ->
      Printf.sprintf
        "included file is not a VFConf file: %s"
        path

  | File_not_found path ->
      Printf.sprintf
        "included file not found: %s"
        path

  | Is_directory path ->
      Printf.sprintf
        "include path refers to a directory: %s"
        path

  | Include_cycle paths ->
      Printf.sprintf
        "recursive include detected: %s"
        (string_of_cycle paths)

  | Maximum_depth_exceeded { maximum; path } ->
      Printf.sprintf
        "maximum include depth (%d) exceeded while including: %s"
        maximum
        path

  | Io_error { path; message } ->
      Printf.sprintf
        "cannot read included file '%s': %s"
        path
        message

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

let pp_context formatter context =
  Format.fprintf
    formatter
    "@[<v>Include context:@,\
     root: %s@,\
     depth: %d/%d"
    context.root
    (depth context)
    context.maximum_depth;

  begin
    match stack context with
    | [] ->
        Format.fprintf
          formatter
          "@,stack: <empty>"

    | paths ->
        Format.fprintf
          formatter
          "@,stack:";

        List.iter
          (fun path ->
            Format.fprintf
              formatter
              "@,  %s"
              path)
          paths
  end;

  Format.fprintf
    formatter
    "@]"