open Vfconf

exception Test_failure of string

let fail format =
  Printf.ksprintf (fun message -> raise (Test_failure message)) format

let check condition format =
  Printf.ksprintf (fun message -> if not condition then fail "%s" message) format

let check_equal expected actual label =
  if not (String.equal expected actual) then
    fail "%s: expected %S, got %S" label expected actual

let parse source =
  match Parse.string_result ~filename:"test.vf.conf" source with
  | Ok document -> document
  | Error error -> fail "parse failed: %s" (Parse.string_of_error error)

let codes diagnostics =
  List.filter_map (fun diagnostic -> diagnostic.Diagnostic.code) diagnostics

let has_code code diagnostics =
  List.exists (String.equal code) (codes diagnostics)

let test_lexer_and_positions () =
  let document = parse "answer = -42\ncolor = #aabbcc\n" in
  match document with
  | first :: second :: _ ->
      check (first.Node.span.start_pos.line = 1) "first node line";
      check (second.Node.span.start_pos.line = 2) "second node line";
      check
        (second.Node.span.start_pos.offset > first.Node.span.start_pos.offset)
        "source offsets must increase"
  | _ -> fail "expected two assignments"

let test_hash_disambiguation () =
  ignore (parse "# comment\nvalue = #abc\n");
  let rejects source =
    match Parse.string_result ~filename:"hash.vf.conf" source with
    | Error _ -> true
    | Ok _ -> false
  in
  check (rejects "#comment\n") "hash comments must contain whitespace";
  check (rejects "value = #12\n") "short hexadecimal color must be rejected";
  check
    (rejects "value = #abc trailing\n")
    "a compact color cannot silently consume trailing comment text"

let test_language_contract () =
  ignore
    (parse
       "decimal = -12\npositive = +7\nfloat = .5\nexponent = 1e-6\nhex = 0xff\noctal = 0o755\nbinary = 0b1010\n");
  ignore
    (parse
       "nanoseconds = 1ns\nmicroseconds = 2us\n milliseconds = 3ms\nseconds = 4s\nminutes = 5min\nhours = 6h\nbytes = 1B\nkilobytes = 2KB\nmebibytes = 3MiB\n");
  begin
    match parse "[first]\na = 1\n[first.nested]\nb = 2\n[second]\nc = 3\n" with
    | [
        {Node.value = Statement.Section first; _};
        {Node.value = Statement.Section nested; _};
        {Node.value = Statement.Section second; _};
      ] ->
        check (List.length first.Statement.body = 1) "first section extent";
        check (List.length nested.Statement.body = 1) "nested section extent";
        check (List.length second.Statement.body = 1) "second section extent"
    | _ -> fail "section boundaries do not match the language contract"
  end;
  begin
    match parse "when true || false && false {\nvalue = 1\n}\n" with
    | [{Node.value = Statement.Conditional conditional; _}] ->
        begin
          match conditional.Statement.condition.Node.value with
          | Statement.Logical
              {
                operator = Statement.Or;
                right = {Node.value = Statement.Logical {operator = Statement.And; _}; _};
                _;
              } -> ()
          | _ -> fail "condition precedence must bind && more strongly than ||"
        end
    | _ -> fail "expected conditional statement"
  end;
  begin
    match parse "value = 1\nvalue += 2\nvalue -= 1\nonce := true\n" with
    | statements ->
        let operators =
          List.filter_map
            (fun statement ->
              match statement.Node.value with
              | Statement.Assignment assignment -> Some assignment.Statement.operator
              | _ -> None)
            statements
        in
        check
          (operators =
             [Statement.Assign; Statement.Add_assign; Statement.Sub_assign;
              Statement.Define_assign])
          "assignment operators"
  end;
  check
    (match
       Parse.string_result
         ~filename:"scope.vf.conf"
         "when true {\n[forbidden]\nvalue = 1\n}\n"
     with
     | Error _ -> true
     | Ok _ -> false)
    "section headers must remain top-level"

let test_parser_and_ast () =
  match parse "[server]\nport = 8080\n" with
  | [{ Node.value = Statement.Section section; _ }] ->
      check_equal "server" (String.concat "." section.Statement.name) "section";
      check (List.length section.Statement.body = 1) "section body"
  | _ -> fail "expected one section"

let test_analyzer () =
  let document =
    parse
      "define unused = 1\nempty = []\n[blank]\n[next]\nvalue = 1\nwhen false {\n  hidden = true\n}\n"
  in
  let diagnostics = Analyzer.diagnostics (Analyzer.analyze document) in
  List.iter
    (fun code -> check (has_code code diagnostics) "missing analyzer diagnostic %s" code)
    ["VFW0203"; "VFW0303"; "VFW0304"; "VFW0503"; "VFW0504"]
  ;
  let unused = Analyzer.unused_diagnostics ~roots:[["next"; "value"]] (Analyzer.analyze document) in
  check (has_code "VFW0204" unused) "unused section warning";
  check (has_code "VFW0205" unused) "unused value warning"

let test_references_and_conditions () =
  let document = parse "enabled = true\nwhen $enabled {\n  value = 1\n}\n" in
  let result = Validator.validate document in
  check
    (not (Validator.has_errors result.Validator.diagnostics))
    "valid reference reported as error";
  let config = Option.get result.Validator.config in
  check
    (Condition.reference_truthy [] config ["enabled"])
    "boolean reference should be true"

let test_evaluator_diagnostics () =
  let document =
    parse "number = 1\nnumber = 1\nratio = 1\nratio += 0.5\n"
  in
  let state = Evaluator.evaluate_document document in
  let diagnostics = Evaluator.diagnostics state in
  check (has_code "VFW0301" diagnostics) "redundant assignment warning";
  check (has_code "VFW0501" diagnostics) "implicit conversion warning";
  begin
    try
      ignore (Evaluator.divide_numbers 1.0 0.0);
      fail "division by zero should fail"
    with
    | Evaluator.Evaluation_error Evaluator.Division_by_zero -> ()
    | exn -> raise exn
  end;
  begin
    try
      ignore
        (Evaluator.evaluate_value
           (Evaluator.empty_state ())
           (Node.dummy (Value.Float Float.nan)));
      fail "non-finite value should fail"
    with
    | Evaluator.Evaluation_error (Evaluator.Invalid_value _) -> ()
    | exn -> raise exn
  end

let test_evaluator_limits_and_types () =
  let strict_failure source options expected =
    match Evaluator.evaluate_with_diagnostics ~options (parse source) with
    | Error error ->
        check (expected error) "unexpected evaluator error: %s" (Evaluator.string_of_error error)
    | Ok _ -> fail "evaluation should have failed"
  in
  strict_failure
    "value = 1\nvalue = \"one\"\n"
    Evaluator.default_options
    (function Evaluator.Type_mismatch _ -> true | _ -> false);
  let no_conversion =
    {Evaluator.default_options with allow_numeric_conversions = false}
  in
  strict_failure
    "value = 1\nvalue += 0.5\n"
    no_conversion
    (function Evaluator.Type_mismatch _ -> true | _ -> false);
  let low_complexity =
    {Evaluator.default_options with maximum_operations = 2}
  in
  strict_failure
    "a = 1\nb = 2\n"
    low_complexity
    (function Evaluator.Limit_exceeded {limit; _} -> limit = "operation count" | _ -> false);
  let low_depth =
    {Evaluator.default_options with maximum_depth = 2}
  in
  strict_failure
    "value = [[[1]]]\n"
    low_depth
    (function Evaluator.Limit_exceeded {limit; _} -> limit = "nesting depth" | _ -> false)

let with_temp_vfconf contents function_ =
  let path = Filename.temp_file "vfconf-test-" ".vf.conf" in
  let channel = open_out_bin path in
  output_string channel contents;
  close_out channel;
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> function_ path)

let test_includes_and_cycles () =
  with_temp_vfconf "value = 1\n" (fun path ->
    let context = Include.create_context (Filename.dirname path) in
    let context = Include.push path context in
    match Include.cycle_for path context with
    | Some [first; last] ->
        check (String.equal first last) "cycle endpoints"
    | _ -> fail "include cycle was not detected")

let test_loader_warnings () =
  let child = Filename.temp_file "vfconf-child-" ".vf.conf" in
  let parent = Filename.temp_file "vfconf-parent-" ".vf.conf" in
  let write path contents =
    let channel = open_out_bin path in
    output_string channel contents;
    close_out channel
  in
  Fun.protect
    ~finally:(fun () -> Sys.remove parent; Sys.remove child)
    (fun () ->
      write child "child = true\n";
      let include_line = Printf.sprintf "include %S\n" (Filename.basename child) in
      write parent (include_line ^ include_line);
      let result = Loader.load_file parent in
      check
        (has_code "VFW0601" (Loader.diagnostics result))
        "repeated include warning")

let make_temp_directory prefix =
  let path = Filename.temp_file prefix "" in
  Sys.remove path;
  Unix.mkdir path 0o700;
  path

let test_include_security () =
  let root = make_temp_directory "vfconf-root-" in
  let outside = Filename.temp_file "vfconf-outside-" ".vf.conf" in
  let inside = Filename.concat root "inside.vf.conf" in
  let link_inside = Filename.concat root "inside-link.vf.conf" in
  let link_outside = Filename.concat root "outside-link.vf.conf" in
  let write path contents =
    let channel = open_out_bin path in
    output_string channel contents;
    close_out channel
  in
  Fun.protect
    ~finally:(fun () ->
      List.iter (fun path -> if Sys.file_exists path then Sys.remove path)
        [link_inside; link_outside; inside; outside];
      Unix.rmdir root)
    (fun () ->
      write inside "inside = true\n";
      write outside "outside = true\n";
      Unix.symlink inside link_inside;
      Unix.symlink outside link_outside;
      check
        (String.equal (Include.canonicalize link_inside) (Include.canonicalize inside))
        "canonical path must resolve symbolic links";
      let context = Include.create_context root in
      begin
        try
          ignore (Include.enter context (Filename.basename link_inside));
          fail "symbolic link should be rejected by default"
        with
        | Include.Include_error (Include.Symlink_not_allowed _) -> ()
        | exn -> raise exn
      end;
      let symlinks = Include.create_context ~allow_symlinks:true root in
      ignore (Include.enter symlinks (Filename.basename link_inside));
      begin
        try
          ignore (Include.enter symlinks (Filename.basename link_outside));
          fail "symlink escaping the security root should be rejected"
        with
        | Include.Include_error (Include.Outside_root _) -> ()
        | exn -> raise exn
      end;
      begin
        try
          ignore (Include.enter context (Include.canonicalize outside));
          fail "absolute path outside the security root should be rejected"
        with
        | Include.Include_error (Include.Outside_root _) -> ()
        | exn -> raise exn
      end)

let test_loader_security_root () =
  let root = make_temp_directory "vfconf-loader-root-" in
  let project = Filename.concat root "project" in
  Unix.mkdir project 0o700;
  let main = Filename.concat project "main.vf.conf" in
  let shared = Filename.concat root "shared.vf.conf" in
  let write path contents =
    let channel = open_out_bin path in
    output_string channel contents;
    close_out channel
  in
  Fun.protect
    ~finally:(fun () ->
      List.iter (fun path -> if Sys.file_exists path then Sys.remove path) [main; shared];
      Unix.rmdir project;
      Unix.rmdir root)
    (fun () ->
      write shared "shared = true\n";
      write main "include \"../shared.vf.conf\"\n";
      begin
        try
          ignore (Loader.load_file main);
          fail "default loader root should reject parent traversal"
        with
        | Loader.Load_error (Loader.Include_error (Include.Outside_root _)) -> ()
        | exn -> raise exn
      end;
      let result = Loader.load_file ~security_root:root main in
      check (Config.mem ["shared"] (Loader.config result)) "configured security root")

let integer value = Node.dummy (Value.Integer (Int64.of_int value))

let test_merge () =
  let left = Config.empty () |> Config.set ["value"] (integer 1) in
  let right = Config.empty () |> Config.set ["value"] (integer 2) in
  let merged = Merge.overlay left right in
  match Config.find_value ["value"] merged with
  | Value.Integer value -> check (value = 2L) "overlay must keep right value"
  | _ -> fail "merged value has wrong type"

let test_schema () =
  let default = integer 8080 in
  let port = Field.optional ~value_type:Field.Integer ~default "port" in
  let section = Schema.make_section ["server"] |> Schema.add_field port in
  let schema = Schema.make "test" |> Schema.add_section section in
  let result = Schema.validate schema (Config.empty ()) in
  check (Config.mem ["server"; "port"] result.Schema.config) "schema default";
  check (has_code "VFW0404" result.Schema.diagnostics) "default warning"

let test_schema_warnings () =
  let legacy =
    Field.optional
      ~value_type:Field.String
      ~deprecated:true
      ~replacement:"name"
      "legacy"
  in
  let section =
    Schema.make_section ~allow_unknown_fields:true ["app"]
    |> Schema.add_field legacy
  in
  let schema =
    Schema.make ~allow_unknown_sections:true "warnings"
    |> Schema.add_section section
  in
  let config =
    Config.empty ()
    |> Config.set ["app"; "legacy"] (Node.dummy (Value.String ""))
    |> Config.set ["app"; "extra"] (integer 1)
    |> Config.set ["other"; "value"] (integer 2)
  in
  let diagnostics = (Schema.validate schema config).Schema.diagnostics in
  List.iter
    (fun code -> check (has_code code diagnostics) "missing schema diagnostic %s" code)
    ["VFW0402"; "VFW0403"; "VFW0405"; "VFW0701"]

let test_formatter_diagnostics () =
  let source =
    "enabled=on\r\ncolor=#AABBCC\r\ntimeout=60s\r\nmemory=1000B\r\n"
  in
  let diagnostics = Formatter.diagnostics_of_source source (parse source) in
  List.iter
    (fun code -> check (has_code code diagnostics) "missing formatter diagnostic %s" code)
    [
      "VFW0702"; "VFW0703"; "VFW0801"; "VFW0802";
      "VFW0803"; "VFW0804"; "VFW0805"; "VFW0901";
    ]

let test_formatter_idempotence () =
  let source = "[server]\nport=8080\n" in
  let once = Formatter.format (parse source) in
  let twice = Formatter.format (parse once) in
  check_equal once twice "formatter idempotence"

let test_comment_preserving_formatter () =
  let source =
    "# header\nvalue=1 // inline\n/* block\n   comment */\ncolor=#aabbcc\n"
  in
  let original_comments = Source_formatter.comments source in
  let formatted =
    match Api.format ~filename:"comments.vf.conf" source with
    | Ok output -> output
    | Error _ -> fail "comment-preserving formatting failed"
  in
  check
    (Source_formatter.comments formatted = original_comments)
    "formatter lost or changed a comment";
  let formatted_twice =
    match Api.format ~filename:"comments.vf.conf" formatted with
    | Ok output -> output
    | Error _ -> fail "second formatting pass failed"
  in
  check_equal formatted formatted_twice "source formatter idempotence";
  let canonical source =
    match Api.parse ~filename:"comments.vf.conf" source with
    | Ok document -> Formatter.format document
    | Error _ -> fail "formatted source did not parse"
  in
  check_equal
    (canonical source)
    (canonical formatted)
    "parse(format(document)) semantic equality"

let error_kinds =
  [
    Error.Unexpected_character '@';
    Error.Invalid_token "?";
    Error.Unterminated_string;
    Error.Unterminated_comment;
    Error.Invalid_escape "\\q";
    Error.Invalid_number "1..2";
    Error.Invalid_color "#x";
    Error.Invalid_duration "2m";
    Error.Invalid_size "2XB";
    Error.Unexpected_token "]";
    Error.Expected_token {expected = "value"; found = Some "newline"};
    Error.Unexpected_end_of_file;
    Error.Duplicate_key "a";
    Error.Undefined_reference "a";
    Error.Invalid_reference "a";
    Error.Type_mismatch {expected = "integer"; found = "string"};
    Error.Invalid_assignment {key = "a"; operator = "+="};
    Error.Invalid_value "out of range";
    Error.Invalid_condition "not boolean";
    Error.Include_not_found "missing.vf.conf";
    Error.Include_cycle ["a"; "a"];
    Error.Include_depth_exceeded {maximum = 1; path = "a"};
    Error.Invalid_include "a.txt";
    Error.Schema_violation "rule";
    Error.Missing_required_field "name";
    Error.Unknown_field "extra";
    Error.Evaluation_failed "failure";
    Error.Division_by_zero;
    Error.File_not_found "missing";
    Error.Cannot_read_file {path = "x"; message = "denied"};
    Error.Internal_error "bug";
  ]

let warning_kinds =
  [
    Warning.Duplicate_definition "x";
    Warning.Shadowed_definition "x";
    Warning.Unused_definition "x";
    Warning.Unused_section "x";
    Warning.Unused_value "x";
    Warning.Redundant_assignment "x";
    Warning.Overwritten_value "x";
    Warning.Empty_section "x";
    Warning.Empty_array "x";
    Warning.Empty_object "x";
    Warning.Unknown_key "x";
    Warning.Unknown_section "x";
    Warning.Suspicious_value {key = Some "x"; value = "?"};
    Warning.Schema_default_used "x";
    Warning.Schema_additional_field "x";
    Warning.Implicit_conversion {from_type = "integer"; to_type = "float"};
    Warning.Condition_always_true;
    Warning.Condition_always_false;
    Warning.Unreachable_configuration;
    Warning.Include_repeated "x";
    Warning.Include_outside_root "x";
    Warning.Deprecated_key {key = "x"; replacement = Some "y"};
    Warning.Deprecated_value {value = "x"; replacement = Some "y"};
    Warning.Deprecated_syntax {syntax = "x"; replacement = Some "y"};
    Warning.Non_canonical_boolean "on";
    Warning.Non_canonical_size "1kb";
    Warning.Non_canonical_duration "60s";
    Warning.Non_canonical_color "#ABC";
    Warning.Style_issue "spacing";
    Warning.Compatibility_issue "platform";
  ]

let test_every_diagnostic_code () =
  let position = Node.position ~offset:4 ~line:2 ~column:3 () in
  let span = Node.span ~filename:"diagnostics.vf.conf" position position in
  let diagnostics =
    List.map (fun kind -> Error.to_diagnostic (Error.make ~span kind)) error_kinds
    @ List.map (fun kind -> Warning.to_diagnostic (Warning.make ~span kind)) warning_kinds
  in
  let actual = codes diagnostics in
  let unique = List.sort_uniq String.compare actual in
  check (List.length diagnostics = 61) "expected 61 diagnostics";
  check (List.length unique = 61) "diagnostic codes must be unique";
  List.iter
    (fun diagnostic ->
      check (diagnostic.Diagnostic.message <> "") "empty diagnostic message";
      match diagnostic.Diagnostic.span with
      | Some actual ->
          check (actual.Node.start_pos.line = 2) "diagnostic line was not preserved";
          check (actual.Node.start_pos.column = 3) "diagnostic column was not preserved"
      | None -> fail "diagnostic span was not preserved")
    diagnostics

let test_properties_and_fuzzing () =
  let state = Random.State.make [| 0x564643; 0x2026 |] in
  let scalar i =
    match i mod 6 with
    | 0 -> Printf.sprintf "value_%d = %d\n" i (Random.State.int state 10000 - 5000)
    | 1 -> Printf.sprintf "value_%d = %.3f\n" i (Random.State.float state 1000.)
    | 2 -> Printf.sprintf "value_%d = %b\n" i (Random.State.bool state)
    | 3 -> Printf.sprintf "value_%d = \"text-%d\"\n" i i
    | 4 -> Printf.sprintf "value_%d = #%06x\n" i (Random.State.int state 0x1000000)
    | _ -> Printf.sprintf "value_%d = %dms\n" i (Random.State.int state 1000)
  in
  for round = 0 to 99 do
    let source = String.concat "" (List.init (1 + (round mod 8)) scalar) in
    match Api.format source with
    | Error diagnostics -> fail "generated document %d did not format (%d diagnostics)" round (List.length diagnostics)
    | Ok formatted ->
        ignore (parse formatted);
        begin match Api.format formatted with
        | Ok formatted_again -> check_equal formatted formatted_again "formatter idempotence"
        | Error _ -> fail "formatted generated document became unparsable"
        end
  done;
  (* Arbitrary bytes must never escape as an uncaught lexer/parser exception. *)
  for _ = 0 to 199 do
    let length = Random.State.int state 80 in
    let bytes = Bytes.init length (fun _ -> Char.chr (Random.State.int state 256)) in
    try ignore (Parse.string_result ~filename:"fuzz.vf.conf" (Bytes.to_string bytes)) with
    | _ -> fail "parser raised on arbitrary input"
  done

let tests =
  [
    ("lexer and positions", test_lexer_and_positions);
    ("hash comment/color disambiguation", test_hash_disambiguation);
    ("language contract", test_language_contract);
    ("parser and AST", test_parser_and_ast);
    ("semantic analyzer", test_analyzer);
    ("references and conditions", test_references_and_conditions);
    ("evaluator diagnostics", test_evaluator_diagnostics);
    ("evaluator limits and strict types", test_evaluator_limits_and_types);
    ("includes and cycles", test_includes_and_cycles);
    ("loader warnings", test_loader_warnings);
    ("include security", test_include_security);
    ("loader security root", test_loader_security_root);
    ("configuration merge", test_merge);
    ("schema validation", test_schema);
    ("schema warnings", test_schema_warnings);
    ("formatter idempotence", test_formatter_idempotence);
    ("comment-preserving formatter", test_comment_preserving_formatter);
    ("formatter diagnostics", test_formatter_diagnostics);
    ("all diagnostic codes", test_every_diagnostic_code);
    ("properties and fuzzing", test_properties_and_fuzzing);
  ]

let () =
  List.iter
    (fun (name, test) ->
      try
        test ();
        Printf.printf "ok - %s\n%!" name
      with
      | Test_failure message ->
          Printf.eprintf "not ok - %s: %s\n%!" name message;
          exit 1
      | exn ->
          Printf.eprintf "not ok - %s: %s\n%!" name (Printexc.to_string exn);
          exit 1)
    tests
