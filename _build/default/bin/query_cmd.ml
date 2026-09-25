let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-query: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-query: %s\n" message;
  exit 3

let load_config filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename);

  try
    Vfconf.Loader.config_of_file filename
  with
  | Vfconf.Loader.Load_error error ->
      Printf.eprintf
        "vfconf-query: %s: %s\n"
        filename
        (Vfconf.Loader.string_of_error error);
      exit 1

  | Sys_error message ->
      io_error message

let run expression filename =
  let config =
    load_config filename
  in

  let entries =
    try
      Vfconf.Query.execute expression config
    with
    | Vfconf.Query.Query_error error ->
        cli_error
          (Vfconf.Query.string_of_error error)
  in

  match entries with
  | [] ->
      exit 1

  | [entry] ->
      print_endline
        (Vfconf.Formatter.format_value
           entry.Vfconf.Config.value);
      exit 0

  | entries ->
      List.iter
        (fun entry ->
          Printf.printf
            "%s = %s\n"
            (Vfconf.Config.string_of_path
               entry.Vfconf.Config.path)
            (Vfconf.Formatter.format_value
               entry.Vfconf.Config.value))
        entries;
      exit 0

let print_help () =
  Printf.printf
    "VFConf configuration query\n\
     \n\
     Usage:\n\
     \  vfconf-query EXPR FILE.vf.conf\n\
     \n\
     Query syntax:\n\
     \  language.id    exact path\n\
     \  build.*        one component wildcard\n\
     \  compiler.**    recursive wildcard\n\
     \  **.name        recursive name search\n\
     \  **             all entries\n";
  exit 0

let print_version () =
  Printf.printf "VFConf query %s\n" version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "--help"]
  | [_; "-h"] ->
      print_help ()

  | [_; "--version"]
  | [_; "-V"] ->
      print_version ()

  | [_; expression; filename] ->
      run expression filename

  | _ ->
      cli_error "usage: vfconf-query EXPR FILE.vf.conf"

let () =
  main ()
