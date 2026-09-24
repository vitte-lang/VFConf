(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/ast.ml
 *
 * Canonical Abstract Syntax Tree.
 *)

(* ---------------------------------------------------------- *)
(* Source locations                                           *)
(* ---------------------------------------------------------- *)

type position = {
  offset : int;
  line : int;
  column : int;
}

type span = {
  filename : string;
  start_pos : position;
  end_pos : position;
}

type 'a located = {
  value : 'a;
  span : span;
}

let located span value =
  { value; span }

(* ---------------------------------------------------------- *)
(* Names                                                      *)
(* ---------------------------------------------------------- *)

type identifier = string

type path = identifier list

type key = path

type section_name = path

type reference = path

(* ---------------------------------------------------------- *)
(* Operators                                                  *)
(* ---------------------------------------------------------- *)

type assignment_operator =
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign

type comparison_operator =
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal

type logical_operator =
  | And
  | Or

(* ---------------------------------------------------------- *)
(* Units                                                      *)
(* ---------------------------------------------------------- *)

type duration_unit =
  | Nanosecond
  | Microsecond
  | Millisecond
  | Second
  | Minute
  | Hour

type size_unit =
  | Byte
  | Kilobyte
  | Megabyte
  | Gigabyte
  | Kibibyte
  | Mebibyte
  | Gibibyte

(* ---------------------------------------------------------- *)
(* Colors                                                     *)
(* ---------------------------------------------------------- *)

type color =
  | Hex of string
  | Rgb of {
      red : int;
      green : int;
      blue : int;
    }
  | Rgba of {
      red : int;
      green : int;
      blue : int;
      alpha : float;
    }

(* ---------------------------------------------------------- *)
(* Values                                                     *)
(* ---------------------------------------------------------- *)

type value =
  | String of string
  | Integer of int64
  | Float of float
  | Boolean of bool
  | Null
  | Array of value located list
  | Object of object_entry list
  | Reference of reference
  | Color of color
  | Duration of float * duration_unit
  | Size of float * size_unit

and object_entry = {
  object_key : key;
  object_value : value located;
  object_span : span;
}

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

type condition =
  | Condition_reference of reference
  | Condition_boolean of bool
  | Condition_not of condition located
  | Condition_logical of {
      left : condition located;
      operator : logical_operator;
      right : condition located;
    }
  | Condition_compare of {
      reference : reference;
      operator : comparison_operator;
      value : value located;
    }

(* ---------------------------------------------------------- *)
(* Assignments                                                *)
(* ---------------------------------------------------------- *)

type assignment = {
  key : key;
  operator : assignment_operator;
  value : value located;
}

(* ---------------------------------------------------------- *)
(* Includes                                                   *)
(* ---------------------------------------------------------- *)

type include_statement = {
  path : string;
}

(* ---------------------------------------------------------- *)
(* Definitions                                                *)
(* ---------------------------------------------------------- *)

type define_statement = {
  name : identifier;
  value : value located;
}

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

type statement =
  | Assignment of assignment
  | Include of include_statement
  | Define of define_statement
  | Section of section
  | Conditional of conditional

and section = {
  name : section_name;
  body : statement located list;
}

and conditional = {
  condition : condition located;
  then_branch : statement located list;
  else_branch : statement located list option;
}

(* ---------------------------------------------------------- *)
(* Document                                                   *)
(* ---------------------------------------------------------- *)

type document = {
  statements : statement located list;
  filename : string;
}

let empty_document ?(filename = "") () =
  {
    statements = [];
    filename;
  }

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

let path_of_string value =
  if value = "" then
    []
  else
    String.split_on_char '.' value

let string_of_path path =
  String.concat "." path

(* ---------------------------------------------------------- *)
(* Operator printers                                          *)
(* ---------------------------------------------------------- *)

let string_of_assignment_operator = function
  | Assign ->
      "="
  | Define_assign ->
      ":="
  | Add_assign ->
      "+="
  | Sub_assign ->
      "-="

let string_of_comparison_operator = function
  | Equal ->
      "=="
  | Not_equal ->
      "!="
  | Less ->
      "<"
  | Less_equal ->
      "<="
  | Greater ->
      ">"
  | Greater_equal ->
      ">="

let string_of_logical_operator = function
  | And ->
      "&&"
  | Or ->
      "||"

(* ---------------------------------------------------------- *)
(* Unit printers                                              *)
(* ---------------------------------------------------------- *)

let string_of_duration_unit = function
  | Nanosecond ->
      "ns"
  | Microsecond ->
      "us"
  | Millisecond ->
      "ms"
  | Second ->
      "s"
  | Minute ->
      "min"
  | Hour ->
      "h"

let string_of_size_unit = function
  | Byte ->
      "B"
  | Kilobyte ->
      "KB"
  | Megabyte ->
      "MB"
  | Gigabyte ->
      "GB"
  | Kibibyte ->
      "KiB"
  | Mebibyte ->
      "MiB"
  | Gibibyte ->
      "GiB"

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_position formatter (position : position) =
  Format.fprintf
    formatter
    "%d:%d"
    position.line
    position.column

let pp_span formatter (span : span) =
  Format.fprintf
    formatter
    "%s:%a-%a"
    span.filename
    pp_position span.start_pos
    pp_position span.end_pos

let pp_path formatter path =
  Format.pp_print_string
    formatter
    (string_of_path path)

let pp_color formatter = function
  | Hex value ->
      Format.fprintf formatter "#%s" value

  | Rgb { red; green; blue } ->
      Format.fprintf
        formatter
        "rgb(%d,%d,%d)"
        red
        green
        blue

  | Rgba { red; green; blue; alpha } ->
      Format.fprintf
        formatter
        "rgba(%d,%d,%d,%g)"
        red
        green
        blue
        alpha

let rec pp_value formatter = function
  | String value ->
      Format.fprintf formatter "%S" value

  | Integer value ->
      Format.fprintf formatter "%Ld" value

  | Float value ->
      Format.fprintf formatter "%g" value

  | Boolean value ->
      Format.pp_print_bool formatter value

  | Null ->
      Format.pp_print_string formatter "null"

  | Reference path ->
      Format.fprintf
        formatter
        "$%a"
        pp_path
        path

  | Color color ->
      pp_color formatter color

  | Duration (number, unit) ->
      Format.fprintf
        formatter
        "%g%s"
        number
        (string_of_duration_unit unit)

  | Size (number, unit) ->
      Format.fprintf
        formatter
        "%g%s"
        number
        (string_of_size_unit unit)

  | Array values ->
      Format.fprintf formatter "[";

      List.iteri
        (fun index (value : value located) ->
          if index > 0 then
            Format.fprintf formatter ", ";

          pp_value formatter value.value)
        values;

      Format.fprintf formatter "]"

  | Object entries ->
      Format.fprintf formatter "{";

      List.iteri
        (fun index entry ->
          if index > 0 then
            Format.fprintf formatter ", ";

          Format.fprintf
            formatter
            "%a: %a"
            pp_path
            entry.object_key
            pp_value
            entry.object_value.value)
        entries;

      Format.fprintf formatter "}"

(* ---------------------------------------------------------- *)
(* AST dump                                                   *)
(* ---------------------------------------------------------- *)

let indent formatter depth =
  Format.pp_print_string
    formatter
    (String.make (depth * 2) ' ')

let rec dump_condition formatter depth (located_condition : condition located) =
  indent formatter depth;

  match located_condition.value with
  | Condition_reference path ->
      Format.fprintf
        formatter
        "ReferenceCondition(%a)@."
        pp_path
        path

  | Condition_boolean value ->
      Format.fprintf
        formatter
        "BooleanCondition(%b)@."
        value

  | Condition_not condition ->
      Format.fprintf formatter "Not@.";
      dump_condition formatter (depth + 1) condition

  | Condition_logical { left; operator; right } ->
      Format.fprintf
        formatter
        "Logical(%s)@."
        (string_of_logical_operator operator);

      dump_condition formatter (depth + 1) left;
      dump_condition formatter (depth + 1) right

  | Condition_compare { reference; operator; value } ->
      Format.fprintf
        formatter
        "Compare(%a %s %a)@."
        pp_path
        reference
        (string_of_comparison_operator operator)
        pp_value
        value.value

let rec dump_statement formatter depth (located_statement : statement located) =
  indent formatter depth;

  match located_statement.value with
  | Assignment assignment ->
      Format.fprintf
        formatter
        "Assignment(%a %s %a)@."
        pp_path
        assignment.key
        (string_of_assignment_operator assignment.operator)
        pp_value
        assignment.value.value

  | Include include_statement ->
      Format.fprintf
        formatter
        "Include(%S)@."
        include_statement.path

  | Define definition ->
      Format.fprintf
        formatter
        "Define(%s = %a)@."
        definition.name
        pp_value
        definition.value.value

  | Section section ->
      Format.fprintf
        formatter
        "Section(%a)@."
        pp_path
        section.name;

      List.iter
        (dump_statement formatter (depth + 1))
        section.body

  | Conditional conditional ->
      Format.fprintf formatter "Conditional@.";

      indent formatter (depth + 1);
      Format.fprintf formatter "Condition:@.";

      dump_condition
        formatter
        (depth + 2)
        conditional.condition;

      indent formatter (depth + 1);
      Format.fprintf formatter "Then:@.";

      List.iter
        (dump_statement formatter (depth + 2))
        conditional.then_branch;

      begin
        match conditional.else_branch with
        | None ->
            ()

        | Some statements ->
            indent formatter (depth + 1);
            Format.fprintf formatter "Else:@.";

            List.iter
              (dump_statement formatter (depth + 2))
              statements
      end

let dump formatter document =
  Format.fprintf
    formatter
    "VFConf.Document(%S)@."
    document.filename;

  List.iter
    (dump_statement formatter 1)
    document.statements;

  Format.pp_print_flush formatter ()

let dump_stdout document =
  dump Format.std_formatter document