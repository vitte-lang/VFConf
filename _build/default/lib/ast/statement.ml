(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/statement.ml
 *
 * Statement representation for the VFConf AST.
 *)

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
(* Values                                                     *)
(* ---------------------------------------------------------- *)

type value = Value.t

(* ---------------------------------------------------------- *)
(* Conditions                                                 *)
(* ---------------------------------------------------------- *)

type condition =
  | Reference of reference
  | Boolean of bool
  | Not of condition Node.t
  | Logical of {
      left : condition Node.t;
      operator : logical_operator;
      right : condition Node.t;
    }
  | Compare of {
      reference : reference;
      operator : comparison_operator;
      value : value Node.t;
    }

(* ---------------------------------------------------------- *)
(* Assignments                                                *)
(* ---------------------------------------------------------- *)

type assignment = {
  key : key;
  operator : assignment_operator;
  value : value Node.t;
}

(* ---------------------------------------------------------- *)
(* Include                                                    *)
(* ---------------------------------------------------------- *)

type include_statement = {
  path : string;
}

(* ---------------------------------------------------------- *)
(* Definition                                                 *)
(* ---------------------------------------------------------- *)

type define_statement = {
  name : identifier;
  value : value Node.t;
}

(* ---------------------------------------------------------- *)
(* Statements                                                 *)
(* ---------------------------------------------------------- *)

type t =
  | Assignment of assignment
  | Include of include_statement
  | Define of define_statement
  | Section of section
  | Conditional of conditional

and section = {
  name : section_name;
  body : t Node.t list;
}

and conditional = {
  condition : condition Node.t;
  then_branch : t Node.t list;
  else_branch : t Node.t list option;
}

(* ---------------------------------------------------------- *)
(* Constructors                                               *)
(* ---------------------------------------------------------- *)

let assignment
    ?(operator = Assign)
    key
    value =
  Assignment
    {
      key;
      operator;
      value;
    }

let include_ path =
  Include
    {
      path;
    }

let define name value =
  Define
    {
      name;
      value;
    }

let section name body =
  Section
    {
      name;
      body;
    }

let conditional
    condition
    then_branch
    else_branch =
  Conditional
    {
      condition;
      then_branch;
      else_branch;
    }

(* ---------------------------------------------------------- *)
(* Located constructors                                       *)
(* ---------------------------------------------------------- *)

let located_assignment
    span
    ?(operator = Assign)
    key
    value =
  Node.located
    span
    (assignment
       ~operator
       key
       value)

let located_include
    span
    path =
  Node.located
    span
    (include_ path)

let located_define
    span
    name
    value =
  Node.located
    span
    (define name value)

let located_section
    span
    name
    body =
  Node.located
    span
    (section name body)

let located_conditional
    span
    condition
    then_branch
    else_branch =
  Node.located
    span
    (conditional
       condition
       then_branch
       else_branch)

(* ---------------------------------------------------------- *)
(* Condition constructors                                     *)
(* ---------------------------------------------------------- *)

let condition_reference reference =
  Reference reference

let condition_boolean value =
  Boolean value

let condition_not condition =
  Not condition

let condition_and left right =
  Logical
    {
      left;
      operator = And;
      right;
    }

let condition_or left right =
  Logical
    {
      left;
      operator = Or;
      right;
    }

let condition_compare
    reference
    operator
    value =
  Compare
    {
      reference;
      operator;
      value;
    }

(* ---------------------------------------------------------- *)
(* Predicates                                                 *)
(* ---------------------------------------------------------- *)

let is_assignment = function
  | Assignment _ ->
      true
  | _ ->
      false

let is_include = function
  | Include _ ->
      true
  | _ ->
      false

let is_define = function
  | Define _ ->
      true
  | _ ->
      false

let is_section = function
  | Section _ ->
      true
  | _ ->
      false

let is_conditional = function
  | Conditional _ ->
      true
  | _ ->
      false

(* ---------------------------------------------------------- *)
(* Operator conversion                                        *)
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

let string_of_path path =
  String.concat "." path

(* ---------------------------------------------------------- *)
(* Traversal                                                  *)
(* ---------------------------------------------------------- *)

let rec iter function_ statement =
  function_ statement;

  match statement.Node.value with
  | Assignment _
  | Include _
  | Define _ ->
      ()

  | Section section ->
      List.iter
        (iter function_)
        section.body

  | Conditional conditional ->
      List.iter
        (iter function_)
        conditional.then_branch;

      begin
        match conditional.else_branch with
        | None ->
            ()
        | Some statements ->
            List.iter
              (iter function_)
              statements
      end

let rec fold function_ accumulator statement =
  let accumulator =
    function_ accumulator statement
  in

  match statement.Node.value with
  | Assignment _
  | Include _
  | Define _ ->
      accumulator

  | Section section ->
      List.fold_left
        (fold function_)
        accumulator
        section.body

  | Conditional conditional ->
      let accumulator =
        List.fold_left
          (fold function_)
          accumulator
          conditional.then_branch
      in

      begin
        match conditional.else_branch with
        | None ->
            accumulator

        | Some statements ->
            List.fold_left
              (fold function_)
              accumulator
              statements
      end

(* ---------------------------------------------------------- *)
(* Counting                                                   *)
(* ---------------------------------------------------------- *)

let count statements =
  List.fold_left
    (fun total statement ->
      fold
        (fun count _ -> count + 1)
        total
        statement)
    0
    statements

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_path formatter path =
  Format.pp_print_string
    formatter
    (string_of_path path)

let rec pp_condition formatter condition =
  match condition with
  | Reference reference ->
      Format.fprintf
        formatter
        "$%a"
        pp_path
        reference

  | Boolean value ->
      Format.pp_print_bool
        formatter
        value

  | Not condition ->
      Format.fprintf
        formatter
        "!%a"
        pp_condition
        condition.Node.value

  | Logical { left; operator; right } ->
      Format.fprintf
        formatter
        "(%a %s %a)"
        pp_condition
        left.Node.value
        (string_of_logical_operator operator)
        pp_condition
        right.Node.value

  | Compare { reference; operator; value } ->
      Format.fprintf
        formatter
        "$%a %s %a"
        pp_path
        reference
        (string_of_comparison_operator operator)
        Value.pp
        value.Node.value

let rec pp formatter statement =
  match statement with
  | Assignment assignment ->
      Format.fprintf
        formatter
        "%a %s %a"
        pp_path
        assignment.key
        (string_of_assignment_operator assignment.operator)
        Value.pp
        assignment.value.Node.value

  | Include include_statement ->
      Format.fprintf
        formatter
        "include %S"
        include_statement.path

  | Define definition ->
      Format.fprintf
        formatter
        "define %s = %a"
        definition.name
        Value.pp
        definition.value.Node.value

  | Section section ->
      Format.fprintf
        formatter
        "Section(%a)"
        pp_path
        section.name

  | Conditional conditional ->
      Format.fprintf
        formatter
        "when %a"
        pp_condition
        conditional.condition.Node.value

let pp_located formatter statement =
  Format.fprintf
    formatter
    "%a [%a]"
    pp
    statement.Node.value
    Node.pp_span
    statement.Node.span

(* ---------------------------------------------------------- *)
(* Debug dump                                                 *)
(* ---------------------------------------------------------- *)

let indent formatter depth =
  Format.pp_print_string
    formatter
    (String.make (depth * 2) ' ')

let rec dump formatter depth statement =
  indent formatter depth;

  begin
    match statement.Node.value with
    | Assignment assignment ->
        Format.fprintf
          formatter
          "Assignment(%a %s %a)@."
          pp_path
          assignment.key
          (string_of_assignment_operator assignment.operator)
          Value.pp
          assignment.value.Node.value

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
          Value.pp
          definition.value.Node.value

    | Section section ->
        Format.fprintf
          formatter
          "Section(%a)@."
          pp_path
          section.name;

        List.iter
          (dump formatter (depth + 1))
          section.body

    | Conditional conditional ->
        Format.fprintf
          formatter
          "Conditional(%a)@."
          pp_condition
          conditional.condition.Node.value;

        indent formatter (depth + 1);
        Format.fprintf formatter "Then@.";

        List.iter
          (dump formatter (depth + 2))
          conditional.then_branch;

        begin
          match conditional.else_branch with
          | None ->
              ()

          | Some statements ->
              indent formatter (depth + 1);
              Format.fprintf formatter "Else@.";

              List.iter
                (dump formatter (depth + 2))
                statements
        end
  end