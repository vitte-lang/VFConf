(*
 * VFConf - Vitte Foundation Configuration Language
 * bin/dump.ml
 *
 * Source / lexer / parser / AST inspection utility.
 *)

let version = "0.1.0"

type mode =
  | Source
  | Tokens
  | Parse
  | Ast

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
      Printf.eprintf "vfconf-dump: %s\n" message;
      exit 3

let print_diagnostics diagnostics =
  if diagnostics <> [] then
    Format.eprintf
      "%a@."
      Vfconf.Diagnostic.pp_all
      diagnostics

let parse_file filename =
  match Vfconf.Parse.file_with_diagnostics filename with
  | Ok document ->
      document

  | Error diagnostics ->
      print_diagnostics diagnostics;
      exit 1

let dump_source filename =
  let source = read_file filename in
  print_string source;

  if source = ""
     || source.[String.length source - 1] <> '\n'
  then
    print_newline ()

let dump_tokens filename =
  let source = read_file filename in
  let lexbuf =
    Lexing.from_string source
  in

  let initial_position =
    {
      Lexing.pos_fname = filename;
      pos_lnum = 1;
      pos_bol = 0;
      pos_cnum = 0;
    }
  in

  lexbuf.Lexing.lex_curr_p <- initial_position;

  Printf.printf
    "========== VFCONF TOKENS ==========\n\n\
     file: %s\n\n"
    filename;

  let rec loop () =
    try
      let parser_token =
        Vfconf.Lexer.token lexbuf
      in

      let token =
        Vfconf.Token.of_parser_token
          parser_token
      in

      let span =
        Vfconf.Node.span_of_lexing_positions
          (Lexing.lexeme_start_p lexbuf)
          (Lexing.lexeme_end_p lexbuf)
      in

      let located =
        Vfconf.Token.located
          token
          span
      in

      Format.printf
        "%a  %a@."
        Vfconf.Node.pp_span
        (Vfconf.Token.span located)
        Vfconf.Token.pp_debug
        (Vfconf.Token.value located);

      if not (Vfconf.Token.is_eof token) then
        loop ()
    with
    | Vfconf.Lexer.Error
        {
          kind;
          start_pos;
          end_pos;
        } ->
        let span =
          Vfconf.Node.span_of_lexing_positions
            start_pos
            end_pos
        in

        let message =
          Vfconf.Lexer.message_of_error_kind kind
        in

        Format.eprintf
          "%a: lexical error: %s@."
          Vfconf.Node.pp_span
          span
          message;

        exit 1
  in

  loop ()

let parse_only filename =
  let document =
    parse_file filename
  in

  Printf.printf
    "VFConf: %s: parsed successfully (%d statements)\n"
    filename
    (Vfconf.Statement.count document)

let dump_ast filename =
  let document =
    parse_file filename
  in

  Printf.printf
    "========== VFCONF AST ==========\n\n\
     file: %s\n\
     statements: %d\n\n"
    filename
    (Vfconf.Statement.count document);

  List.iter
    (fun statement ->
      Format.printf
        "%a@."
        (fun formatter node ->
          Vfconf.Statement.dump
            formatter
            0
            node)
        statement)
    document

let run mode filename =
  match mode with
  | Source ->
      dump_source filename

  | Tokens ->
      dump_tokens filename

  | Parse ->
      parse_only filename

  | Ast ->
      dump_ast filename

let print_version () =
  Printf.printf
    "vfconf-dump %s\n"
    version

let print_help () =
  print_string
    "VFConf source / lexer / parser / AST inspection utility\n\
     \n\
     Usage:\n\
     \  vfconf-dump FILE.vf.conf\n\
     \  vfconf-dump --tokens FILE.vf.conf\n\
     \  vfconf-dump --parse FILE.vf.conf\n\
     \  vfconf-dump --ast FILE.vf.conf\n\
     \  vfconf-dump --source FILE.vf.conf\n\
     \  vfconf-dump --help\n\
     \  vfconf-dump --version\n\
     \n\
     Modes:\n\
     \  --tokens    Lex and display the token stream\n\
     \  --parse     Parse without semantic validation\n\
     \  --ast       Parse and display the AST\n\
     \  --source    Display source text\n"

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
      run Ast filename

  | [_; "--tokens"; filename]
  | [_; "-tokens"; filename] ->
      run Tokens filename

  | [_; "--parse"; filename]
  | [_; "-parse"; filename] ->
      run Parse filename

  | [_; "--ast"; filename]
  | [_; "-ast"; filename] ->
      run Ast filename

  | [_; "--source"; filename]
  | [_; "-source"; filename] ->
      run Source filename

  | [_] ->
      Printf.eprintf
        "vfconf-dump: missing input file\n\
         Try 'vfconf-dump --help' for usage.\n";
      exit 2

  | _ ->
      Printf.eprintf
        "vfconf-dump: invalid arguments\n\
         Try 'vfconf-dump --help' for usage.\n";
      exit 2

let () =
  main ()
