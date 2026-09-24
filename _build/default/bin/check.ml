(*

* VFConf - Vitte Foundation Configuration Language
* check.ml
* Command-line configuration checker.
* Usage:
* vfconf-check <file.vf.conf>
* Exit status:
* 0  configuration accepted
* 1  configuration error
* 2  command-line / I/O error
    *)

let version = "0.1.0"

type severity =
| Error
| Warning

type diagnostic = {
severity : severity;
file : string;
line : int;
column : int;
message : string;
}

let severity_name = function
| Error -> "error"
| Warning -> "warning"

let print_diagnostic diagnostic =
Printf.eprintf
"%s:%d:%d: %s: %s\n"
diagnostic.file
diagnostic.line
diagnostic.column
(severity_name diagnostic.severity)
diagnostic.message

let fail ?(line = 1) ?(column = 1) file message =
print_diagnostic
{
severity = Error;
file;
line;
column;
message;
};
exit 1

let has_suffix value suffix =
let value_length = String.length value in
let suffix_length = String.length suffix in

value_length >= suffix_length
&&
String.sub
value
(value_length - suffix_length)
suffix_length
= suffix

let validate_extension filename =
if not (has_suffix filename ".vf.conf") then
fail filename "expected a '.vf.conf' file"

let validate_regular_file filename =
if not (Sys.file_exists filename) then begin
Printf.eprintf "vfconf: %s: file does not exist\n" filename;
exit 2
end;

if Sys.is_directory filename then begin
Printf.eprintf "vfconf: %s: expected a file, found a directory\n" filename;
exit 2
end

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
Printf.eprintf "vfconf: %s\n" message;
exit 2

let validate_not_empty filename source =
if String.trim source = "" then
fail filename "configuration file is empty"

let validate_no_nul filename source =
match String.index_opt source '\000' with
| None ->
()
| Some offset ->
fail
~column:(offset + 1)
filename
"NUL byte is not allowed in VFConf source"

(*

* Temporary frontend.
* Replace this function once the VFConf lexer/parser pipeline exists:
* let lexbuf = Lexing.from_string source in
* let ast = Parser.document Lexer.token lexbuf in
* Validator.validate ast
* Parser errors should eventually be converted to canonical
* Diagnostic values preserving Lexing.position / Span information.
    *)
    let check_source filename source =
  validate_not_empty filename source;
  validate_no_nul filename source;

  match Vfconf.Parse.string_result ~filename source with
  | Error error ->
      let diagnostic =
        Vfconf.Parse.diagnostic_of_error error
      in

      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        diagnostic;

      exit 1

  | Ok document ->
      let validation =
        Vfconf.Validator.validate document
      in

      let diagnostics =
        Vfconf.Validator.diagnostics validation
        |> Vfconf.Diagnostic.sort
      in

      if diagnostics <> [] then
        Format.eprintf
          "%a@."
          Vfconf.Diagnostic.pp_all
          diagnostics;

      if Vfconf.Diagnostic.has_errors diagnostics then
        exit 1;

      document

let check_file filename =
  validate_extension filename;
  validate_regular_file filename;

  let source =
    read_file filename
  in

  let _document =
    check_source filename source
  in

  Printf.printf
    "VFConf: %s: OK\n"
    filename;

  exit 0

let print_version () =
Printf.printf "VFConf %s\n" version;
exit 0

let print_help () =
Printf.printf
"VFConf configuration checker\n
\n
Usage:\n
\  vfconf-check FILE.vf.conf\n
\  vfconf-check -help\n
\  vfconf-check -version\n
\n
Exit status:\n
\  0  configuration accepted\n
\  1  invalid VFConf configuration\n
\  2  command-line or I/O error\n";
exit 0

let main () =
match Array.to_list Sys.argv with
| [_; "-help"]
| [_; "-h"] ->
print_help ()

| [_; "-version"]
| [_; "-V"] ->
print_version ()

| [_; filename] ->
check_file filename

| [_] ->
Printf.eprintf
"vfconf: missing input file\n
Try 'vfconf-check -help' for usage.\n";
exit 2

| _ ->
Printf.eprintf
"vfconf: too many arguments\n
Try 'vfconf-check -help' for usage.\n";
exit 2

let () =
main ()