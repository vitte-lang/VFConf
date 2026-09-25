let version = "0.1.0"

let cli_error message =
  Printf.eprintf "vfconf-set: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-set: %s\n" message;
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
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        (Vfconf.Parse.diagnostic_of_error error);
      exit 1

let parse_value text =
  let synthetic =
    "__vfconf_set_value = " ^ text ^ "\n"
  in
  match Vfconf.Parse.string_result
          ~filename:"<vfconf-set-value>"
          synthetic
  with
  | Error error ->
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        (Vfconf.Parse.diagnostic_of_error error);
      exit 2
  | Ok document ->
      begin
        match document with
        | [
            {
              Vfconf.Node.value =
                Vfconf.Statement.Assignment assignment;
              _;
            }
          ] ->
            assignment.value
        | _ ->
            cli_error "invalid VFConf value"
      end

let rec is_prefix prefix path =
  match prefix, path with
  | [], _ ->
      true
  | _, [] ->
      false
  | x :: xs, y :: ys ->
      String.equal x y && is_prefix xs ys

let drop_prefix prefix path =
  let rec loop prefix path =
    match prefix, path with
    | [], rest ->
        rest
    | _ :: prefix_rest, _ :: path_rest ->
        loop prefix_rest path_rest
    | _ ->
        path
  in
  loop prefix path

let replace_assignment_value assignment value =
  Vfconf.Statement.Assignment
    {
      assignment with
      value;
    }

let update_existing target value document =
  let changed = ref false in

  let update_body prefix body =
    List.map
      (fun statement ->
        match statement.Vfconf.Node.value with
        | Vfconf.Statement.Assignment assignment
          when prefix @ assignment.key = target ->
            changed := true;
            Vfconf.Node.replace
              (replace_assignment_value assignment value)
              statement
        | _ ->
            statement)
      body
  in

  let document =
    List.map
      (fun statement ->
        match statement.Vfconf.Node.value with
        | Vfconf.Statement.Assignment assignment
          when assignment.key = target ->
            changed := true;
            Vfconf.Node.replace
              (replace_assignment_value assignment value)
              statement

        | Vfconf.Statement.Section section ->
            let body =
              update_body section.name section.body
            in
            if body == section.body then
              statement
            else
              Vfconf.Node.replace
                (Vfconf.Statement.Section
                   {
                     section with
                     body;
                   })
                statement

        | _ ->
            statement)
      document
  in

  document, !changed

let longest_section_prefix target document =
  List.fold_left
    (fun best statement ->
      match statement.Vfconf.Node.value with
      | Vfconf.Statement.Section section
        when is_prefix section.name target
             && List.length section.name < List.length target ->
          begin
            match best with
            | None ->
                Some section.name
            | Some current
              when List.length section.name > List.length current ->
                Some section.name
            | Some _ ->
                best
          end
      | _ ->
          best)
    None
    document

let append_to_section section_path target value document =
  let relative_key =
    drop_prefix section_path target
  in

  List.map
    (fun statement ->
      match statement.Vfconf.Node.value with
      | Vfconf.Statement.Section section
        when section.name = section_path ->
          let assignment =
            Vfconf.Node.make
              (Vfconf.Statement.assignment
                 relative_key
                 value)
          in
          Vfconf.Node.replace
            (Vfconf.Statement.Section
               {
                 section with
                 body = section.body @ [assignment];
               })
            statement
      | _ ->
          statement)
    document

let split_last path =
  match List.rev path with
  | [] ->
      None
  | last :: reversed_prefix ->
      Some (List.rev reversed_prefix, last)

let create_path target value document =
  match longest_section_prefix target document with
  | Some section_path ->
      append_to_section
        section_path
        target
        value
        document

  | None ->
      begin
        match split_last target with
        | None ->
            document

        | Some ([], key) ->
            document
            @ [
                Vfconf.Node.make
                  (Vfconf.Statement.assignment
                     [key]
                     value);
              ]

        | Some (section_name, key) ->
            let assignment =
              Vfconf.Node.make
                (Vfconf.Statement.assignment
                   [key]
                   value)
            in
            document
            @ [
                Vfconf.Node.make
                  (Vfconf.Statement.section
                     section_name
                     [assignment]);
              ]
      end

let set_path target value document =
  let document, changed =
    update_existing target value document
  in
  if changed then
    document
  else
    create_path target value document

let run path_string value_string filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename);

  let path =
    Vfconf.Config.path_of_string path_string
  in

  if not (Vfconf.Config.valid_path path) then
    cli_error ("invalid configuration path: " ^ path_string);

  let value =
    parse_value value_string
  in

  let source =
    read_file filename
  in

  let document =
    parse_document filename source
  in

  let updated =
    set_path path value document
  in

  let formatted =
    Vfconf.Formatter.format updated
  in

  let _ =
    parse_document filename formatted
  in

  atomic_write filename formatted;

  Printf.printf
    "%s: set %s\n"
    filename
    path_string;

  exit 0

let print_help () =
  Printf.printf
    "VFConf configuration set\n\
     \n\
     Usage:\n\
     \  vfconf-set PATH VALUE FILE.vf.conf\n\
     \  vfconf-set --help\n\
     \  vfconf-set --version\n";
  exit 0

let print_version () =
  Printf.printf "VFConf set %s\n" version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "--help"]
  | [_; "-h"] ->
      print_help ()

  | [_; "--version"]
  | [_; "-V"] ->
      print_version ()

  | [_; path; value; filename] ->
      run path value filename

  | _ ->
      cli_error "usage: vfconf-set PATH VALUE FILE.vf.conf"

let () =
  main ()
