(*
 * VFConf - Vitte Foundation Configuration Language
 * fmt_all.ml
 *
 * Recursive canonical formatter.
 *)

let version = "0.1.0"

type counters = {
  mutable files : int;
  mutable formatted : int;
  mutable unchanged : int;
  mutable invalid : int;
  mutable failed : int;
}

let counters () =
  {
    files = 0;
    formatted = 0;
    unchanged = 0;
    invalid = 0;
    failed = 0;
  }

let has_suffix value suffix =
  let value_len = String.length value in
  let suffix_len = String.length suffix in
  value_len >= suffix_len
  && String.sub value (value_len - suffix_len) suffix_len = suffix

let is_vfconf filename =
  has_suffix filename ".vf.conf"

let read_file filename =
  try
    let channel = open_in_bin filename in
    Fun.protect
      ~finally:(fun () -> close_in_noerr channel)
      (fun () ->
        Ok (really_input_string channel (in_channel_length channel)))
  with
  | Sys_error message ->
      Error message

let atomic_write filename contents =
  let directory = Filename.dirname filename in
  let basename = Filename.basename filename in

  try
    let temporary =
      Filename.temp_file
        ~temp_dir:directory
        (basename ^ ".")
        ".tmp"
    in

    let committed = ref false in

    Fun.protect
      ~finally:(fun () ->
        if not !committed then
          try Sys.remove temporary
          with Sys_error _ -> ())
      (fun () ->
        try
          let channel = open_out_bin temporary in

          Fun.protect
            ~finally:(fun () -> close_out_noerr channel)
            (fun () ->
              output_string channel contents;
              flush channel);

          Unix.rename temporary filename;
          committed := true;
          Ok ()

        with
        | Sys_error message ->
            Error message
        | Unix.Unix_error (error, function_name, argument) ->
            Error
              (Printf.sprintf
                 "%s: %s(%s)"
                 (Unix.error_message error)
                 function_name
                 argument))

  with
  | Sys_error message ->
      Error message

let rec collect path =
  if Sys.is_directory path then
    let names =
      Sys.readdir path
      |> Array.to_list
      |> List.sort String.compare
    in

    List.fold_left
      (fun files name ->
        let child = Filename.concat path name in
        files @ collect child)
      []
      names

  else if is_vfconf path then
    [path]

  else
    []

let process_file counts filename =
  counts.files <- counts.files + 1;

  match read_file filename with
  | Error message ->
      counts.failed <- counts.failed + 1;
      Printf.eprintf
        "%s: I/O error: %s\n"
        filename
        message

  | Ok source ->
      begin
        match Vfconf.Parse.string_result ~filename source with
        | Error error ->
            counts.invalid <- counts.invalid + 1;

            let diagnostic =
              Vfconf.Parse.diagnostic_of_error error
            in

            Format.eprintf
              "%a@."
              Vfconf.Diagnostic.pp
              diagnostic

        | Ok document ->
            let formatted =
              Vfconf.Formatter.format document
            in

            if String.equal source formatted then begin
              counts.unchanged <- counts.unchanged + 1;
              Printf.printf
                "%s: unchanged\n"
                filename
            end
            else
              match atomic_write filename formatted with
              | Ok () ->
                  counts.formatted <- counts.formatted + 1;
                  Printf.printf
                    "%s: formatted\n"
                    filename

              | Error message ->
                  counts.failed <- counts.failed + 1;
                  Printf.eprintf
                    "%s: I/O error: %s\n"
                    filename
                    message
      end

let print_summary counts =
  Printf.printf
    "\nVFConf fmt-all summary\n\
     Files:      %d\n\
     Formatted:  %d\n\
     Unchanged:  %d\n\
     Invalid:    %d\n\
     Failed:     %d\n"
    counts.files
    counts.formatted
    counts.unchanged
    counts.invalid
    counts.failed

let run path =
  if not (Sys.file_exists path) then begin
    Printf.eprintf
      "vfconf-fmt-all: path does not exist: %s\n"
      path;
    exit 3
  end;

  if not (Sys.is_directory path) && not (is_vfconf path) then begin
    Printf.eprintf
      "vfconf-fmt-all: expected directory or .vf.conf file: %s\n"
      path;
    exit 2
  end;

  let files =
    collect path
    |> List.sort String.compare
  in

  let counts = counters () in

  List.iter
    (process_file counts)
    files;

  print_summary counts;

  if counts.failed > 0 then
    exit 3
  else if counts.invalid > 0 then
    exit 1
  else
    exit 0

let print_help () =
  Printf.printf
    "VFConf recursive formatter\n\
     \n\
     Usage:\n\
     \  vfconf-fmt-all PATH\n\
     \  vfconf-fmt-all --help\n\
     \  vfconf-fmt-all --version\n\
     \n\
     PATH may be a directory or a .vf.conf file.\n";
  exit 0

let print_version () =
  Printf.printf
    "VFConf fmt-all %s\n"
    version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"] ->
      print_help ()

  | [_; "-V"]
  | [_; "--version"] ->
      print_version ()

  | [_; path] ->
      run path

  | [_] ->
      Printf.eprintf
        "vfconf-fmt-all: missing PATH\n";
      exit 2

  | _ ->
      Printf.eprintf
        "vfconf-fmt-all: invalid arguments\n";
      exit 2

let () =
  main ()
