let version = "0.1.0"

module String_map = Map.Make (String)

type tree = {
  value : Vfconf.Value.t Vfconf.Node.t option;
  children : tree String_map.t;
}

let empty_tree =
  {
    value = None;
    children = String_map.empty;
  }

let cli_error message =
  Printf.eprintf "vfconf-tree: %s\n" message;
  exit 2

let io_error message =
  Printf.eprintf "vfconf-tree: %s\n" message;
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
        "vfconf-tree: %s\n"
        (Vfconf.Loader.string_of_error error);
      exit 1
  | Sys_error message ->
      io_error message

let rec insert path value tree =
  match path with
  | [] ->
      {
        tree with
        value = Some value;
      }

  | component :: rest ->
      let child =
        match String_map.find_opt component tree.children with
        | Some child ->
            child
        | None ->
            empty_tree
      in

      let child =
        insert rest value child
      in

      {
        tree with
        children =
          String_map.add
            component
            child
            tree.children;
      }

let tree_of_config config =
  Vfconf.Config.entries config
  |> List.fold_left
       (fun tree entry ->
         insert
           entry.Vfconf.Config.path
           entry.Vfconf.Config.value
           tree)
       empty_tree

let rec print_tree level tree =
  String_map.iter
    (fun name child ->
      let indentation =
        String.make (level * 2) ' '
      in

      match child.value with
      | Some value ->
          Printf.printf
            "%s%s = %s\n"
            indentation
            name
            (Vfconf.Formatter.format_value value)

      | None ->
          Printf.printf
            "%s%s\n"
            indentation
            name;

      print_tree (level + 1) child)
    tree.children

let run filename =
  validate_file filename;

  let config =
    load_config filename
  in

  let tree =
    tree_of_config config
  in

  print_tree 0 tree;
  exit 0

let print_help () =
  Printf.printf
    "VFConf configuration tree\n\
     \n\
     Usage:\n\
     \  vfconf-tree FILE.vf.conf\n\
     \  vfconf-tree --help\n\
     \  vfconf-tree --version\n";
  exit 0

let print_version () =
  Printf.printf "VFConf tree %s\n" version;
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
      cli_error "usage: vfconf-tree FILE.vf.conf"

let () =
  main ()
