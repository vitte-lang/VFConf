let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-exists: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-exists: %s\n" message;
  exit 3

let validate_file filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename)

let load_config filename =
  try
    Vfconf.Loader.config_of_file filename
  with
  | Vfconf.Loader.Load_error error ->
      Printf.eprintf
        "vfconf-exists: %s\n"
        (Vfconf.Loader.string_of_error error);
      exit 1

  | Sys_error message ->
      io_error message

let run path_string filename =
  validate_file filename;

  let path =
    Vfconf.Config.path_of_string path_string
  in

  if not (Vfconf.Config.valid_path path) then
    cli_error ("invalid configuration path: " ^ path_string);

  let config =
    load_config filename
  in

  if Vfconf.Config.mem path config then begin
    print_endline "true";
    exit 0
  end else begin
    print_endline "false";
    exit 1
  end

let print_help () =
  Printf.printf
    "VFConf configuration path existence check\n\
     \n\
     Usage:\n\
     \  vfconf-exists PATH FILE.vf.conf\n\
     \  vfconf-exists --help\n\
     \  vfconf-exists --version\n";
  exit 0

let print_version () =
  Printf.printf "VFConf exists %s\n" version;
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
      cli_error "usage: vfconf-exists PATH FILE.vf.conf"

let () =
  main ()
