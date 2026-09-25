let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-diff: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-diff: %s\n" message;
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
        "vfconf-diff: %s: %s\n"
        filename
        (Vfconf.Loader.string_of_error error);
      exit 1

  | Sys_error message ->
      io_error message

let run left_filename right_filename =
  validate_file left_filename;
  validate_file right_filename;

  let left =
    load_config left_filename
  in

  let right =
    load_config right_filename
  in

  let differences =
    Vfconf.Merge.diff left right
  in

  match differences with
  | [] ->
      exit 0

  | _ ->
      Format.printf
        "%a@."
        Vfconf.Merge.pp_diff
        differences;
      exit 1

let print_help () =
  Printf.printf
    "VFConf semantic configuration diff\n\
     \n\
     Usage:\n\
     \  vfconf-diff FILE1.vf.conf FILE2.vf.conf\n\
     \  vfconf-diff --help\n\
     \  vfconf-diff --version\n\
     \n\
     Exit status:\n\
     \  0  configurations are equal\n\
     \  1  configurations differ or are invalid\n\
     \  2  invalid command line\n\
     \  3  I/O error\n";
  exit 0

let print_version () =
  Printf.printf "VFConf diff %s\n" version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "--help"]
  | [_; "-h"] ->
      print_help ()

  | [_; "--version"]
  | [_; "-V"] ->
      print_version ()

  | [_; left_filename; right_filename] ->
      run left_filename right_filename

  | _ ->
      cli_error
        "usage: vfconf-diff FILE1.vf.conf FILE2.vf.conf"

let () =
  main ()
