(*
 * VFConf - Vitte Foundation Configuration Language
 * bin/check_all.ml
 *
 * Recursive VFConf configuration checker.
 *)

let has_suffix value suffix =
  let value_length = String.length value in
  let suffix_length = String.length suffix in
  value_length >= suffix_length
  &&
  String.sub
    value
    (value_length - suffix_length)
    suffix_length
  = suffix

let rec collect_files path =
  if not (Sys.file_exists path) then begin
    Printf.eprintf
      "vfconf-check-all: %s: path does not exist\n"
      path;
    exit 3
  end;

  if Sys.is_directory path then
    Sys.readdir path
    |> Array.to_list
    |> List.sort String.compare
    |> List.concat_map
         (fun name ->
           collect_files
             (Filename.concat path name))
  else if has_suffix path ".vf.conf" then
    [path]
  else
    []

let run_checker filename =
  match
    Unix.create_process
      "vfconf-check"
      [| "vfconf-check"; filename |]
      Unix.stdin
      Unix.stdout
      Unix.stderr
  with
  | pid ->
      begin
        match snd (Unix.waitpid [] pid) with
        | Unix.WEXITED code ->
            code

        | Unix.WSIGNALED signal ->
            Printf.eprintf
              "vfconf-check-all: checker terminated by signal %d: %s\n"
              signal
              filename;
            7

        | Unix.WSTOPPED signal ->
            Printf.eprintf
              "vfconf-check-all: checker stopped by signal %d: %s\n"
              signal
              filename;
            7
      end

  | exception Unix.Unix_error
      (Unix.ENOENT, _, _) ->
      Printf.eprintf
        "vfconf-check-all: vfconf-check not found\n";
      exit 7

  | exception Unix.Unix_error
      (error, _, _) ->
      Printf.eprintf
        "vfconf-check-all: cannot execute vfconf-check: %s\n"
        (Unix.error_message error);
      exit 7

let run path =
  let files =
    collect_files path
  in

  if files = [] then begin
    Printf.printf
      "VFConf: no .vf.conf files found in %s\n"
      path;
    exit 0
  end;

  let valid = ref 0 in
  let invalid = ref 0 in
  let failures = ref 0 in

  List.iter
    (fun filename ->
      match run_checker filename with
      | 0 ->
          incr valid

      | 1 ->
          incr invalid

      | _ ->
          incr failures)
    files;

  Printf.printf
    "\nVFConf check-all summary\n\
     Files:   %d\n\
     Valid:   %d\n\
     Invalid: %d\n\
     Failed:  %d\n"
    (List.length files)
    !valid
    !invalid
    !failures;

  if !failures > 0 then
    exit 3
  else if !invalid > 0 then
    exit 1
  else
    exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"] ->
      print_string
        "Usage: vfconf-check-all [PATH]\n"

  | [_] ->
      run "."

  | [_; path] ->
      run path

  | _ ->
      Printf.eprintf
        "vfconf-check-all: invalid arguments\n";
      exit 2

let () =
  main ()
