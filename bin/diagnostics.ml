(*
 * VFConf - Vitte Foundation Configuration Language
 * bin/diagnostics.ml
 *
 * Canonical diagnostic inspection utility.
 *)

let version = "0.1.0"

type output_format =
  | Human
  | Compact
  | Json

let read_file filename =
  try
    let channel = open_in_bin filename in
    Fun.protect
      ~finally:(fun () -> close_in_noerr channel)
      (fun () ->
        let length = in_channel_length channel in
        really_input_string channel length)
  with
  | Sys_error message ->
      Printf.eprintf
        "vfconf-diagnostics: %s\n"
        message;
      exit 3

let diagnostics_of_source filename source =
  match
    Vfconf.Parse.string_result
      ~filename
      source
  with
  | Error error ->
      [
        Vfconf.Parse.diagnostic_of_error
          error
      ]

  | Ok document ->
      let validation =
        Vfconf.Validator.validate document
      in

      Vfconf.Validator.diagnostics validation
      |> Vfconf.Validator.unique_diagnostics
      |> Vfconf.Diagnostic.sort

let reporter_format = function
  | Human ->
      Vfconf.Reporter.Human

  | Compact ->
      Vfconf.Reporter.Compact

  | Json ->
      Vfconf.Reporter.Json

let run format filename =
  let source =
    read_file filename
  in

  let diagnostics =
    diagnostics_of_source
      filename
      source
  in

  let options =
    {
      Vfconf.Reporter.default_options with
      format = reporter_format format;
      show_codes = true;
      show_notes = true;
      show_fixes = true;
      sort = true;
    }
  in

  let reporter =
    Vfconf.Reporter.create
      ~options
      ()
  in

  Vfconf.Reporter.emit_many
    reporter
    diagnostics;

  Vfconf.Reporter.print
    reporter;

  if Vfconf.Reporter.has_errors reporter then
    exit 1
  else
    exit 0

let print_version () =
  Printf.printf
    "vfconf-diagnostics %s\n"
    version

let print_help () =
  print_string
    "VFConf diagnostic inspection utility\n\
     \n\
     Usage:\n\
     \  vfconf-diagnostics FILE.vf.conf\n\
     \  vfconf-diagnostics --human FILE.vf.conf\n\
     \  vfconf-diagnostics --compact FILE.vf.conf\n\
     \  vfconf-diagnostics --json FILE.vf.conf\n\
     \n\
     Output formats:\n\
     \  --human      Human-readable diagnostics\n\
     \  --compact    One-line diagnostics\n\
     \  --json       Machine-readable JSON diagnostics\n"

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"]
  | [_; "-help"] ->
      print_help ()

  | [_; "-V"]
  | [_; "--version"]
  | [_; "-version"] ->
      print_version ()

  | [_; filename] ->
      run Human filename

  | [_; "--human"; filename] ->
      run Human filename

  | [_; "--compact"; filename] ->
      run Compact filename

  | [_; "--json"; filename] ->
      run Json filename

  | [_] ->
      Printf.eprintf
        "vfconf-diagnostics: missing input file\n";
      exit 2

  | _ ->
      Printf.eprintf
        "vfconf-diagnostics: invalid arguments\n";
      exit 2

let () =
  main ()
