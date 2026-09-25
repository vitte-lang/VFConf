let version = "0.1.0"

module Path_map =
  Map.Make (struct
    type t = string list
    let compare = Stdlib.compare
  end)

let cli_error message =
  Printf.eprintf "vfconf-resolve: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-resolve: %s\n" message;
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
    |> Stdlib.List.fold_left
         add_entry
         Path_map.empty
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

let resolve state =
  let config =
    Vfconf.Evaluator.config state
  in

  let environment =
    Vfconf.Evaluator.environment state
  in

  try
    Vfconf.Reference.resolve_all
      ~config
      ~environment
      ()
  with
  | Vfconf.Reference.Reference_error error ->
      let diagnostic =
        Vfconf.Reference.diagnostic_of_error error
      in
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        diagnostic;
      exit 6

let run filename =
  if not (Sys.file_exists filename) then
    io_error ("file does not exist: " ^ filename);

  if Sys.is_directory filename then
    cli_error ("expected a file, found directory: " ^ filename);

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
    resolve state
  in

  let resolved_document =
    document_of_config config
  in

  let output =
    Vfconf.Formatter.format resolved_document
  in

  begin
    match
      Vfconf.Parse.string_result
        ~filename:"<vfconf-resolve>"
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
    "VFConf reference resolver\n\
     \n\
     Usage:\n\
     \  vfconf-resolve FILE.vf.conf\n\
     \  vfconf-resolve --help\n\
     \  vfconf-resolve --version\n\
     \n\
     Resolves configuration and definition references and writes\n\
     canonical VFConf to standard output.\n";
  exit 0

let print_version () =
  Printf.printf "VFConf resolve %s\n" version;
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
      cli_error "usage: vfconf-resolve FILE.vf.conf"

let () =
  main ()
