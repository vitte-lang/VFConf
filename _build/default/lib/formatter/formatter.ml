(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/formatter/formatter.ml
 *
 * Canonical formatter for VFConf source files.
 *)

type options = {
  indent_width : int;
  final_newline : bool;
  space_around_operators : bool;
  multiline_arrays : bool;
  multiline_objects : bool;
  sort_object_keys : bool;
}

let default_options =
  {
    indent_width = 2;
    final_newline = true;
    space_around_operators = true;
    multiline_arrays = false;
    multiline_objects = true;
    sort_object_keys = false;
  }

(* ---------------------------------------------------------- *)
(* Basic helpers                                              *)
(* ---------------------------------------------------------- *)

let spaces count =
  if count <= 0 then
    ""
  else
    String.make count ' '

let indentation options level =
  spaces (level * options.indent_width)

let string_of_path path =
  String.concat "." path

let string_of_reference path =
  "$" ^ string_of_path path

let assignment_operator = function
  | Statement.Assign ->
      "="
  | Statement.Define_assign ->
      ":="
  | Statement.Add_assign ->
      "+="
  | Statement.Sub_assign ->
      "-="

let comparison_operator = function
  | Statement.Equal ->
      "=="
  | Statement.Not_equal ->
      "!="
  | Statement.Less ->
      "<"
  | Statement.Less_equal ->
      "<="
  | Statement.Greater ->
      ">"
  | Statement.Greater_equal ->
      ">="

let logical_operator = function
  | Statement.And ->
      "&&"
  | Statement.Or ->
      "||"

let operator_spacing options operator =
  if options.space_around_operators then
    " " ^ operator ^ " "
  else
    operator

(* ---------------------------------------------------------- *)
(* String formatting                                          *)
(* ---------------------------------------------------------- *)

let escape_string value =
  let buffer = Buffer.create (String.length value + 8) in

  String.iter
    (function
      | '"' ->
          Buffer.add_string buffer "\\\""
      | '\\' ->
          Buffer.add_string buffer "\\\\"
      | '\n' ->
          Buffer.add_string buffer "\\n"
      | '\r' ->
          Buffer.add_string buffer "\\r"
      | '\t' ->
          Buffer.add_string buffer "\\t"
      | '\b' ->
          Buffer.add_string buffer "\\b"
      | '\012' ->
          Buffer.add_string buffer "\\f"
      | character ->
          Buffer.add_char buffer character)
    value;

  Buffer.contents buffer

let quote_string value =
  "\"" ^ escape_string value ^ "\""

(* ---------------------------------------------------------- *)
(* Primitive value formatting                                 *)
(* ---------------------------------------------------------- *)

let string_of_float value =
  match classify_float value with
  | FP_nan ->
      "nan"
  | FP_infinite when value > 0.0 ->
      "inf"
  | FP_infinite ->
      "-inf"
  | FP_normal
  | FP_subnormal
  | FP_zero ->
      let result =
        Printf.sprintf "%.17g" value
      in

      if
        not (String.contains result '.')
        && not (String.contains result 'e')
        && not (String.contains result 'E')
      then
        result ^ ".0"
      else
        result

let string_of_duration_unit = function
  | Value.Nanosecond ->
      "ns"
  | Value.Microsecond ->
      "us"
  | Value.Millisecond ->
      "ms"
  | Value.Second ->
      "s"
  | Value.Minute ->
      "min"
  | Value.Hour ->
      "h"

let string_of_size_unit = function
  | Value.Byte ->
      "B"
  | Value.Kilobyte ->
      "KB"
  | Value.Megabyte ->
      "MB"
  | Value.Gigabyte ->
      "GB"
  | Value.Kibibyte ->
      "KiB"
  | Value.Mebibyte ->
      "MiB"
  | Value.Gibibyte ->
      "GiB"

let clamp_byte value =
  max 0 (min 255 value)

let string_of_color = function
  | Value.Hex value ->
      if String.length value > 0 && value.[0] = '#' then
        value
      else
        "#" ^ value

  | Value.Rgb { red; green; blue } ->
      Printf.sprintf
        "rgb(%d, %d, %d)"
        (clamp_byte red)
        (clamp_byte green)
        (clamp_byte blue)

  | Value.Rgba { red; green; blue; alpha } ->
      Printf.sprintf
        "rgba(%d, %d, %d, %s)"
        (clamp_byte red)
        (clamp_byte green)
        (clamp_byte blue)
        (string_of_float alpha)

(* ---------------------------------------------------------- *)
(* Value formatting                                           *)
(* ---------------------------------------------------------- *)

let rec format_value
    ?(options = default_options)
    ?(level = 0)
    value =
  match value.Node.value with
  | Value.String string ->
      quote_string string

  | Value.Integer integer ->
      Int64.to_string integer

  | Value.Float float ->
      string_of_float float

  | Value.Boolean boolean ->
      if boolean then "true" else "false"

  | Value.Null ->
      "null"

  | Value.Reference reference ->
      string_of_reference reference

  | Value.Color color ->
      string_of_color color

  | Value.Duration (amount, unit) ->
      string_of_float amount
      ^ string_of_duration_unit unit

  | Value.Size (amount, unit) ->
      string_of_float amount
      ^ string_of_size_unit unit

  | Value.Array values ->
      format_array
        ~options
        ~level
        values

  | Value.Object entries ->
      format_object
        ~options
        ~level
        entries

and format_array
    ~options
    ~level
    values =
  match values with
  | [] ->
      "[]"

  | _ when not options.multiline_arrays ->
      let contents =
        values
        |> List.map
             (format_value
                ~options
                ~level)
        |> String.concat ", "
      in
      "[" ^ contents ^ "]"

  | _ ->
      let child_level =
        level + 1
      in

      let contents =
        values
        |> List.map
             (fun value ->
               indentation options child_level
               ^ format_value
                   ~options
                   ~level:child_level
                   value)
        |> String.concat ",\n"
      in

      "[\n"
      ^ contents
      ^ "\n"
      ^ indentation options level
      ^ "]"

and format_object
    ~options
    ~level
    entries =
  match entries with
  | [] ->
      "{}"

  | _ ->
      let entries =
        if options.sort_object_keys then
          List.sort
            (fun left right ->
              String.compare
                (string_of_path left.Value.key)
                (string_of_path right.Value.key))
            entries
        else
          entries
      in

      if not options.multiline_objects then
        let contents =
          entries
          |> List.map
               (fun entry ->
                 string_of_path entry.Value.key
                 ^ ": "
                 ^ format_value
                     ~options
                     ~level
                     entry.Value.value)
          |> String.concat ", "
        in

        "{ " ^ contents ^ " }"
      else
        let child_level =
          level + 1
        in

        let contents =
          entries
          |> List.map
               (fun entry ->
                 indentation options child_level
                 ^ string_of_path entry.Value.key
                 ^ ": "
                 ^ format_value
                     ~options
                     ~level:child_level
                     entry.Value.value)
          |> String.concat ",\n"
        in

        "{\n"
        ^ contents
        ^ "\n"
        ^ indentation options level
        ^ "}"

(* ---------------------------------------------------------- *)
(* Condition formatting                                       *)
(* ---------------------------------------------------------- *)

let condition_precedence condition =
  match condition.Node.value with
  | Statement.Boolean _
  | Statement.Reference _
  | Statement.Compare _ ->
      4

  | Statement.Not _ ->
      3

  | Statement.Logical { operator = Statement.And; _ } ->
      2

  | Statement.Logical { operator = Statement.Or; _ } ->
      1

let rec format_condition
    ?(options = default_options)
    ?(parent_precedence = 0)
    condition =
  let precedence =
    condition_precedence condition
  in

  let result =
    match condition.Node.value with
    | Statement.Boolean boolean ->
        if boolean then "true" else "false"

    | Statement.Reference reference ->
        string_of_reference reference

    | Statement.Not inner ->
        "!"
        ^ format_condition
            ~options
            ~parent_precedence:precedence
            inner

    | Statement.Logical { left; operator; right } ->
        let operator =
          logical_operator operator
        in

        format_condition
          ~options
          ~parent_precedence:precedence
          left
        ^ operator_spacing options operator
        ^ format_condition
            ~options
            ~parent_precedence:precedence
            right

    | Statement.Compare { reference; operator; value } ->
        string_of_reference reference
        ^ operator_spacing
            options
            (comparison_operator operator)
        ^ format_value
            ~options
            value
  in

  if precedence < parent_precedence then
    "(" ^ result ^ ")"
  else
    result

(* ---------------------------------------------------------- *)
(* Statement formatting                                       *)
(* ---------------------------------------------------------- *)

let rec format_statement
    ?(options = default_options)
    ?(level = 0)
    statement =
  let indent =
    indentation options level
  in

  match statement.Node.value with
  | Statement.Assignment assignment ->
      indent
      ^ string_of_path assignment.Statement.key
      ^ operator_spacing
          options
          (assignment_operator assignment.Statement.operator)
      ^ format_value
          ~options
          ~level
          assignment.Statement.value
      ^ ";"

  | Statement.Include include_statement ->
      indent
      ^ "include "
      ^ quote_string include_statement.Statement.path
      ^ ";"

  | Statement.Define definition ->
      indent
      ^ "define "
      ^ definition.Statement.name
      ^ operator_spacing options "="
      ^ format_value
          ~options
          ~level
          definition.Statement.value
      ^ ";"

  | Statement.Section section ->
      format_section
        ~options
        ~level
        section

  | Statement.Conditional conditional ->
      format_conditional
        ~options
        ~level
        conditional

and format_section
    ~options
    ~level
    section =
  let indent =
    indentation options level
  in

  let header =
    indent
    ^ "["
    ^ string_of_path section.Statement.name
    ^ "]"
  in

  match section.Statement.body with
  | [] ->
      header

  | body ->
      header
      ^ "\n"
      ^ format_statements
          ~options
          ~level
          body

and format_conditional
    ~options
    ~level
    conditional =
  let indent =
    indentation options level
  in

  let condition =
    format_condition
      ~options
      conditional.Statement.condition
  in

  let then_body =
    format_block
      ~options
      ~level
      conditional.Statement.then_branch
  in

  match conditional.Statement.else_branch with
  | None ->
      indent
      ^ "when "
      ^ condition
      ^ " "
      ^ then_body

  | Some else_branch ->
      let else_body =
        format_block
          ~options
          ~level
          else_branch
      in

      indent
      ^ "when "
      ^ condition
      ^ " "
      ^ then_body
      ^ " else "
      ^ else_body

and format_block
    ~options
    ~level
    statements =
  match statements with
  | [] ->
      "{}"

  | _ ->
      "{\n"
      ^ format_statements
          ~options
          ~level:(level + 1)
          statements
      ^ "\n"
      ^ indentation options level
      ^ "}"

and format_statements
    ?(options = default_options)
    ?(level = 0)
    statements =
  statements
  |> List.map
       (format_statement
          ~options
          ~level)
  |> String.concat "\n"

(* ---------------------------------------------------------- *)
(* Document formatting                                        *)
(* ---------------------------------------------------------- *)

let format_document
    ?(options = default_options)
    statements =
  let output =
    format_statements
      ~options
      statements
  in

  if options.final_newline then
    if output = "" then
      ""
    else
      output ^ "\n"
  else
    output

let format =
  format_document

(* ---------------------------------------------------------- *)
(* Output                                                     *)
(* ---------------------------------------------------------- *)

let pp_value
    ?(options = default_options)
    formatter
    value =
  Format.pp_print_string
    formatter
    (format_value
       ~options
       value)

let pp_condition
    ?(options = default_options)
    formatter
    condition =
  Format.pp_print_string
    formatter
    (format_condition
       ~options
       condition)

let pp_statement
    ?(options = default_options)
    formatter
    statement =
  Format.pp_print_string
    formatter
    (format_statement
       ~options
       statement)

let pp
    ?(options = default_options)
    formatter
    statements =
  Format.pp_print_string
    formatter
    (format_document
       ~options
       statements)