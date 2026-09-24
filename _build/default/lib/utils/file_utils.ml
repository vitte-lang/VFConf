(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/utils/file_utils.ml
 *
 * Portable filesystem and file I/O utilities.
 *)

type error =
  | Not_found of string
  | Not_a_file of string
  | Not_a_directory of string
  | Already_exists of string
  | Permission_denied of string
  | Io_error of {
      path : string;
      message : string;
    }

exception File_error of error

(* ---------------------------------------------------------- *)
(* Error handling                                             *)
(* ---------------------------------------------------------- *)

let classify_sys_error path message =
  let lower =
    String.lowercase_ascii message
  in

  if
    String.contains lower 'p'
    && (
      String.starts_with
        ~prefix:"permission denied"
        lower
      || String.ends_with
           ~suffix:"permission denied"
           lower
    )
  then
    Permission_denied path
  else
    Io_error
      {
        path;
        message;
      }

let protect_sys_error path function_ =
  try
    function_ ()
  with
  | Sys_error message ->
      raise
        (File_error
           (classify_sys_error
              path
              message))

(* ---------------------------------------------------------- *)
(* Existence and kind                                         *)
(* ---------------------------------------------------------- *)

let exists path =
  Sys.file_exists path

let stat_opt path =
  try
    Some (Unix.stat path)
  with
  | Unix.Unix_error
      ( (Unix.ENOENT | Unix.ENOTDIR),
        _,
        _ ) ->
      None

  | Unix.Unix_error
      (error, function_name, argument) ->
      raise
        (File_error
           (Io_error
              {
                path;
                message =
                  Printf.sprintf
                    "%s(%s): %s"
                    function_name
                    argument
                    (Unix.error_message error);
              }))

let is_file path =
  match stat_opt path with
  | Some stats ->
      stats.Unix.st_kind
      = Unix.S_REG

  | None ->
      false

let is_directory path =
  match stat_opt path with
  | Some stats ->
      stats.Unix.st_kind
      = Unix.S_DIR

  | None ->
      false

let is_symlink path =
  try
    (Unix.lstat path).Unix.st_kind
    = Unix.S_LNK
  with
  | Unix.Unix_error
      ( (Unix.ENOENT | Unix.ENOTDIR),
        _,
        _ ) ->
      false

  | Unix.Unix_error
      (error, function_name, argument) ->
      raise
        (File_error
           (Io_error
              {
                path;
                message =
                  Printf.sprintf
                    "%s(%s): %s"
                    function_name
                    argument
                    (Unix.error_message error);
              }))

let require_exists path =
  if not (exists path) then
    raise
      (File_error
         (Not_found path))

let require_file path =
  require_exists path;

  if not (is_file path) then
    raise
      (File_error
         (Not_a_file path))

let require_directory path =
  require_exists path;

  if not (is_directory path) then
    raise
      (File_error
         (Not_a_directory path))

(* ---------------------------------------------------------- *)
(* File reading                                               *)
(* ---------------------------------------------------------- *)

let read_all channel =
  let buffer =
    Buffer.create 4096
  in

  let chunk =
    Bytes.create 4096
  in

  let rec loop () =
    let count =
      input
        channel
        chunk
        0
        (Bytes.length chunk)
    in

    if count > 0 then begin
      Buffer.add_subbytes
        buffer
        chunk
        0
        count;

      loop ()
    end
  in

  loop ();
  Buffer.contents buffer

let with_input_file path function_ =
  require_file path;

  let channel =
    protect_sys_error
      path
      (fun () ->
        open_in_bin path)
  in

  match function_ channel with
  | value ->
      close_in_noerr channel;
      value

  | exception exn ->
      close_in_noerr channel;
      raise exn

let read_file path =
  with_input_file
    path
    read_all

let read_lines path =
  with_input_file
    path
    (fun channel ->
      let rec loop accumulator =
        match input_line channel with
        | line ->
            loop
              (line :: accumulator)

        | exception End_of_file ->
            List.rev accumulator
      in

      loop [])

(* ---------------------------------------------------------- *)
(* File writing                                               *)
(* ---------------------------------------------------------- *)

let ensure_parent_directory path =
  let parent =
    Filename.dirname path
  in

  if
    not (String.equal parent ".")
    && not (String.equal parent path)
  then
    require_directory parent

let with_output_file
    ?(append = false)
    path
    function_ =
  ensure_parent_directory path;

  let flags =
    if append then
      [
        Open_wronly;
        Open_creat;
        Open_binary;
        Open_append;
      ]
    else
      [
        Open_wronly;
        Open_creat;
        Open_binary;
        Open_trunc;
      ]
  in

  let channel =
    protect_sys_error
      path
      (fun () ->
        open_out_gen
          flags
          0o666
          path)
  in

  match function_ channel with
  | value ->
      flush channel;
      close_out_noerr channel;
      value

  | exception exn ->
      close_out_noerr channel;
      raise exn

let write_file path contents =
  with_output_file
    path
    (fun channel ->
      output_string
        channel
        contents)

let append_file path contents =
  with_output_file
    ~append:true
    path
    (fun channel ->
      output_string
        channel
        contents)

let write_lines path lines =
  with_output_file
    path
    (fun channel ->
      List.iter
        (fun line ->
          output_string channel line;
          output_char channel '\n')
        lines)

(* ---------------------------------------------------------- *)
(* Atomic writing                                             *)
(* ---------------------------------------------------------- *)

let temporary_path path =
  let directory =
    Filename.dirname path
  in

  let basename =
    Filename.basename path
  in

  let temporary =
    Printf.sprintf
      ".%s.%d.tmp"
      basename
      (Unix.getpid ())
  in

  Filename.concat
    directory
    temporary

let write_file_atomic path contents =
  ensure_parent_directory path;

  let temporary =
    temporary_path path
  in

  let cleanup () =
    if exists temporary then
      try
        Sys.remove temporary
      with
      | Sys_error _ ->
          ()
  in

  try
    write_file
      temporary
      contents;

    protect_sys_error
      path
      (fun () ->
        Sys.rename
          temporary
          path)
  with
  | exn ->
      cleanup ();
      raise exn

(* ---------------------------------------------------------- *)
(* Directories                                                *)
(* ---------------------------------------------------------- *)

let create_directory
    ?(permissions = 0o755)
    path =
  if exists path then begin
    if is_directory path then
      ()
    else
      raise
        (File_error
           (Already_exists path))
  end
  else
    try
      Unix.mkdir
        path
        permissions
    with
    | Unix.Unix_error
        (error, function_name, argument) ->
        raise
          (File_error
             (Io_error
                {
                  path;
                  message =
                    Printf.sprintf
                      "%s(%s): %s"
                      function_name
                      argument
                      (Unix.error_message error);
                }))

let rec create_directories
    ?(permissions = 0o755)
    path =
  if
    String.equal path ""
    || String.equal path "."
    || String.equal path Filename.current_dir_name
  then
    ()
  else if exists path then begin
    if not (is_directory path) then
      raise
        (File_error
           (Not_a_directory path))
  end
  else begin
    let parent =
      Filename.dirname path
    in

    if not (String.equal parent path) then
      create_directories
        ~permissions
        parent;

    create_directory
      ~permissions
      path
  end

let list_directory path =
  require_directory path;

  protect_sys_error
    path
    (fun () ->
      Sys.readdir path
      |> Array.to_list
      |> List.filter
           (fun name ->
             not
               (String.equal name "."
                || String.equal name ".."))
      |> List.sort String.compare)

let list_directory_paths path =
  list_directory path
  |> List.map
       (Filename.concat path)

let list_files path =
  list_directory_paths path
  |> List.filter is_file

let list_directories path =
  list_directory_paths path
  |> List.filter is_directory

(* ---------------------------------------------------------- *)
(* Recursive traversal                                        *)
(* ---------------------------------------------------------- *)

let rec walk_files path =
  if is_file path then
    [path]
  else begin
    require_directory path;

    list_directory_paths path
    |> List.fold_left
         (fun accumulator child ->
           if is_directory child then
             List.rev_append
               (walk_files child)
               accumulator
           else if is_file child then
             child :: accumulator
           else
             accumulator)
         []
    |> List.rev
  end

let find_files
    ?(recursive = true)
    predicate
    path =
  let files =
    if recursive then
      walk_files path
    else
      list_files path
  in

  List.filter
    predicate
    files

(* ---------------------------------------------------------- *)
(* VFConf helpers                                             *)
(* ---------------------------------------------------------- *)

let vfconf_extension =
  ".vf.conf"

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

let is_vfconf_file path =
  is_file path
  && has_suffix
       (Filename.basename path)
       vfconf_extension

let find_vfconf_files
    ?(recursive = true)
    path =
  find_files
    ~recursive
    is_vfconf_file
    path

(* ---------------------------------------------------------- *)
(* Copy / rename / remove                                     *)
(* ---------------------------------------------------------- *)

let copy_file
    ?(overwrite = false)
    source
    destination =
  require_file source;

  if exists destination && not overwrite then
    raise
      (File_error
         (Already_exists destination));

  ensure_parent_directory destination;

  let contents =
    read_file source
  in

  write_file
    destination
    contents

let rename
    ?(overwrite = false)
    source
    destination =
  require_exists source;

  if exists destination && not overwrite then
    raise
      (File_error
         (Already_exists destination));

  ensure_parent_directory destination;

  protect_sys_error
    source
    (fun () ->
      Sys.rename
        source
        destination)

let remove_file path =
  require_file path;

  protect_sys_error
    path
    (fun () ->
      Sys.remove path)

let rec remove_tree path =
  if not (exists path) then
    ()
  else if is_directory path && not (is_symlink path) then begin
    list_directory_paths path
    |> List.iter remove_tree;

    try
      Unix.rmdir path
    with
    | Unix.Unix_error
        (error, function_name, argument) ->
        raise
          (File_error
             (Io_error
                {
                  path;
                  message =
                    Printf.sprintf
                      "%s(%s): %s"
                      function_name
                      argument
                      (Unix.error_message error);
                }))
  end
  else
    protect_sys_error
      path
      (fun () ->
        Sys.remove path)

(* ---------------------------------------------------------- *)
(* Metadata                                                   *)
(* ---------------------------------------------------------- *)

let file_size path =
  require_file path;

  (Unix.stat path).Unix.st_size

let modification_time path =
  require_exists path;

  (Unix.stat path).Unix.st_mtime

let permissions path =
  require_exists path;

  (Unix.stat path).Unix.st_perm

let set_permissions path permissions =
  require_exists path;

  try
    Unix.chmod
      path
      permissions
  with
  | Unix.Unix_error
      (error, function_name, argument) ->
      raise
        (File_error
           (Io_error
              {
                path;
                message =
                  Printf.sprintf
                    "%s(%s): %s"
                    function_name
                    argument
                    (Unix.error_message error);
              }))

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Not_found path ->
      Printf.sprintf
        "file or directory not found: %s"
        path

  | Not_a_file path ->
      Printf.sprintf
        "not a regular file: %s"
        path

  | Not_a_directory path ->
      Printf.sprintf
        "not a directory: %s"
        path

  | Already_exists path ->
      Printf.sprintf
        "file or directory already exists: %s"
        path

  | Permission_denied path ->
      Printf.sprintf
        "permission denied: %s"
        path

  | Io_error
      {
        path;
        message;
      } ->
      Printf.sprintf
        "%s: %s"
        path
        message

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)