(*

* VFConf - Vitte Foundation Configuration Language
* dump.ml
* Debug / inspection utility for VFConf source files.
* Usage:
* vfconf-dump FILE.vf.conf
* vfconf-dump -source FILE.vf.conf
* vfconf-dump -tokens FILE.vf.conf
* vfconf-dump -ast FILE.vf.conf
    *)

type mode =
| Source
| Tokens
| Ast

let version = "0.1.0"

let has_suffix value suffix =
let value_len = String.length value in
let suffix_len = String.length suffix in
value_len >= suffix_len
&& String.sub value (value_len - suffix_len) suffix_len = suffix

let error message =
Printf.eprintf "vfconf-dump: %s\n" message;
exit 2

let validate_file filename =
if not (has_suffix filename ".vf.conf") then
error ("expected a .vf.conf file: " ^ filename);

if not (Sys.file_exists filename) then
error ("file does not exist: " ^ filename);

if Sys.is_directory filename then
error ("expected a file, found directory: " ^ filename)

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
error message

let print_separator title =
Printf.printf
"\n========== %s ==========\n\n"
title

let dump_source filename source =
print_separator "VFCONF SOURCE";
Printf.printf "file: %s\n" filename;
Printf.printf "bytes: %d\n\n" (String.length source);
print_string source;

if String.length source > 0
&& source.[String.length source - 1] <> '\n'
then
print_newline ()

(*

* Temporary token dumper.
* Once lexer.mll exists, replace this implementation with:
* let lexbuf = Lexing.from_string source in
* lexbuf.lex_curr_p <-

{
  lexbuf.lex_curr_p with
  pos_fname = filename;
};

* let rec loop () =

match Lexer.token lexbuf with
| Parser.EOF ->
    print_endline "EOF"
| token ->
    Printf.printf "%s\n" (Token.to_string token);
    loop ()

* in
* loop ()
    *)
    let dump_tokens filename source =
    print_separator "VFCONF TOKENS";

Printf.printf "file: %s\n" filename;
Printf.printf "bytes: %d\n\n" (String.length source);

Printf.printf
"\n"

(*

* Temporary AST dumper.
* Once parser.mly exists:
* let lexbuf = Lexing.from_string source in
* lexbuf.lex_curr_p <-

{
  lexbuf.lex_curr_p with
  pos_fname = filename;
};

* let ast =

Parser.document Lexer.token lexbuf

* in
* Ast.dump Format.std_formatter ast
    *)
    let dump_ast filename source =
    print_separator "VFCONF AST";

Printf.printf "file: %s\n" filename;
Printf.printf "bytes: %d\n\n" (String.length source);

Printf.printf
"\n"

let run mode filename =
validate_file filename;

let source = read_file filename in

match mode with
| Source ->
dump_source filename source
| Tokens ->
dump_tokens filename source
| Ast ->
dump_ast filename source

let print_version () =
Printf.printf "VFConf dump %s\n" version;
exit 0

let print_help () =
Printf.printf
"VFConf source inspection utility\n
\n
Usage:\n
\  vfconf-dump FILE.vf.conf\n
\  vfconf-dump -source FILE.vf.conf\n
\  vfconf-dump -tokens FILE.vf.conf\n
\  vfconf-dump -ast FILE.vf.conf\n
\n
Options:\n
\  -source       dump raw source\n
\  -tokens       dump lexer tokens\n
\  -ast          dump parsed AST\n
\  -version      display version\n
\  -help         display this help\n";
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
run Ast filename

| [_; "-source"; filename] ->
run Source filename

| [_; "-tokens"; filename] ->
run Tokens filename

| [_; "-ast"; filename] ->
run Ast filename

| _ ->
Printf.eprintf
"vfconf-dump: invalid arguments\n
Try 'vfconf-dump -help' for usage.\n";
exit 2

let () =
main ()