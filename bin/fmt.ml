(*
 * VFConf - Vitte Foundation Configuration Language
 * fmt.ml
 *
 * VFConf formatter command-line frontend.
 *)

let version = "0.1.0"

type mode =
  | Write
  | Check
  | Stdout
  | Diff

let has_suffix value suffix =
  let value_len = String.length value in
  let suffix_len = String.length suffix in
  value_len >= suffix_len
  && String.sub value (value_len - suffix_len) suffix_len = suffix

let cli_error message =
  Printf.eprintf "vfconf-fmt: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-fmt: %s\n" message;
  exit 3

let validate_file filename =
  if not (has_suffix filename ".vf.conf") then
    cli_error ("expected a '.vf.conf' file: " ^ filename);

  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename)

let read_file filename =
  try
    let channel = open_in_bin filename in
    Fun.protect
      ~finally:(fun () -> close_in_noerr channel)
      (fun () ->
        really_input_string channel (in_channel_length channel))
  with
  | Sys_error message ->
      io_error message

let write_file filename contents =
  let directory =
    Filename.dirname filename
  in

  let basename =
    Filename.basename filename
  in

  let temporary =
    Filename.temp_file
      ~temp_dir:directory
      (basename ^ ".")
      ".tmp"
  in

  let committed =
    ref false
  in

  Fun.protect
    ~finally:(fun () ->
      if not !committed then
        try Sys.remove temporary
        with Sys_error _ -> ())
    (fun () ->
      try
        let channel =
          open_out_bin temporary
        in

        Fun.protect
          ~finally:(fun () -> close_out_noerr channel)
          (fun () ->
            output_string channel contents;
            flush channel);

        Unix.rename temporary filename;
        committed := true

      with
      | Sys_error message ->
          io_error message
      | Unix.Unix_error (error, function_name, argument) ->
          io_error
            (Printf.sprintf
               "%s: %s(%s)"
               (Unix.error_message error)
               function_name
               argument))

let format_source filename source =
  match Vfconf.Parse.string_result ~filename source with
  | Error error ->
      let diagnostic =
        Vfconf.Parse.diagnostic_of_error error
      in

      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        diagnostic;

      exit 1

  | Ok document ->
      Vfconf.Formatter.format document

let run_write filename source formatted =
  if source = formatted then
    Printf.printf "%s: already formatted\n" filename
  else begin
    write_file filename formatted;
    Printf.printf "%s: formatted\n" filename
  end

let run_check filename source formatted =
  if source = formatted then begin
    Printf.printf "%s: formatted\n" filename;
    exit 0
  end
  else begin
    Printf.eprintf "%s: requires formatting\n" filename;
    exit 1
  end

let run_stdout formatted =
  print_string formatted;
  flush stdout

let lines_of_string value =
  let lines = String.split_on_char '\n' value in
  match List.rev lines with
  | "" :: rest ->
      List.rev rest
  | _ ->
      lines

type diff_operation =
  | Equal_line of string
  | Delete_line of string
  | Insert_line of string

let diff_lines before after =
  let before = Array.of_list before in
  let after = Array.of_list after in

  let n = Array.length before in
  let m = Array.length after in

  let lcs =
    Array.make_matrix (n + 1) (m + 1) 0
  in

  for i = n - 1 downto 0 do
    for j = m - 1 downto 0 do
      if String.equal before.(i) after.(j) then
        lcs.(i).(j) <- lcs.(i + 1).(j + 1)
          + 1
      else
        lcs.(i).(j) <-
          max lcs.(i + 1).(j) lcs.(i).(j + 1)
    done
  done;

  let rec build i j acc =
    if i = n && j = m then
      List.rev acc

    else if i = n then
      build
        i
        (j + 1)
        (Insert_line after.(j) :: acc)

    else if j = m then
      build
        (i + 1)
        j
        (Delete_line before.(i) :: acc)

    else if String.equal before.(i) after.(j) then
      build
        (i + 1)
        (j + 1)
        (Equal_line before.(i) :: acc)

    else if lcs.(i + 1).(j) >= lcs.(i).(j + 1) then
      build
        (i + 1)
        j
        (Delete_line before.(i) :: acc)

    else
      build
        i
        (j + 1)
        (Insert_line after.(j) :: acc)
  in

  build 0 0 []

let count_before operations =
  List.fold_left
    (fun count -> function
      | Equal_line _
      | Delete_line _ ->
          count + 1
      | Insert_line _ ->
          count)
    0
    operations

let count_after operations =
  List.fold_left
    (fun count -> function
      | Equal_line _
      | Insert_line _ ->
          count + 1
      | Delete_line _ ->
          count)
    0
    operations

let print_diff filename source formatted =
  let operations =
    diff_lines
      (lines_of_string source)
      (lines_of_string formatted)
  in

  let old_count = count_before operations in
  let new_count = count_after operations in

  Printf.printf "--- %s\n" filename;
  Printf.printf "+++ %s (formatted)\n" filename;
  Printf.printf
    "@@ -1,%d +1,%d @@\n"
    old_count
    new_count;

  List.iter
    (function
      | Equal_line line ->
          Printf.printf " %s\n" line

      | Delete_line line ->
          Printf.printf "-%s\n" line

      | Insert_line line ->
          Printf.printf "+%s\n" line)
    operations;

  flush stdout

let run_diff filename source formatted =
  if String.equal source formatted then
    exit 0
  else begin
    print_diff filename source formatted;
    exit 1
  end

let run mode filename =
  validate_file filename;

  let source = read_file filename in
  let formatted = format_source filename source in

  match mode with
  | Write ->
      run_write filename source formatted

  | Check ->
      run_check filename source formatted

  | Stdout ->
      run_stdout formatted

  | Diff ->
      run_diff filename source formatted

let print_version () =
  Printf.printf "VFConf formatter %s\n" version;
  exit 0

let print_help () =
  Printf.printf
    "VFConf formatter\n\
     \n\
     Usage:\n\
     \  vfconf-fmt FILE.vf.conf\n\
     \  vfconf-fmt --write FILE.vf.conf\n\
     \  vfconf-fmt --check FILE.vf.conf\n\
     \  vfconf-fmt --stdout FILE.vf.conf\n\
     \  vfconf-fmt --diff FILE.vf.conf\n\
     \n\
     Options:\n\
     \  -w, --write     format file in place\n\
     \  -c, --check     check canonical formatting\n\
     \  --stdout        print formatted source to stdout\n\
     \  --diff          display formatting differences\n\
     \  -V, --version   display version\n\
     \  -h, --help      display help\n";
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"]
  | [_; "-help"] ->
      print_help ()

  | [_; "-V"]
  | [_; "--version"]
  | [_; "-version"] ->
      print_version ()

  | [_; filename] ->
      run Stdout filename

  | [_; "-w"; filename]
  | [_; "--write"; filename]
  | [_; "-write"; filename] ->
      run Write filename

  | [_; "-c"; filename]
  | [_; "--check"; filename]
  | [_; "-check"; filename] ->
      run Check filename

  | [_; "--stdout"; filename]
  | [_; "-stdout"; filename] ->
      run Stdout filename

  | [_; "--diff"; filename]
  | [_; "-diff"; filename] ->
      run Diff filename

  | _ ->
      Printf.eprintf
        "vfconf-fmt: invalid arguments\n\
         Try 'vfconf-fmt --help' for usage.\n";
      exit 2

let () =
  main ()
