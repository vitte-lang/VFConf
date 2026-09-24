(*
 * VFConf - Vitte Foundation Configuration Language
 * bin/fmt.ml
 *
 * Canonical VFConf command-line formatter.
 *
 * Usage:
 *   vfconf-fmt FILE.vf.conf
 *   vfconf-fmt --write FILE.vf.conf
 *   vfconf-fmt --check FILE.vf.conf
 *   vfconf-fmt --stdout FILE.vf.conf
 *
 * Exit status:
 *   0  success
 *   1  formatting required
 *   2  command-line or I/O error
 *)

type mode =
  | Write
  | Check
  | Stdout

let version = "0.1.0"

let program_name = "vfconf-fmt"

(* ---------------------------------------------------------- *)
(* Errors                                                     *)
(* ---------------------------------------------------------- *)

let fail_usage message =
  Printf.eprintf "%s: %s\n" program_name message;
  Printf.eprintf "Try '%s --help' for usage.\n" program_name;
  exit 2

let fail_io message =
  Printf.eprintf "%s: %s\n" program_name message;
  exit 2

(* ---------------------------------------------------------- *)
(* Filename validation                                        *)
(* ---------------------------------------------------------- *)

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

let validate_filename filename =
  if not (has_suffix filename ".vf.conf") then
    fail_usage
      (Printf.sprintf
         "'%s' is not a VFConf file (expected *.vf.conf)"
         filename)

let validate_input filename =
  validate_filename filename;

  if not (Sys.file_exists filename) then
    fail_io
      (Printf.sprintf
         "file not found: %s"
         filename);

  if Sys.is_directory filename then
    fail_io
      (Printf.sprintf
         "expected a file, found a directory: %s"
         filename)

(* ---------------------------------------------------------- *)
(* File I/O                                                   *)
(* ---------------------------------------------------------- *)

let read_file filename =
  try
    let channel = open_in_bin filename in

    Fun.protect
      ~finally:(fun () ->
        close_in_noerr channel)
      (fun () ->
        let length = in_channel_length channel in
        really_input_string channel length)

  with
  | Sys_error message ->
      fail_io message

let write_file filename contents =
  try
    let channel = open_out_bin filename in

    Fun.protect
      ~finally:(fun () ->
        close_out_noerr channel)
      (fun () ->
        output_string channel contents;
        flush channel)

  with
  | Sys_error message ->
      fail_io message

(* ---------------------------------------------------------- *)
(* Line ending normalization                                  *)
(* ---------------------------------------------------------- *)

let normalize_line_endings source =
  let length = String.length source in
  let buffer = Buffer.create length in

  let rec loop index =
    if index >= length then
      ()
    else
      match source.[index] with
      | '\r' ->
          if
            index + 1 < length
            && source.[index + 1] = '\n'
          then begin
            Buffer.add_char buffer '\n';
            loop (index + 2)
          end
          else begin
            Buffer.add_char buffer '\n';
            loop (index + 1)
          end

      | character ->
          Buffer.add_char buffer character;
          loop (index + 1)
  in

  loop 0;
  Buffer.contents buffer

(* ---------------------------------------------------------- *)
(* Whitespace normalization                                   *)
(* ---------------------------------------------------------- *)

let remove_trailing_whitespace line =
  let rec find_last index =
    if index < 0 then
      -1
    else
      match line.[index] with
      | ' '
      | '\t' ->
          find_last (index - 1)

      | _ ->
          index
  in

  let last =
    find_last (String.length line - 1)
  in

  if last < 0 then
    ""
  else
    String.sub line 0 (last + 1)

let remove_final_empty_lines lines =
  let rec drop = function
    | [] ->
        []

    | "" :: rest ->
        drop rest

    | remaining ->
        remaining
  in

  List.rev lines
  |> drop
  |> List.rev

(* ---------------------------------------------------------- *)
(* Bootstrap formatter                                        *)
(* ---------------------------------------------------------- *)

let bootstrap_format source =
  let normalized =
    normalize_line_endings source
  in

  let lines =
    String.split_on_char '\n' normalized
    |> List.map remove_trailing_whitespace
    |> remove_final_empty_lines
  in

  match lines with
  | [] ->
      ""

  | _ ->
      String.concat "\n" lines ^ "\n"

(*
 * Canonical frontend integration point.
 *
 * Once lexer.mll, parser.mly and the AST formatter are ready,
 * this bootstrap implementation should be replaced by:
 *
 *   let lexbuf =
 *     Lexing.from_string source
 *   in
 *
 *   lexbuf.lex_curr_p <-
 *     {
 *       lexbuf.lex_curr_p with
 *       pos_fname = filename;
 *     };
 *
 *   let document =
 *     Parser.document Lexer.token lexbuf
 *   in
 *
 *   Formatter.format document
 *
 * Final architecture:
 *
 *       *.vf.conf
 *            |
 *            v
 *        lexer.mll
 *            |
 *            v
 *        parser.mly
 *            |
 *            v
 *           AST
 *            |
 *            v
 *      formatter.ml
 *            |
 *            v
 *       printer.ml
 *            |
 *            v
 *   canonical *.vf.conf
 *)

let format_source _filename source =
  bootstrap_format source

(* ---------------------------------------------------------- *)
(* Write mode                                                 *)
(* ---------------------------------------------------------- *)

let format_write filename =
  validate_input filename;

  let source =
    read_file filename
  in

  let formatted =
    format_source filename source
  in

  if source = formatted then
    Printf.printf
      "%s: unchanged\n"
      filename
  else begin
    write_file filename formatted;

    Printf.printf
      "%s: formatted\n"
      filename
  end

(* ---------------------------------------------------------- *)
(* Check mode                                                 *)
(* ---------------------------------------------------------- *)

let format_check filename =
  validate_input filename;

  let source =
    read_file filename
  in

  let formatted =
    format_source filename source
  in

  if source = formatted then begin
    Printf.printf
      "%s: formatted\n"
      filename;

    exit 0
  end
  else begin
    Printf.eprintf
      "%s: requires formatting\n"
      filename;

    exit 1
  end

(* ---------------------------------------------------------- *)
(* Stdout mode                                                *)
(* ---------------------------------------------------------- *)

let format_stdout filename =
  validate_input filename;

  let source =
    read_file filename
  in

  let formatted =
    format_source filename source
  in

  print_string formatted;
  flush stdout

(* ---------------------------------------------------------- *)
(* Dispatcher                                                 *)
(* ---------------------------------------------------------- *)

let run mode filename =
  match mode with
  | Write ->
      format_write filename

  | Check ->
      format_check filename

  | Stdout ->
      format_stdout filename

(* ---------------------------------------------------------- *)
(* Version                                                    *)
(* ---------------------------------------------------------- *)

let print_version () =
  Printf.printf
    "VFConf formatter %s\n"
    version

(* ---------------------------------------------------------- *)
(* Help                                                       *)
(* ---------------------------------------------------------- *)

let print_help () =
  Printf.printf
    "VFConf formatter\n\
     \n\
     Usage:\n\
     \  vfconf-fmt FILE.vf.conf\n\
     \  vfconf-fmt --write FILE.vf.conf\n\
     \  vfconf-fmt --check FILE.vf.conf\n\
     \  vfconf-fmt --stdout FILE.vf.conf\n\
     \n\
     Options:\n\
     \  -w, --write      format file in place\n\
     \  -c, --check      verify canonical formatting\n\
     \  -p, --stdout     write formatted source to stdout\n\
     \  -V, --version    display version\n\
     \  -h, --help       display help\n\
     \n\
     Exit status:\n\
     \  0   success\n\
     \  1   formatting required\n\
     \  2   command-line or I/O error\n"

(* ---------------------------------------------------------- *)
(* Main                                                       *)
(* ---------------------------------------------------------- *)

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"] ->
      print_help ()

  | [_; "-V"]
  | [_; "--version"] ->
      print_version ()

  | [_; filename] ->
      run Write filename

  | [_; "-w"; filename]
  | [_; "--write"; filename] ->
      run Write filename

  | [_; "-c"; filename]
  | [_; "--check"; filename] ->
      run Check filename

  | [_; "-p"; filename]
  | [_; "--stdout"; filename] ->
      run Stdout filename

  | [_] ->
      fail_usage "missing input file"

  | _ ->
      fail_usage "invalid arguments"

let () =
  main ()