(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/parser/precedence.ml
 *
 * Canonical operator precedence and associativity definitions.
 *)

type associativity =
  | Left
  | Right
  | Non_associative

type operator =
  | Logical_or
  | Logical_and
  | Logical_not
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign

type info = {
  precedence : int;
  associativity : associativity;
}

(* ---------------------------------------------------------- *)
(* Precedence levels                                          *)
(* ---------------------------------------------------------- *)

let assignment_precedence = 10
let logical_or_precedence = 20
let logical_and_precedence = 30
let comparison_precedence = 40
let logical_not_precedence = 50
let primary_precedence = 100

let info = function
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign ->
      {
        precedence = assignment_precedence;
        associativity = Right;
      }

  | Logical_or ->
      {
        precedence = logical_or_precedence;
        associativity = Left;
      }

  | Logical_and ->
      {
        precedence = logical_and_precedence;
        associativity = Left;
      }

  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal ->
      {
        precedence = comparison_precedence;
        associativity = Non_associative;
      }

  | Logical_not ->
      {
        precedence = logical_not_precedence;
        associativity = Right;
      }

let precedence operator =
  (info operator).precedence

let associativity operator =
  (info operator).associativity

(* ---------------------------------------------------------- *)
(* Conversion from AST operators                              *)
(* ---------------------------------------------------------- *)

let of_assignment_operator = function
  | Statement.Assign ->
      Assign

  | Statement.Define_assign ->
      Define_assign

  | Statement.Add_assign ->
      Add_assign

  | Statement.Sub_assign ->
      Sub_assign

let of_comparison_operator = function
  | Statement.Equal ->
      Equal

  | Statement.Not_equal ->
      Not_equal

  | Statement.Less ->
      Less

  | Statement.Less_equal ->
      Less_equal

  | Statement.Greater ->
      Greater

  | Statement.Greater_equal ->
      Greater_equal

let of_logical_operator = function
  | Statement.And ->
      Logical_and

  | Statement.Or ->
      Logical_or

(* ---------------------------------------------------------- *)
(* Condition precedence                                       *)
(* ---------------------------------------------------------- *)

let condition_precedence condition =
  match condition.Node.value with
  | Statement.Boolean _
  | Statement.Reference _
  | Statement.Compare _ ->
      primary_precedence

  | Statement.Not _ ->
      logical_not_precedence

  | Statement.Logical { operator = Statement.And; _ } ->
      logical_and_precedence

  | Statement.Logical { operator = Statement.Or; _ } ->
      logical_or_precedence

let condition_associativity condition =
  match condition.Node.value with
  | Statement.Boolean _
  | Statement.Reference _
  | Statement.Compare _ ->
      Non_associative

  | Statement.Not _ ->
      Right

  | Statement.Logical { operator = Statement.And; _ }
  | Statement.Logical { operator = Statement.Or; _ } ->
      Left

(* ---------------------------------------------------------- *)
(* Parentheses decisions                                      *)
(* ---------------------------------------------------------- *)

let needs_parentheses
    ~parent_precedence
    ~child_precedence =
  child_precedence < parent_precedence

let needs_parentheses_for_side
    ~parent
    ~child
    ~right_side =
  let parent_info =
    info parent
  in

  let child_info =
    info child
  in

  if child_info.precedence < parent_info.precedence then
    true
  else if child_info.precedence > parent_info.precedence then
    false
  else
    match parent_info.associativity with
    | Non_associative ->
        true

    | Left ->
        right_side

    | Right ->
        not right_side

let condition_needs_parentheses
    ~parent
    ~child =
  condition_precedence child
  < condition_precedence parent

(* ---------------------------------------------------------- *)
(* Ordering                                                   *)
(* ---------------------------------------------------------- *)

let compare left right =
  Int.compare
    (precedence left)
    (precedence right)

let lower_than left right =
  precedence left < precedence right

let higher_than left right =
  precedence left > precedence right

let same_precedence left right =
  precedence left = precedence right

(* ---------------------------------------------------------- *)
(* Source representation                                      *)
(* ---------------------------------------------------------- *)

let operator_string = function
  | Logical_or ->
      "||"

  | Logical_and ->
      "&&"

  | Logical_not ->
      "!"

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

  | Assign ->
      "="

  | Define_assign ->
      ":="

  | Add_assign ->
      "+="

  | Sub_assign ->
      "-="

let associativity_string = function
  | Left ->
      "left"

  | Right ->
      "right"

  | Non_associative ->
      "non-associative"

(* ---------------------------------------------------------- *)
(* Classification                                             *)
(* ---------------------------------------------------------- *)

let is_assignment = function
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign ->
      true

  | _ ->
      false

let is_comparison = function
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal ->
      true

  | _ ->
      false

let is_logical = function
  | Logical_or
  | Logical_and
  | Logical_not ->
      true

  | _ ->
      false

let is_binary = function
  | Logical_not ->
      false

  | Logical_or
  | Logical_and
  | Equal
  | Not_equal
  | Less
  | Less_equal
  | Greater
  | Greater_equal
  | Assign
  | Define_assign
  | Add_assign
  | Sub_assign ->
      true

let is_unary operator =
  not (is_binary operator)

(* ---------------------------------------------------------- *)
(* Collections                                                *)
(* ---------------------------------------------------------- *)

let all =
  [
    Assign;
    Define_assign;
    Add_assign;
    Sub_assign;
    Logical_or;
    Logical_and;
    Equal;
    Not_equal;
    Less;
    Less_equal;
    Greater;
    Greater_equal;
    Logical_not;
  ]

let sorted_by_precedence =
  List.sort
    (fun left right ->
      let result =
        compare left right
      in

      if result <> 0 then
        result
      else
        String.compare
          (operator_string left)
          (operator_string right))
    all

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_associativity formatter associativity =
  Format.pp_print_string
    formatter
    (associativity_string associativity)

let pp_operator formatter operator =
  Format.pp_print_string
    formatter
    (operator_string operator)

let pp_info formatter operator =
  let information =
    info operator
  in

  Format.fprintf
    formatter
    "%s(precedence=%d, associativity=%s)"
    (operator_string operator)
    information.precedence
    (associativity_string information.associativity)