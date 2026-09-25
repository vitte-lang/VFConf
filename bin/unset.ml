let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-unset: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-unset: %s\n" message;
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

let atomic_write filename contents =
  let directory = Filename.dirname filename in
  let basename = Filename.basename filename in

  let temporary =
    try
      Filename.temp_file
        ~temp_dir:directory
        (basename ^ ".")
        ".tmp"
    with
    | Sys_error message ->
        io_error message
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

let remove_from_body prefix target body =
  let removed = ref false in

  let body =
    List.filter
      (fun statement ->
        match statement.Vfconf.Node.value with
        | Vfconf.Statement.Assignment assignment ->
            let full_path =
              prefix @ assignment.key
            in

            if full_path = target then begin
              removed := true;
              false
            end else
              true

        | _ ->
            true)
      body
  in

  body, !removed

let remove_path target document =
  let removed = ref false in

  let document =
    List.filter_map
      (fun statement ->
        match statement.Vfconf.Node.value with
        | Vfconf.Statement.Assignment assignment ->
            if assignment.key = target then begin
              removed := true;
              None
            end else
              Some statement

        | Vfconf.Statement.Section section ->
            let body, section_removed =
              remove_from_body
                section.name
                target
                section.body
            in

            if section_removed then
              removed := true;

            if section_removed && body = [] then
              None
            else if section_removed then
              Some
                (Vfconf.Node.replace
                   (Vfconf.Statement.Section
                      {
                        section with
                        body;
                      })
                   statement)
            else
              Some statement

        | _ ->
            Some statement)
      document
  in

  document, !removed

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

  let updated, removed =
    remove_path path document
  in

  if not removed then begin
    Printf.eprintf
      "vfconf-unset: path not found: %s\n"
      path_string;
    exit 1
  end;

  let formatted =
    Vfconf.Formatter.format updated
  in

  let _ =
    parse_document filename formatted
  in

  atomic_write filename formatted;

  Printf.printf
    "%s: removed %s\n"
    filename
    path_string;

  exit 0

let print_help () =
  Printf.printf
    "VFConf configuration unset\n\
     \n\
     Usage:\n\
     \  vfconf-unset PATH FILE.vf.conf\n\
     \  vfconf-unset --help\n\
     \  vfconf-unset --version\n";
  exit 0

let print_version () =
  Printf.printf "VFConf unset %s\n" version;
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
      cli_error "usage: vfconf-unset PATH FILE.vf.conf"

let () =
  main ()
