let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-list: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-list: %s\n" message;
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
        "vfconf-list: %s\n"
        (Vfconf.Loader.string_of_error error);
      exit 1
  | Sys_error message ->
      io_error message

let compare_entries left right =
  String.compare
    (Vfconf.Config.string_of_path left.Vfconf.Config.path)
    (Vfconf.Config.string_of_path right.Vfconf.Config.path)

let print_entry entry =
  Printf.printf
    "%s = %s\n"
    (Vfconf.Config.string_of_path entry.Vfconf.Config.path)
    (Vfconf.Formatter.format_value entry.Vfconf.Config.value)

let run filename =
  validate_file filename;

  let config =
    load_config filename
  in

  let entries =
    Vfconf.Config.entries config
    |> List.sort compare_entries
  in

  List.iter print_entry entries;
  exit 0

let print_help () =
  Printf.printf
    "VFConf configuration listing\n\
     \n\
     Usage:\n\
     \  vfconf-list FILE.vf.conf\n\
     \  vfconf-list --help\n\
     \  vfconf-list --version\n";
  exit 0

let print_version () =
  Printf.printf "VFConf list %s\n" version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "--help"]
  | [_; "-h"] ->
      print_help ()

  | [_; "--version"]
  | [_; "-V"] ->
      print_version ()

  | [_; filename] ->
      run filename

  | _ ->
      cli_error "usage: vfconf-list FILE.vf.conf"

let () =
  main ()
