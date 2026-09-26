let version = "0.1.0"

type mode = Write | Check | Stdout | Diff

let help =
  "VFConf comment-preserving formatter\n\n\
   Usage: vfconf-fmt [OPTIONS] [FILE.vf.conf|-]\n\n\
   Options:\n\
     -w, --write              format file in place\n\
     -c, --check              check canonical formatting\n\
     --stdout                 print formatted source (default)\n\
     --diff                   display formatting differences\n\
     --json                   emit JSON output\n\
     --editor                 editor-compatible diagnostics\n\
     --quiet, -q              suppress status output\n\
     --color=auto|always|never control ANSI colors\n\
     -V, --version            display version\n\
     -h, --help               display help\n\n\
   FILE defaults to '-' (standard input).\n\
   Exit status: 0 success, 1 invalid/unformatted, 2 usage, 3 I/O.\n"

let write_file filename contents =
  try
    let directory = Filename.dirname filename in
    let temporary = Filename.temp_file ~temp_dir:directory (Filename.basename filename ^ ".") ".tmp" in
    let committed = ref false in
    Fun.protect
      ~finally:(fun () -> if not !committed then try Sys.remove temporary with Sys_error _ -> ())
      (fun () ->
        let channel = open_out_bin temporary in
        Fun.protect ~finally:(fun () -> close_out_noerr channel)
          (fun () -> output_string channel contents; flush channel);
        Unix.rename temporary filename;
        committed := true);
    Ok ()
  with
  | Sys_error message -> Error message
  | Unix.Unix_error (error, function_name, argument) ->
      Error (Printf.sprintf "%s: %s(%s)" (Unix.error_message error) function_name argument)

let print_diff options filename source formatted =
  let color = Cli_support.color_enabled options Unix.stdout in
  let red, green, reset =
    if color then "\027[31m", "\027[32m", "\027[0m" else "", "", ""
  in
  Printf.printf "--- %s\n+++ %s (formatted)\n" filename filename;
  Printf.printf "%s-%s%s\n%s+%s%s\n" red source reset green formatted reset

let emit_formatted options formatted =
  match options.Cli_support.output with
  | Cli_support.Json ->
      Printf.printf "{\"formatted\":%s}\n" (Cli_support.json_string formatted)
  | Cli_support.Human | Cli_support.Editor -> print_string formatted

let run options mode input =
  match Cli_support.read_input input with
  | Error message ->
      Printf.eprintf "vfconf-fmt: %s\n" message;
      Exit_code.io_error
  | Ok (filename, source) ->
      begin match Vfconf.Api.format ~filename source with
      | Error diagnostics ->
          Cli_support.emit_diagnostics options diagnostics;
          Exit_code.invalid_configuration
      | Ok formatted ->
          match mode with
          | Stdout -> emit_formatted options formatted; Exit_code.success
          | Check ->
              let canonical = String.equal source formatted in
              if options.Cli_support.output = Cli_support.Json then
                Printf.printf "{\"canonical\":%s,\"file\":%s}\n"
                  (if canonical then "true" else "false")
                  (Cli_support.json_string filename)
              else if not options.Cli_support.quiet then
                Printf.printf "%s: %s\n" filename
                  (if canonical then "formatted" else "requires formatting");
              if canonical then Exit_code.success else Exit_code.invalid_configuration
          | Diff ->
              if String.equal source formatted then Exit_code.success
              else begin print_diff options filename source formatted; Exit_code.invalid_configuration end
          | Write ->
              if String.equal input "-" then begin
                Printf.eprintf "vfconf-fmt: --write cannot be used with stdin\n";
                Exit_code.command_line_error
              end else
                begin match write_file input formatted with
                | Error message -> Printf.eprintf "vfconf-fmt: %s\n" message; Exit_code.io_error
                | Ok () ->
                    if not options.Cli_support.quiet then Printf.printf "%s: formatted\n" input;
                    Exit_code.success
                end
      end

let extract_mode arguments =
  let rec loop mode positional = function
    | [] -> Ok (mode, List.rev positional)
    | ("-w" | "--write") :: rest -> loop Write positional rest
    | ("-c" | "--check") :: rest -> loop Check positional rest
    | "--stdout" :: rest -> loop Stdout positional rest
    | "--diff" :: rest -> loop Diff positional rest
    | argument :: rest -> loop mode (argument :: positional) rest
  in
  loop Stdout [] arguments

let main arguments =
  match Cli_support.parse arguments with
  | Error message -> Printf.eprintf "vfconf-fmt: %s\n" message; Exit_code.command_line_error
  | Ok (_, (["-h"] | ["--help"])) -> print_string help; Exit_code.success
  | Ok (_, (["-V"] | ["--version"])) -> Printf.printf "vfconf-fmt %s\n" version; Exit_code.success
  | Ok (options, arguments) ->
      begin match extract_mode arguments with
      | Error message -> Printf.eprintf "vfconf-fmt: %s\n" message; Exit_code.command_line_error
      | Ok (mode, []) -> run options mode "-"
      | Ok (mode, [input]) -> run options mode input
      | Ok _ -> Printf.eprintf "vfconf-fmt: expected one input\n"; Exit_code.command_line_error
      end

let () =
  let arguments = Array.to_list Sys.argv |> List.tl in
  exit (main arguments)
