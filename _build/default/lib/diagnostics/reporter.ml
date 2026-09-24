(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/reporter.ml
 *
 * Diagnostic collection and reporting.
 *)

type format =
  | Human
  | Compact
  | Json

type options = {
  format : format;
  show_codes : bool;
  show_notes : bool;
  show_fixes : bool;
  sort : bool;
  warnings_as_errors : bool;
}

type t = {
  mutable diagnostics : Diagnostic.t list;
  options : options;
}

let default_options =
  {
    format = Human;
    show_codes = true;
    show_notes = true;
    show_fixes = true;
    sort = true;
    warnings_as_errors = false;
  }

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let create ?(options = default_options) () =
  {
    diagnostics = [];
    options;
  }

let clear reporter =
  reporter.diagnostics <- []

let options reporter =
  reporter.options

(* ---------------------------------------------------------- *)
(* Collection                                                 *)
(* ---------------------------------------------------------- *)

let emit reporter diagnostic =
  reporter.diagnostics <-
    diagnostic :: reporter.diagnostics

let emit_many reporter diagnostics =
  List.iter
    (emit reporter)
    diagnostics

let emit_error reporter error =
  emit
    reporter
    (Error.to_diagnostic error)

let diagnostics reporter =
  let values =
    List.rev reporter.diagnostics
  in

  if reporter.options.sort then
    Diagnostic.sort values
  else
    values

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

let count reporter =
  List.length reporter.diagnostics

let is_empty reporter =
  reporter.diagnostics = []

let error_count reporter =
  Diagnostic.error_count
    reporter.diagnostics

let warning_count reporter =
  Diagnostic.warning_count
    reporter.diagnostics

let information_count reporter =
  Diagnostic.information_count
    reporter.diagnostics

let hint_count reporter =
  Diagnostic.hint_count
    reporter.diagnostics

let has_errors reporter =
  Diagnostic.has_errors
    reporter.diagnostics
  ||
  (reporter.options.warnings_as_errors
   && Diagnostic.has_warnings reporter.diagnostics)

let has_warnings reporter =
  Diagnostic.has_warnings
    reporter.diagnostics

let exit_code reporter =
  if has_errors reporter then 1 else 0

(* ---------------------------------------------------------- *)
(* Filtering                                                  *)
(* ---------------------------------------------------------- *)

let filter severity reporter =
  diagnostics reporter
  |> List.filter
       (fun diagnostic ->
         diagnostic.Diagnostic.severity = severity)

let errors reporter =
  filter Diagnostic.Error reporter

let warnings reporter =
  filter Diagnostic.Warning reporter

let informations reporter =
  filter Diagnostic.Information reporter

let hints reporter =
  filter Diagnostic.Hint reporter

(* ---------------------------------------------------------- *)
(* JSON helpers                                               *)
(* ---------------------------------------------------------- *)

let escape_json value =
  let buffer =
    Buffer.create
      (String.length value + 16)
  in

  String.iter
    (function
      | '"' ->
          Buffer.add_string buffer "\\\""

      | '\\' ->
          Buffer.add_string buffer "\\\\"

      | '\b' ->
          Buffer.add_string buffer "\\b"

      | '\012' ->
          Buffer.add_string buffer "\\f"

      | '\n' ->
          Buffer.add_string buffer "\\n"

      | '\r' ->
          Buffer.add_string buffer "\\r"

      | '\t' ->
          Buffer.add_string buffer "\\t"

      | character ->
          let code =
            Char.code character
          in

          if code < 0x20 then
            Buffer.add_string
              buffer
              (Printf.sprintf "\\u%04x" code)
          else
            Buffer.add_char
              buffer
              character)
    value;

  Buffer.contents buffer

let json_string value =
  Printf.sprintf
    "\"%s\""
    (escape_json value)

let json_option function_ = function
  | None ->
      "null"

  | Some value ->
      function_ value

let json_position position =
  Printf.sprintf
    {|{"offset":%d,"line":%d,"column":%d}|}
    position.Node.offset
    position.Node.line
    position.Node.column

let json_span span =
  Printf.sprintf
    {|{"file":%s,"start":%s,"end":%s}|}
    (json_string span.Node.filename)
    (json_position span.Node.start_pos)
    (json_position span.Node.end_pos)

let json_label (label : Diagnostic.label) =
  let message =
    json_option
      json_string
      label.Diagnostic.message
  in

  Printf.sprintf
    {|{"span":%s,"message":%s,"primary":%s}|}
    (json_span label.Diagnostic.span)
    message
    (if label.Diagnostic.primary then "true" else "false")

let json_fix (fix : Diagnostic.fix) =
  let message =
    json_option
      json_string
      fix.Diagnostic.message
  in

  Printf.sprintf
    {|{"span":%s,"replacement":%s,"message":%s}|}
    (json_span fix.Diagnostic.span)
    (json_string fix.Diagnostic.replacement)
    message

let json_list function_ values =
  let contents =
    values
    |> List.map function_
    |> String.concat ","
  in

  "[" ^ contents ^ "]"

let diagnostic_to_json diagnostic =
  let code =
    json_option
      json_string
      diagnostic.Diagnostic.code
  in

  let span =
    json_option
      json_span
      diagnostic.Diagnostic.span
  in

  let labels =
    json_list
      json_label
      diagnostic.Diagnostic.labels
  in

  let notes =
    json_list
      json_string
      diagnostic.Diagnostic.notes
  in

  let fixes =
    json_list
      json_fix
      diagnostic.Diagnostic.fixes
  in

  Printf.sprintf
    {|{"severity":%s,"code":%s,"message":%s,"span":%s,"labels":%s,"notes":%s,"fixes":%s}|}
    (json_string
       (Diagnostic.string_of_severity
          diagnostic.Diagnostic.severity))
    code
    (json_string diagnostic.Diagnostic.message)
    span
    labels
    notes
    fixes

(* ---------------------------------------------------------- *)
(* Compact reporting                                          *)
(* ---------------------------------------------------------- *)

let pp_compact formatter diagnostic =
  begin
    match Diagnostic.primary_span diagnostic with
    | Some span ->
        Format.fprintf
          formatter
          "%s:%d:%d: "
          span.Node.filename
          span.Node.start_pos.Node.line
          span.Node.start_pos.Node.column

    | None ->
        ()
  end;

  Format.fprintf
    formatter
    "%s"
    (Diagnostic.string_of_severity
       diagnostic.Diagnostic.severity);

  begin
    match diagnostic.Diagnostic.code with
    | Some code ->
        Format.fprintf
          formatter
          "[%s]"
          code

    | None ->
        ()
  end;

  Format.fprintf
    formatter
    ": %s"
    diagnostic.Diagnostic.message

(* ---------------------------------------------------------- *)
(* Human reporting                                            *)
(* ---------------------------------------------------------- *)

let pp_human
    options
    formatter
    diagnostic =
  begin
    match Diagnostic.primary_span diagnostic with
    | Some span ->
        Format.fprintf
          formatter
          "%s:%d:%d: "
          span.Node.filename
          span.Node.start_pos.Node.line
          span.Node.start_pos.Node.column

    | None ->
        ()
  end;

  Format.fprintf
    formatter
    "%s"
    (Diagnostic.string_of_severity
       diagnostic.Diagnostic.severity);

  begin
    match
      options.show_codes,
      diagnostic.Diagnostic.code
    with
    | true, Some code ->
        Format.fprintf
          formatter
          "[%s]"
          code

    | _ ->
        ()
  end;

  Format.fprintf
    formatter
    ": %s"
    diagnostic.Diagnostic.message;

  List.iter
    (fun label ->
      Format.fprintf
        formatter
        "@,%s %a"
        (if label.Diagnostic.primary
         then "-->"
         else ":::")
        Node.pp_span
        label.Diagnostic.span;

      match label.Diagnostic.message with
      | None ->
          ()

      | Some message ->
          Format.fprintf
            formatter
            ": %s"
            message)
    diagnostic.Diagnostic.labels;

  if options.show_notes then
    List.iter
      (fun note ->
        Format.fprintf
          formatter
          "@,note: %s"
          note)
      diagnostic.Diagnostic.notes;

  if options.show_fixes then
    List.iter
      (fun (fix : Diagnostic.fix) ->
        Format.fprintf
          formatter
          "@,fix: replace %a with %S"
          Node.pp_span
          fix.Diagnostic.span
          fix.Diagnostic.replacement;

        match fix.Diagnostic.message with
        | None ->
            ()

        | Some message ->
            Format.fprintf
              formatter
              " (%s)"
              message)
      diagnostic.Diagnostic.fixes

(* ---------------------------------------------------------- *)
(* Reporting                                                  *)
(* ---------------------------------------------------------- *)

let pp_diagnostic
    options
    formatter
    diagnostic =
  match options.format with
  | Human ->
      pp_human
        options
        formatter
        diagnostic

  | Compact ->
      pp_compact
        formatter
        diagnostic

  | Json ->
      Format.pp_print_string
        formatter
        (diagnostic_to_json diagnostic)

let pp reporter formatter =
  let values =
    diagnostics reporter
  in

  match reporter.options.format with
  | Json ->
      Format.fprintf
        formatter
        "[";

      List.iteri
        (fun index diagnostic ->
          if index > 0 then
            Format.fprintf formatter ",";

          pp_diagnostic
            reporter.options
            formatter
            diagnostic)
        values;

      Format.fprintf
        formatter
        "]"

  | Human
  | Compact ->
      Format.fprintf
        formatter
        "@[<v>";

      List.iteri
        (fun index diagnostic ->
          if index > 0 then
            Format.fprintf
              formatter
              "@,";

          pp_diagnostic
            reporter.options
            formatter
            diagnostic)
        values;

      Format.fprintf
        formatter
        "@]"

let to_string reporter =
  Format.asprintf
    "%t"
    (pp reporter)

let print reporter =
  pp
      reporter
      Format.std_formatter;

  Format.pp_print_newline
    Format.std_formatter
    ()

let print_error reporter =
  pp
      reporter
      Format.err_formatter;

  Format.pp_print_newline
    Format.err_formatter
    ()

(* ---------------------------------------------------------- *)
(* Summary                                                    *)
(* ---------------------------------------------------------- *)

let pp_summary reporter formatter =
  Format.fprintf
    formatter
    "%d error(s), %d warning(s), %d information message(s), %d hint(s)"
    (error_count reporter)
    (warning_count reporter)
    (information_count reporter)
    (hint_count reporter)

let summary reporter =
  Format.asprintf
    "%t"
    (pp_summary reporter)
