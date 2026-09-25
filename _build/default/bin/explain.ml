(*
 * VFConf - Vitte Foundation Configuration Language
 * bin/explain.ml
 *
 * Explain canonical VFConf diagnostic codes.
 *)

let version = "0.1.0"

let print_explanation explanation =
  Printf.printf
    "%s — %s\nCategory: %s\n\n%s\n"
    explanation.Vfconf.Error.code
    explanation.Vfconf.Error.title
    (Vfconf.Error.string_of_category
       explanation.Vfconf.Error.category)
    explanation.Vfconf.Error.description

let explain code =
  match Vfconf.Error.explain code with
  | Some explanation ->
      print_explanation explanation;
      exit 0

  | None ->
      Printf.eprintf
        "vfconf-explain: unknown diagnostic code '%s'\n"
        code;
      exit 2

let print_help () =
  print_string
    "VFConf diagnostic code explainer\n\
     \n\
     Usage:\n\
     \  vfconf-explain CODE\n\
     \n\
     Examples:\n\
     \  vfconf-explain VF0202\n\
     \  vfconf-explain vf0101\n"

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"]
  | [_; "-help"] ->
      print_help ()

  | [_; "-V"]
  | [_; "--version"]
  | [_; "-version"] ->
      Printf.printf "vfconf-explain %s\n" version

  | [_; code] ->
      explain code

  | [_] ->
      Printf.eprintf
        "vfconf-explain: missing diagnostic code\n";
      exit 2

  | _ ->
      Printf.eprintf
        "vfconf-explain: too many arguments\n";
      exit 2

let () =
  main ()
