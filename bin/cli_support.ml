open Vfconf

type color_mode = Auto | Always | Never
type output_mode = Human | Json | Editor

type options = {
  color : color_mode;
  output : output_mode;
  quiet : bool;
}

let default_options = {color = Auto; output = Human; quiet = false}

let color_of_string = function
  | "auto" -> Ok Auto
  | "always" -> Ok Always
  | "never" -> Ok Never
  | value -> Error (Printf.sprintf "invalid color mode %S" value)

let rec parse_with options positional = function
  | [] -> Ok (options, List.rev positional)
  | "--json" :: rest -> parse_with {options with output = Json} positional rest
  | "--editor" :: rest -> parse_with {options with output = Editor} positional rest
  | "--quiet" :: rest | "-q" :: rest ->
      parse_with {options with quiet = true} positional rest
  | "--color" :: value :: rest ->
      begin match color_of_string value with
      | Ok color -> parse_with {options with color} positional rest
      | Error _ as error -> error
      end
  | "--color" :: [] -> Error "--color requires auto, always, or never"
  | argument :: rest when String.starts_with ~prefix:"--color=" argument ->
      let value = String.sub argument 8 (String.length argument - 8) in
      begin match color_of_string value with
      | Ok color -> parse_with {options with color} positional rest
      | Error _ as error -> error
      end
  | argument :: rest -> parse_with options (argument :: positional) rest

let parse arguments = parse_with default_options [] arguments

let read_channel channel =
  let buffer = Buffer.create 4096 in
  let bytes = Bytes.create 4096 in
  let rec loop () =
    match input channel bytes 0 (Bytes.length bytes) with
    | 0 -> Buffer.contents buffer
    | count -> Buffer.add_subbytes buffer bytes 0 count; loop ()
  in
  loop ()

let read_input filename =
  if String.equal filename "-" then Ok ("<stdin>", read_channel stdin)
  else
    try
      let channel = open_in_bin filename in
      let source = Fun.protect ~finally:(fun () -> close_in_noerr channel) (fun () -> read_channel channel) in
      Ok (filename, source)
    with Sys_error message -> Error message

let json_string = Reporter.json_string

let color_enabled options descriptor =
  match options.color with
  | Always -> true
  | Never -> false
  | Auto -> Unix.isatty descriptor

let emit_diagnostics options diagnostics =
  let format =
    match options.output with
    | Human -> Reporter.Human
    | Json -> Reporter.Json
    | Editor -> Reporter.Compact
  in
  let reporter =
    Reporter.create
      ~options:{Reporter.default_options with format; show_codes = true; sort = true}
      ()
  in
  Reporter.emit_many reporter diagnostics;
  if not (Reporter.is_empty reporter) then
    let output = Reporter.to_string reporter in
    if color_enabled options Unix.stderr && options.output = Human then
      Printf.eprintf "\027[31m%s\027[0m%!" output
    else
      Printf.eprintf "%s%!" output
