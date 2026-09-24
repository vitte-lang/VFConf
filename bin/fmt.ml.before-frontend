(*

* VFConf - Vitte Foundation Configuration Language
* fmt.ml
* VFConf formatter command-line frontend.
* Usage:
* vfconf-fmt FILE.vf.conf
* vfconf-fmt -check FILE.vf.conf
* vfconf-fmt -stdout FILE.vf.conf
* Exit status:
* 0  success / already formatted
* 1  file requires formatting or contains invalid VFConf
* 2  command-line / I/O error
    *)

type mode =
| Write
| Check
| Stdout

let version = "0.1.0"

let has_suffix value suffix =
let value_len = String.length value in
let suffix_len = String.length suffix in
value_len >= suffix_len
&& String.sub value (value_len - suffix_len) suffix_len = suffix

let cli_error message =
Printf.eprintf "vfconf-fmt: %s\n" message;
exit 2

let validate_file filename =
if not (has_suffix filename ".vf.conf") then
cli_error ("expected a '.vf.conf' file: " ^ filename);

if not (Sys.file_exists filename) then
cli_error ("file does not exist: " ^ filename);

if Sys.is_directory filename then
cli_error ("expected a file, found directory: " ^ filename)

let read_file filename =
try
let channel = open_in_bin filename in
Fun.protect
~finally:(fun () -> close_in_noerr channel)
(fun () ->
really_input_string channel (in_channel_length channel))
with
| Sys_error message ->
cli_error message

let write_file filename contents =
try
let channel = open_out_bin filename in
Fun.protect
~finally:(fun () -> close_out_noerr channel)
(fun () ->
output_string channel contents;
flush channel)
with
| Sys_error message ->
cli_error message

let normalize_line_endings source =
let buffer = Buffer.create (String.length source) in

let rec loop i =
if i >= String.length source then
()
else
match source.[i] with
| '\r' ->
if i + 1 < String.length source
&& source.[i + 1] = '\n'
then begin
Buffer.add_char buffer '\n';
loop (i + 2)
end
else begin
Buffer.add_char buffer '\n';
loop (i + 1)
end

  | c ->
      Buffer.add_char buffer c;
      loop (i + 1)

in

loop 0;
Buffer.contents buffer

let remove_trailing_whitespace line =
let rec find_end i =
if i < 0 then
-1
else
match line.[i] with
| ' '
| '\t' ->
find_end (i - 1)
| _ ->
i
in

let last = find_end (String.length line - 1) in

if last < 0 then
""
else
String.sub line 0 (last + 1)

let basic_format source =
let source = normalize_line_endings source in

let lines =
String.split_on_char '\n' source
|> List.map remove_trailing_whitespace
in

let formatted =
String.concat "\n" lines
in

(* Ensure exactly one final newline. *)
let formatted =
String.trim formatted
in

if formatted = "" then
""
else
formatted ^ "\n"

(*

* This is intentionally only a bootstrap formatter.
* Once the VFConf frontend is complete, replace basic_format with:
* source
* -> Lexer
* -> Parser
* -> AST
* -> Formatter.format
* -> Printer
* Formatting from the AST guarantees deterministic canonical output
* instead of manipulating raw source text.
    *)
    let format_source source =
    basic_format source

let run_write filename source formatted =
if source = formatted then
Printf.printf "%s: already formatted\n" filename
else begin
write_file filename formatted;
Printf.printf "%s: formatted\n" filename
end

let run_check filename source formatted =
if source = formatted then begin
Printf.printf "%s: formatted\n" filename;
exit 0
end
else begin
Printf.eprintf "%s: requires formatting\n" filename;
exit 1
end

let run_stdout formatted =
print_string formatted;
flush stdout

let run mode filename =
validate_file filename;

let source = read_file filename in
let formatted = format_source source in

match mode with
| Write ->
run_write filename source formatted

| Check ->
run_check filename source formatted

| Stdout ->
run_stdout formatted

let print_version () =
Printf.printf "VFConf formatter %s\n" version;
exit 0

let print_help () =
Printf.printf
"VFConf formatter\n
\n
Usage:\n
\  vfconf-fmt FILE.vf.conf\n
\  vfconf-fmt -write FILE.vf.conf\n
\  vfconf-fmt -check FILE.vf.conf\n
\  vfconf-fmt -stdout FILE.vf.conf\n
\n
Options:\n
\  -w, -write     format file in place (default)\n
\  -c, -check     check formatting without modifying file\n
\  -stdout        print formatted source to stdout\n
\  -V, -version   display version\n
\  -h, -help      display help\n";
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
run Write filename

| [_; "-write"; filename]
| [_; "-w"; filename] ->
run Write filename

| [_; "-check"; filename]
| [_; "-c"; filename] ->
run Check filename

| [_; "-stdout"; filename] ->
run Stdout filename

| _ ->
Printf.eprintf
"vfconf-fmt: invalid arguments\n
Try 'vfconf-fmt -help' for usage.\n";
exit 2

let () =
main ()