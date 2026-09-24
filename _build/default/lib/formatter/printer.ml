(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/formatter/printer.ml
 *
 * Low-level pretty-printing utilities for VFConf.
 *)

type style = {
  indent_width : int;
  newline : string;
  space_after_comma : bool;
  space_after_colon : bool;
  space_around_operators : bool;
}

let default_style =
  {
    indent_width = 2;
    newline = "\n";
    space_after_comma = true;
    space_after_colon = true;
    space_around_operators = true;
  }

type t = {
  buffer : Buffer.t;
  style : style;
  mutable level : int;
  mutable line_start : bool;
}

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let create
    ?(capacity = 256)
    ?(style = default_style)
    () =
  {
    buffer = Buffer.create capacity;
    style;
    level = 0;
    line_start = true;
  }

let clear printer =
  Buffer.clear printer.buffer;
  printer.level <- 0;
  printer.line_start <- true

let reset =
  clear

let contents printer =
  Buffer.contents printer.buffer

let length printer =
  Buffer.length printer.buffer

let is_empty printer =
  Buffer.length printer.buffer = 0

let style printer =
  printer.style

let level printer =
  printer.level

(* ---------------------------------------------------------- *)
(* Indentation                                                *)
(* ---------------------------------------------------------- *)

let indentation printer =
  String.make
    (printer.level * printer.style.indent_width)
    ' '

let write_indentation printer =
  if printer.line_start then begin
    Buffer.add_string
      printer.buffer
      (indentation printer);

    printer.line_start <- false
  end

let indent printer =
  printer.level <- printer.level + 1

let dedent printer =
  if printer.level > 0 then
    printer.level <- printer.level - 1

let with_indent printer function_ =
  indent printer;

  Fun.protect
    ~finally:(fun () -> dedent printer)
    (fun () -> function_ printer)

(* ---------------------------------------------------------- *)
(* Raw output                                                 *)
(* ---------------------------------------------------------- *)

let raw printer value =
  Buffer.add_string
    printer.buffer
    value;

  if value <> "" then
    printer.line_start <- false

let char printer character =
  write_indentation printer;
  Buffer.add_char printer.buffer character;
  printer.line_start <- false

let text printer value =
  if value <> "" then begin
    write_indentation printer;
    Buffer.add_string printer.buffer value;
    printer.line_start <- false
  end

let space printer =
  text printer " "

let newline printer =
  Buffer.add_string
    printer.buffer
    printer.style.newline;

  printer.line_start <- true

let blank_line printer =
  newline printer;
  newline printer

(* ---------------------------------------------------------- *)
(* Tokens                                                     *)
(* ---------------------------------------------------------- *)

let comma printer =
  char printer ',';

  if printer.style.space_after_comma then
    space printer

let colon printer =
  char printer ':';

  if printer.style.space_after_colon then
    space printer

let semicolon printer =
  char printer ';'

let dot printer =
  char printer '.'

let operator printer value =
  if printer.style.space_around_operators then begin
    space printer;
    text printer value;
    space printer
  end
  else
    text printer value

(* ---------------------------------------------------------- *)
(* Strings                                                    *)
(* ---------------------------------------------------------- *)

let escape_string =
  Formatter.escape_string

let quoted printer value =
  char printer '"';
  raw printer (escape_string value);
  char printer '"'

(* ---------------------------------------------------------- *)
(* Paths                                                      *)
(* ---------------------------------------------------------- *)

let path printer components =
  let rec loop = function
    | [] ->
        ()

    | [component] ->
        text printer component

    | component :: rest ->
        text printer component;
        dot printer;
        loop rest
  in

  loop components

let reference printer components =
  char printer '$';
  path printer components

(* ---------------------------------------------------------- *)
(* Delimiters                                                 *)
(* ---------------------------------------------------------- *)

let delimited
    printer
    ~left
    ~right
    function_ =
  text printer left;

  Fun.protect
    ~finally:(fun () -> text printer right)
    (fun () -> function_ printer)

let parentheses printer function_ =
  delimited
    printer
    ~left:"("
    ~right:")"
    function_

let brackets printer function_ =
  delimited
    printer
    ~left:"["
    ~right:"]"
    function_

let braces printer function_ =
  delimited
    printer
    ~left:"{"
    ~right:"}"
    function_

(* ---------------------------------------------------------- *)
(* Lists                                                      *)
(* ---------------------------------------------------------- *)

let separated
    printer
    ~separator
    function_
    values =
  let rec loop = function
    | [] ->
        ()

    | [value] ->
        function_ printer value

    | value :: rest ->
        function_ printer value;
        separator printer;
        loop rest
  in

  loop values

let comma_separated printer function_ values =
  separated
    printer
    ~separator:comma
    function_
    values

let newline_separated printer function_ values =
  separated
    printer
    ~separator:newline
    function_
    values

(* ---------------------------------------------------------- *)
(* Primitive values                                           *)
(* ---------------------------------------------------------- *)

let integer printer value =
  text
    printer
    (Int64.to_string value)

let float printer value =
  text
    printer
    (Formatter.string_of_float value)

let boolean printer value =
  text
    printer
    (if value then "true" else "false")

let null printer =
  text printer "null"

let color printer value =
  text
    printer
    (Formatter.string_of_color value)

let duration printer amount unit =
  text printer
    (Formatter.string_of_float amount);

  raw printer
    (Formatter.string_of_duration_unit unit)

let size printer amount unit =
  text printer
    (Formatter.string_of_float amount);

  raw printer
    (Formatter.string_of_size_unit unit)

(* ---------------------------------------------------------- *)
(* VFConf values                                              *)
(* ---------------------------------------------------------- *)

let rec value printer node =
  match node.Node.value with
  | Value.String value ->
      quoted printer value

  | Value.Integer value ->
      integer printer value

  | Value.Float value ->
      float printer value

  | Value.Boolean value ->
      boolean printer value

  | Value.Null ->
      null printer

  | Value.Reference value ->
      reference printer value

  | Value.Color value ->
      color printer value

  | Value.Duration (amount, unit) ->
      duration printer amount unit

  | Value.Size (amount, unit) ->
      size printer amount unit

  | Value.Array values ->
      array printer values

  | Value.Object entries ->
      object_ printer entries

and array printer values =
  brackets printer
    (fun printer ->
      comma_separated
        printer
        value
        values)

and object_entry printer entry =
  path printer entry.Value.key;
  colon printer;
  value printer entry.Value.value

and object_ printer entries =
  braces printer
    (fun printer ->
      comma_separated
        printer
        object_entry
        entries)

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

let assignment_operator printer assignment_operator =
  operator printer
    (Formatter.assignment_operator assignment_operator)

let comparison_operator printer operator =
  text printer
    (Formatter.comparison_operator operator)

let logical_operator printer operator =
  text printer
    (Formatter.logical_operator operator)

let rec condition printer node =
  match node.Node.value with
  | Statement.Boolean value ->
      boolean printer value

  | Statement.Reference value ->
      reference printer value

  | Statement.Not inner ->
      char printer '!';
      condition printer inner

  | Statement.Compare
      {
        reference = reference_path;
        operator = comparison;
        value = right;
      } ->
      reference printer reference_path;
      operator printer
        (Formatter.comparison_operator comparison);
      value printer right

  | Statement.Logical
      {
        left;
        operator = logical;
        right;
      } ->
      condition printer left;
      operator printer
        (Formatter.logical_operator logical);
      condition printer right

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

let rec statement printer node =
  match node.Node.value with
  | Statement.Assignment assignment ->
      path printer assignment.Statement.key;

      operator printer
        (Formatter.assignment_operator
           assignment.Statement.operator);

      value printer assignment.Statement.value;
      semicolon printer

  | Statement.Include include_statement ->
      text printer "include";
      space printer;
      quoted printer include_statement.Statement.path;
      semicolon printer

  | Statement.Define definition ->
      text printer "define";
      space printer;
      text printer definition.Statement.name;
      operator printer "=";
      value printer definition.Statement.value;
      semicolon printer

  | Statement.Section section ->
      section_statement printer section

  | Statement.Conditional conditional ->
      conditional_statement printer conditional

and section_statement printer section =
  char printer '[';
  path printer section.Statement.name;
  char printer ']';

  begin
    match section.Statement.body with
    | [] ->
        ()

    | body ->
        newline printer;
        newline_separated
          printer
          statement
          body
  end

and conditional_statement printer conditional =
  text printer "when";
  space printer;
  condition printer conditional.Statement.condition;
  space printer;

  block
    printer
    conditional.Statement.then_branch;

  match conditional.Statement.else_branch with
  | None ->
      ()

  | Some branch ->
      space printer;
      text printer "else";
      space printer;
      block printer branch

and block printer statements =
  char printer '{';

  match statements with
  | [] ->
      char printer '}'

  | _ ->
      newline printer;
      with_indent printer
        (fun printer ->
          newline_separated
            printer
            statement
            statements);
      newline printer;
      char printer '}'

(* ---------------------------------------------------------- *)
(* Documents                                                  *)
(* ---------------------------------------------------------- *)

let document printer statements =
  newline_separated
    printer
    statement
    statements

let print_value ?style node =
  let printer =
    create ?style ()
  in

  value printer node;
  contents printer

let print_condition ?style node =
  let printer =
    create ?style ()
  in

  condition printer node;
  contents printer

let print_statement ?style node =
  let printer =
    create ?style ()
  in

  statement printer node;
  contents printer

let print_document ?style statements =
  let printer =
    create ?style ()
  in

  document printer statements;
  contents printer