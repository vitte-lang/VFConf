(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/diagnostic.ml
 *
 * Canonical diagnostic representation.
 *
 * All lexer, parser, semantic, schema, loader and formatter
 * diagnostics should be converted to this representation.
 *)

type severity =
  | Error
  | Warning
  | Information
  | Hint

type code = string

type category =
  | Lexical
  | Syntax
  | Semantic
  | Configuration
  | Include
  | Reference
  | Type
  | Schema
  | Evaluation
  | Formatting
  | Style
  | Compatibility
  | Deprecation
  | Io
  | Internal

type source =
  | Lexer
  | Parser
  | Analyzer
  | Resolver
  | Validator
  | Loader
  | Schema_validator
  | Evaluator
  | Formatter
  | Cli
  | Other of string

type applicability =
  | Machine_applicable
  | Maybe_incorrect
  | Has_placeholders
  | Unspecified

type related = {
  span : Node.span;
  message : string;
}

type label = {
  span : Node.span;
  message : string option;
  primary : bool;
}

type note = string

type fix = {
  span : Node.span;
  replacement : string;
  message : string option;
  applicability : applicability;
}

type t = {
  severity : severity;
  code : code option;
  message : string;
  span : Node.span option;
  labels : label list;
  notes : note list;
  fixes : fix list;

  category : category option;
  source : source option;
  help : string list;
  related : related list;
}

(* ---------------------------------------------------------- *)
(* Severity                                                   *)
(* ---------------------------------------------------------- *)

let severity_rank = function
  | Error -> 0
  | Warning -> 1
  | Information -> 2
  | Hint -> 3

let compare_severity left right =
  Int.compare
    (severity_rank left)
    (severity_rank right)

let string_of_severity = function
  | Error -> "error"
  | Warning -> "warning"
  | Information -> "information"
  | Hint -> "hint"

let short_string_of_severity = function
  | Error -> "E"
  | Warning -> "W"
  | Information -> "I"
  | Hint -> "H"

let severity_of_string value =
  match String.lowercase_ascii value with
  | "error"
  | "err"
  | "e" ->
      Some Error

  | "warning"
  | "warn"
  | "w" ->
      Some Warning

  | "information"
  | "info"
  | "i" ->
      Some Information

  | "hint"
  | "h" ->
      Some Hint

  | _ ->
      None

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let make
    ?code
    ?span
    ?category
    ?source
    ?(help = [])
    ?(related = [])
    ?(labels = [])
    ?(notes = [])
    ?(fixes = [])
    severity
    message =
  {
    severity;
    code;
    message;
    span;
    labels;
    notes;
    fixes;
      category;
      source;
      help;
      related;
  }

let error
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    message =
  make
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    Error
    message

let warning
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    message =
  make
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    Warning
    message

let information
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    message =
  make
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    Information
    message

let hint
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    message =
  make
    ?code
    ?span
    ?labels
    ?notes
    ?fixes
    Hint
    message

(* ---------------------------------------------------------- *)
(* Labels                                                     *)
(* ---------------------------------------------------------- *)

let label
    ?message
    ?(primary = false)
    span =
  {
    span;
    message;
    primary;
  }

let primary_label
    ?message
    span =
  label
    ?message
    ~primary:true
    span

let secondary_label
    ?message
    span =
  label
    ?message
    ~primary:false
    span

let add_label label diagnostic =
  {
    diagnostic with
    labels =
      diagnostic.labels @ [label];
  }

let add_primary_label
    ?message
    span
    diagnostic =
  add_label
    (primary_label ?message span)
    diagnostic

let add_secondary_label
    ?message
    span
    diagnostic =
  add_label
    (secondary_label ?message span)
    diagnostic

(* ---------------------------------------------------------- *)
(* Notes                                                      *)
(* ---------------------------------------------------------- *)

let add_note note diagnostic =
  {
    diagnostic with
    notes =
      diagnostic.notes @ [note];
  }

let add_notes notes diagnostic =
  {
    diagnostic with
    notes =
      diagnostic.notes @ notes;
  }

(* ---------------------------------------------------------- *)
(* Fixes                                                      *)
(* ---------------------------------------------------------- *)

let fix
    ?message
    ?(applicability = Unspecified)
    span
    replacement =
  {
    span;
    replacement;
    message;
      applicability;
  }

let add_fix fix diagnostic =
  {
    diagnostic with
    fixes =
      diagnostic.fixes @ [fix];
  }

let add_replacement
    ?message
    span
    replacement
    diagnostic =
  add_fix
    (fix ?message span replacement)
    diagnostic

(* ---------------------------------------------------------- *)
(* Mutation-style helpers                                     *)
(* ---------------------------------------------------------- *)

let with_code code diagnostic =
  {
    diagnostic with
    code = Some code;
  }

let without_code diagnostic =
  {
    diagnostic with
    code = None;
  }

let with_span span diagnostic =
  {
    diagnostic with
    span = Some span;
  }

let without_span diagnostic =
  {
    diagnostic with
    span = None;
  }

let with_severity severity diagnostic =
  {
    diagnostic with
    severity;
  }

let with_message message diagnostic =
  {
    diagnostic with
    message;
  }


(* ---------------------------------------------------------- *)
(* Extended diagnostic metadata                               *)
(* ---------------------------------------------------------- *)

let with_category category diagnostic =
  {
    diagnostic with
    category = Some category;
  }

let with_source source diagnostic =
  {
    diagnostic with
    source = Some source;
  }

let add_help message diagnostic =
  {
    diagnostic with
    help = diagnostic.help @ [message];
  }

let add_related span message diagnostic =
  {
    diagnostic with
    related =
      diagnostic.related
      @ [
          {
            span;
            message;
          };
        ];
  }

let string_of_category = function
  | Lexical -> "lexical"
  | Syntax -> "syntax"
  | Semantic -> "semantic"
  | Configuration -> "configuration"
  | Include -> "include"
  | Reference -> "reference"
  | Type -> "type"
  | Schema -> "schema"
  | Evaluation -> "evaluation"
  | Formatting -> "formatting"
  | Style -> "style"
  | Compatibility -> "compatibility"
  | Deprecation -> "deprecation"
  | Io -> "io"
  | Internal -> "internal"

let string_of_source = function
  | Lexer -> "lexer"
  | Parser -> "parser"
  | Analyzer -> "analyzer"
  | Resolver -> "resolver"
  | Validator -> "validator"
  | Loader -> "loader"
  | Schema_validator -> "schema"
  | Evaluator -> "evaluator"
  | Formatter -> "formatter"
  | Cli -> "cli"
  | Other value -> value

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

let is_error diagnostic =
  diagnostic.severity = Error

let is_warning diagnostic =
  diagnostic.severity = Warning

let is_information diagnostic =
  diagnostic.severity = Information

let is_hint diagnostic =
  diagnostic.severity = Hint

let has_code diagnostic =
  match diagnostic.code with
  | Some _ -> true
  | None -> false

let has_span diagnostic =
  match diagnostic.span with
  | Some _ -> true
  | None -> false

let has_fixes diagnostic =
  diagnostic.fixes <> []

let primary_span diagnostic =
  let rec find = function
    | [] ->
        diagnostic.span

    | label :: rest ->
        if label.primary then
          Some label.span
        else
          find rest
  in

  find diagnostic.labels

let filename diagnostic =
  match primary_span diagnostic with
  | Some span ->
      Some span.Node.filename
  | None ->
      None

(* ---------------------------------------------------------- *)
(* Ordering                                                   *)
(* ---------------------------------------------------------- *)

let compare_position
    left
    right =
  let compare_filename =
    String.compare
      left.Node.filename
      right.Node.filename
  in

  if compare_filename <> 0 then
    compare_filename
  else
    let compare_offset =
      Int.compare
        left.Node.start_pos.Node.offset
        right.Node.start_pos.Node.offset
    in

    if compare_offset <> 0 then
      compare_offset
    else
      Int.compare
        left.Node.end_pos.Node.offset
        right.Node.end_pos.Node.offset

let compare left right =
  match primary_span left, primary_span right with
  | Some left_span, Some right_span ->
      let position =
        compare_position
          left_span
          right_span
      in

      if position <> 0 then
        position
      else
        let severity =
          compare_severity
            left.severity
            right.severity
        in

        if severity <> 0 then
          severity
        else
          String.compare
            left.message
            right.message

  | Some _, None ->
      -1

  | None, Some _ ->
      1

  | None, None ->
      let severity =
        compare_severity
          left.severity
          right.severity
      in

      if severity <> 0 then
        severity
      else
        String.compare
          left.message
          right.message

let sort diagnostics =
  List.sort compare diagnostics

(* ---------------------------------------------------------- *)
(* Counting                                                   *)
(* ---------------------------------------------------------- *)

let count_severity severity diagnostics =
  List.fold_left
    (fun count diagnostic ->
      if diagnostic.severity = severity then
        count + 1
      else
        count)
    0
    diagnostics

let error_count diagnostics =
  count_severity Error diagnostics

let warning_count diagnostics =
  count_severity Warning diagnostics

let information_count diagnostics =
  count_severity Information diagnostics

let hint_count diagnostics =
  count_severity Hint diagnostics

let has_errors diagnostics =
  List.exists is_error diagnostics

let has_warnings diagnostics =
  List.exists is_warning diagnostics

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_code formatter = function
  | None ->
      ()

  | Some code ->
      Format.fprintf
        formatter
        "[%s]"
        code

let pp_header formatter diagnostic =
  match diagnostic.code with
  | None ->
      Format.fprintf
        formatter
        "%s: %s"
        (string_of_severity diagnostic.severity)
        diagnostic.message

  | Some code ->
      Format.fprintf
        formatter
        "%s[%s]: %s"
        (string_of_severity diagnostic.severity)
        code
        diagnostic.message

let pp_location formatter span =
  Format.fprintf
    formatter
    "%s:%d:%d"
    span.Node.filename
    span.Node.start_pos.Node.line
    span.Node.start_pos.Node.column

let pp_label formatter label =
  Format.fprintf
    formatter
    "%s %a"
    (if label.primary then "-->" else ":::")
    Node.pp_span
    label.span;

  match label.message with
  | None ->
      ()

  | Some message ->
      Format.fprintf
        formatter
        ": %s"
        message

let pp_fix formatter (fix : fix) =
  Format.fprintf
    formatter
    "replace %a with %S"
    Node.pp_span
    fix.span
    fix.replacement;

  match fix.message with
  | None ->
      ()

  | Some message ->
      Format.fprintf
        formatter
        " (%s)"
        message

let pp formatter diagnostic =
  Format.fprintf
    formatter
    "@[<v>";

  begin
    match primary_span diagnostic with
    | None ->
        ()

    | Some span ->
        Format.fprintf
          formatter
          "%a: "
          pp_location
          span
  end;

  pp_header
    formatter
    diagnostic;

  List.iter
    (fun label ->
      Format.fprintf
        formatter
        "@,%a"
        pp_label
        label)
    diagnostic.labels;

  List.iter
    (fun note ->
      Format.fprintf
        formatter
        "@,note: %s"
        note)
    diagnostic.notes;

  List.iter
    (fun fix ->
      Format.fprintf
        formatter
        "@,fix: %a"
        pp_fix
        fix)
    diagnostic.fixes;

  Format.fprintf
    formatter
    "@]"

let to_string diagnostic =
  Format.asprintf
    "%a"
    pp
    diagnostic

(* ---------------------------------------------------------- *)
(* Collection printing                                        *)
(* ---------------------------------------------------------- *)

let pp_all formatter diagnostics =
  let diagnostics =
    sort diagnostics
  in

  Format.fprintf formatter "@[<v>";

  List.iteri
    (fun index diagnostic ->
      if index > 0 then
        Format.fprintf
          formatter
          "@,@,";

      pp
        formatter
        diagnostic)
    diagnostics;

  Format.fprintf formatter "@]"

let all_to_string diagnostics =
  Format.asprintf
    "%a"
    pp_all
    diagnostics