let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-eval: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-eval: %s\n" message;
  exit 3

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

let parse_document filename source =
  match Vfconf.Parse.string_result ~filename source with
  | Ok document ->
      document

  | Error error ->
      let diagnostic =
        Vfconf.Parse.diagnostic_of_error error
      in
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        diagnostic;
      exit 1

let evaluate_document filename document =
  try
    Vfconf.Evaluator.evaluate_document
      ~filename
      document
  with
  | Vfconf.Evaluator.Evaluation_error error ->
      let diagnostic =
        Vfconf.Evaluator.diagnostic_of_error error
      in
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        diagnostic;
      exit 5

let resolve_value state value =
  let config =
    Vfconf.Evaluator.config state
  in

  let environment =
    Vfconf.Evaluator.environment state
  in

  let context =
    Vfconf.Reference.of_environment
      ~config
      environment
  in

  try
    Vfconf.Reference.resolve_value
      context
      value
  with
  | Vfconf.Reference.Reference_error error ->
      let diagnostic =
        Vfconf.Reference.diagnostic_of_error
          ~span:value.Vfconf.Node.span
          error
      in
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        diagnostic;
      exit 6

let run path_string filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename);

  let path =
    Vfconf.Config.path_of_string path_string
  in

  if not (Vfconf.Config.valid_path path) then
    cli_error ("invalid configuration path: " ^ path_string);

  let source =
    read_file filename
  in

  let document =
    parse_document filename source
  in

  let state =
    evaluate_document filename document
  in

  let config =
    Vfconf.Evaluator.config state
  in

  match Vfconf.Config.find_opt path config with
  | None ->
      Printf.eprintf
        "vfconf-eval: path not found: %s\n"
        path_string;
      exit 1

  | Some value ->
      let value =
        resolve_value state value
      in

      print_endline
        (Vfconf.Formatter.format_value value);
      exit 0

let print_help () =
  Printf.printf
    "VFConf value evaluator\n\
     \n\
     Usage:\n\
     \  vfconf-eval PATH FILE.vf.conf\n\
     \  vfconf-eval --help\n\
     \  vfconf-eval --version\n\
     \n\
     Evaluates the configuration and prints the final value at PATH.\n";
  exit 0

let print_version () =
  Printf.printf "VFConf eval %s\n" version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "--help"]
  | [_; "-h"] ->
      print_help ()

  | [_; "--version"]
  | [_; "-V"] ->
      print_version ()

  | [_; path; filename] ->
      run path filename

  | _ ->
      cli_error "usage: vfconf-eval PATH FILE.vf.conf"

let () =
  main ()
