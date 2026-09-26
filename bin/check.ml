let version = "0.1.0"

let help =
  "VFConf configuration checker\n\n\
   Usage: vfconf-check [OPTIONS] FILE.vf.conf\n\
          vfconf-check [OPTIONS] -\n\n\
   Options:\n\
     --json                    emit JSON diagnostics\n\
     --editor                  emit file:line:column diagnostics\n\
     --quiet, -q               suppress success output\n\
     --color=auto|always|never control ANSI colors\n\
     -V, --version             display version\n\
     -h, --help                display help\n\n\
   Exit status: 0 success, 1 invalid input, 2 usage, 3 I/O.\n"

let run options input =
  match Cli_support.read_input input with
  | Error message ->
      Printf.eprintf "vfconf-check: %s\n" message;
      Exit_code.io_error
  | Ok (filename, source) ->
      if String.trim source = "" then begin
        let diagnostic =
          Vfconf.Error.invalid_value "configuration file is empty"
          |> Vfconf.Error.to_diagnostic
        in
        Cli_support.emit_diagnostics options [diagnostic];
        Exit_code.invalid_configuration
      end else
        match Vfconf.Api.check ~filename source with
        | Error diagnostics ->
            Cli_support.emit_diagnostics options diagnostics;
            Exit_code.invalid_configuration
        | Ok _ ->
            if not options.Cli_support.quiet then
              begin match options.Cli_support.output with
              | Cli_support.Json ->
                  Printf.printf
                    "{\"valid\":true,\"file\":%s}\n"
                    (Cli_support.json_string filename)
              | Cli_support.Human | Cli_support.Editor ->
                  Printf.printf "VFConf: %s: OK\n" filename
              end;
            Exit_code.success

let main arguments =
  match Cli_support.parse arguments with
  | Error message ->
      Printf.eprintf "vfconf-check: %s\n" message;
      Exit_code.command_line_error
  | Ok (_, (["-h"] | ["--help"])) ->
      print_string help;
      Exit_code.success
  | Ok (_, (["-V"] | ["--version"])) ->
      Printf.printf "vfconf-check %s\n" version;
      Exit_code.success
  | Ok (options, [input]) -> run options input
  | Ok _ ->
      Printf.eprintf "vfconf-check: expected one input file or '-'\n";
      Exit_code.command_line_error

let () =
  let arguments = Array.to_list Sys.argv |> List.tl in
  exit (main arguments)
