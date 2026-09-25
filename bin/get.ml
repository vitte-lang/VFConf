let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-get: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-get: %s\n" message;
  exit 3

let validate_file filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename)

let run path_string filename =
  validate_file filename;

  let path =
    Vfconf.Config.path_of_string path_string
  in

  if not (Vfconf.Config.valid_path path) then
    cli_error ("invalid configuration path: " ^ path_string);

  let config =
    try
      Vfconf.Loader.config_of_file filename
    with
    | Vfconf.Loader.Load_error error ->
        Printf.eprintf
          "vfconf-get: %s\n"
          (Vfconf.Loader.string_of_error error);
        exit 1
    | Sys_error message ->
        io_error message
  in

  match Vfconf.Config.find_opt path config with
  | None ->
      Printf.eprintf
        "vfconf-get: path not found: %s\n"
        path_string;
      exit 1

  | Some value ->
      Printf.printf
        "%s\n"
        (Vfconf.Formatter.format_value value);
      exit 0

let print_help () =
  Printf.printf
    "VFConf configuration value reader\n\
     \n\
     Usage:\n\
     \  vfconf-get PATH FILE.vf.conf\n\
     \  vfconf-get --help\n\
     \  vfconf-get --version\n";
  exit 0

let print_version () =
  Printf.printf "VFConf get %s\n" version;
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
      cli_error "usage: vfconf-get PATH FILE.vf.conf"

let () =
  main ()
