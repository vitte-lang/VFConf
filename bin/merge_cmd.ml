let version = "0.1.0"

module Path_map =
  Map.Make (struct
    type t = string list
    let compare = Stdlib.compare
  end)

let cli_error message =
  Printf.eprintf "vfconf-merge: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-merge: %s\n" message;
  exit 3

let validate_file filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename)

let load_config filename =
  validate_file filename;

  try
    Vfconf.Loader.config_of_file filename
  with
  | Vfconf.Loader.Load_error error ->
      Printf.eprintf
        "vfconf-merge: %s: %s\n"
        filename
        (Vfconf.Loader.string_of_error error);
      exit 1

  | Sys_error message ->
      io_error message

let split_last path =
  match Stdlib.List.rev path with
  | [] ->
      None

  | key :: reversed_section ->
      Some
        (Stdlib.List.rev reversed_section, [key])

let add_entry groups entry =
  match split_last entry.Vfconf.Config.path with
  | None ->
      groups

  | Some (section, key) ->
      let assignment =
        Vfconf.Node.dummy
          (Vfconf.Statement.assignment
             key
             entry.Vfconf.Config.value)
      in

      let current =
        match Path_map.find_opt section groups with
        | Some statements ->
            statements
        | None ->
            []
      in

      Path_map.add
        section
        (assignment :: current)
        groups

let document_of_config config =
  let groups =
    Vfconf.Config.entries config
    |> Stdlib.List.fold_left add_entry Path_map.empty
  in

  Path_map.bindings groups
  |> Stdlib.List.concat_map
       (fun (section, reversed_body) ->
         let body =
           Stdlib.List.rev reversed_body
         in

         if section = [] then
           body
         else
           [
             Vfconf.Node.dummy
               (Vfconf.Statement.section
                  section
                  body);
           ])

let merge_configs configs =
  try
    Vfconf.Merge.merge_many configs
  with
  | Vfconf.Merge.Merge_error error ->
      Printf.eprintf
        "vfconf-merge: %s\n"
        (Vfconf.Merge.string_of_error error);
      exit 1

let run filenames =
  if Stdlib.List.length filenames < 2 then
    cli_error "at least two configuration files are required";

  let configs =
    Stdlib.List.map load_config filenames
  in

  let merged =
    merge_configs configs
  in

  let document =
    document_of_config merged
  in

  let output =
    Vfconf.Formatter.format document
  in

  begin
    match
      Vfconf.Parse.string_result
        ~filename:"<vfconf-merge>"
        output
    with
    | Ok _ ->
        ()

    | Error error ->
        let diagnostic =
          Vfconf.Parse.diagnostic_of_error error
        in
        Format.eprintf
          "%a@."
          Vfconf.Diagnostic.pp
          diagnostic;
        exit 7
  end;

  print_string output;
  exit 0

let print_help () =
  Printf.printf
    "VFConf configuration merge\n\
     \n\
     Usage:\n\
     \  vfconf-merge FILE1.vf.conf FILE2.vf.conf [FILE...]\n\
     \  vfconf-merge --help\n\
     \  vfconf-merge --version\n\
     \n\
     Later files override earlier files.\n";
  exit 0

let print_version () =
  Printf.printf "VFConf merge %s\n" version;
  exit 0

let main () =
  match Array.to_list Sys.argv with
  | [_; "--help"]
  | [_; "-h"] ->
      print_help ()

  | [_; "--version"]
  | [_; "-V"] ->
      print_version ()

  | _ :: filenames ->
      run filenames

  | [] ->
      cli_error
        "usage: vfconf-merge FILE1.vf.conf FILE2.vf.conf [FILE...]"

let () =
  main ()
