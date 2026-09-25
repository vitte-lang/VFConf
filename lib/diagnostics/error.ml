(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/error.ml
 *
 * Canonical VFConf error constructors.
 *
 * This module centralizes error diagnostic creation so lexer,
 * parser, semantic, configuration, schema and evaluator layers
 * use stable diagnostic codes and canonical English messages.
 *)

type category =
  | Lexical
  | Syntax
  | Semantic
  | Configuration
  | Include
  | Schema
  | Evaluation
  | Io
  | Internal

type kind =
  | Unexpected_character of char
  | Invalid_token of string
  | Unterminated_string
  | Unterminated_comment
  | Invalid_escape of string
  | Invalid_number of string
  | Invalid_color of string
  | Invalid_duration of string
  | Invalid_size of string
  | Unexpected_token of string
  | Expected_token of {
      expected : string;
      found : string option;
    }
  | Unexpected_end_of_file
  | Duplicate_key of string
  | Undefined_reference of string
  | Invalid_reference of string
  | Type_mismatch of {
      expected : string;
      found : string;
    }
  | Invalid_assignment of {
      key : string;
      operator : string;
    }
  | Invalid_value of string
  | Invalid_condition of string
  | Include_not_found of string
  | Include_cycle of string list
  | Include_depth_exceeded of {
      maximum : int;
      path : string;
    }
  | Invalid_include of string
  | Schema_violation of string
  | Missing_required_field of string
  | Unknown_field of string
  | Evaluation_failed of string
  | Division_by_zero
  | File_not_found of string
  | Cannot_read_file of {
      path : string;
      message : string;
    }
  | Internal_error of string

type t = {
  category : category;
  kind : kind;
  span : Node.span option;
}

(* ---------------------------------------------------------- *)
(* Categories                                                 *)
(* ---------------------------------------------------------- *)

let string_of_category = function
  | Lexical -> "lexical"
  | Syntax -> "syntax"
  | Semantic -> "semantic"
  | Configuration -> "configuration"
  | Include -> "include"
  | Schema -> "schema"
  | Evaluation -> "evaluation"
  | Io -> "io"
  | Internal -> "internal"

(* ---------------------------------------------------------- *)
(* Diagnostic codes                                           *)
(* ---------------------------------------------------------- *)

let code_of_kind = function
  | Unexpected_character _ -> "VF0001"
  | Invalid_token _ -> "VF0002"
  | Unterminated_string -> "VF0003"
  | Unterminated_comment -> "VF0004"
  | Invalid_escape _ -> "VF0005"
  | Invalid_number _ -> "VF0006"
  | Invalid_color _ -> "VF0007"
  | Invalid_duration _ -> "VF0008"
  | Invalid_size _ -> "VF0009"

  | Unexpected_token _ -> "VF0101"
  | Expected_token _ -> "VF0102"
  | Unexpected_end_of_file -> "VF0103"

  | Duplicate_key _ -> "VF0201"
  | Undefined_reference _ -> "VF0202"
  | Invalid_reference _ -> "VF0203"
  | Type_mismatch _ -> "VF0204"
  | Invalid_assignment _ -> "VF0205"
  | Invalid_value _ -> "VF0206"
  | Invalid_condition _ -> "VF0207"

  | Include_not_found _ -> "VF0401"
  | Include_cycle _ -> "VF0402"
  | Include_depth_exceeded _ -> "VF0403"
  | Invalid_include _ -> "VF0404"

  | Schema_violation _ -> "VF0501"
  | Missing_required_field _ -> "VF0502"
  | Unknown_field _ -> "VF0503"

  | Evaluation_failed _ -> "VF0601"
  | Division_by_zero -> "VF0602"

  | File_not_found _ -> "VF9001"
  | Cannot_read_file _ -> "VF9002"

  | Internal_error _ -> "VF9901"

(* ---------------------------------------------------------- *)
(* Messages                                                   *)
(* ---------------------------------------------------------- *)

let message_of_kind = function
  | Unexpected_character character ->
      Printf.sprintf
        "unexpected character %C"
        character

  | Invalid_token token ->
      Printf.sprintf
        "invalid token %S"
        token

  | Unterminated_string ->
      "unterminated string literal"

  | Unterminated_comment ->
      "unterminated block comment"

  | Invalid_escape escape ->
      Printf.sprintf
        "invalid escape sequence %S"
        escape

  | Invalid_number value ->
      Printf.sprintf
        "invalid numeric literal %S"
        value

  | Invalid_color value ->
      Printf.sprintf
        "invalid color literal %S"
        value

  | Invalid_duration value ->
      Printf.sprintf
        "invalid duration literal %S"
        value

  | Invalid_size value ->
      Printf.sprintf
        "invalid size literal %S"
        value

  | Unexpected_token token ->
      Printf.sprintf
        "unexpected token %S"
        token

  | Expected_token { expected; found = None } ->
      Printf.sprintf
        "expected %s"
        expected

  | Expected_token
      {
        expected;
        found = Some found;
      } ->
      Printf.sprintf
        "expected %s, found %s"
        expected
        found

  | Unexpected_end_of_file ->
      "unexpected end of file"

  | Duplicate_key key ->
      Printf.sprintf
        "duplicate configuration key '%s'"
        key

  | Undefined_reference reference ->
      Printf.sprintf
        "undefined reference '$%s'"
        reference

  | Invalid_reference reference ->
      Printf.sprintf
        "invalid reference '$%s'"
        reference

  | Type_mismatch { expected; found } ->
      Printf.sprintf
        "type mismatch: expected %s, found %s"
        expected
        found

  | Invalid_assignment { key; operator } ->
      Printf.sprintf
        "operator '%s' cannot be applied to configuration key '%s'"
        operator
        key

  | Invalid_value message ->
      Printf.sprintf
        "invalid value: %s"
        message

  | Invalid_condition message ->
      Printf.sprintf
        "invalid condition: %s"
        message

  | Include_not_found path ->
      Printf.sprintf
        "included file not found: %s"
        path

  | Include_cycle paths ->
      Printf.sprintf
        "recursive include detected: %s"
        (String.concat " -> " paths)

  | Include_depth_exceeded { maximum; path } ->
      Printf.sprintf
        "maximum include depth (%d) exceeded while including '%s'"
        maximum
        path

  | Invalid_include path ->
      Printf.sprintf
        "invalid include path: %s"
        path

  | Schema_violation message ->
      Printf.sprintf
        "schema violation: %s"
        message

  | Missing_required_field field ->
      Printf.sprintf
        "missing required field '%s'"
        field

  | Unknown_field field ->
      Printf.sprintf
        "unknown field '%s'"
        field

  | Evaluation_failed message ->
      Printf.sprintf
        "evaluation failed: %s"
        message

  | Division_by_zero ->
      "division by zero"

  | File_not_found path ->
      Printf.sprintf
        "file not found: %s"
        path

  | Cannot_read_file { path; message } ->
      Printf.sprintf
        "cannot read file '%s': %s"
        path
        message

  | Internal_error message ->
      Printf.sprintf
        "internal error: %s"
        message

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let category_of_kind = function
  | Unexpected_character _
  | Invalid_token _
  | Unterminated_string
  | Unterminated_comment
  | Invalid_escape _
  | Invalid_number _
  | Invalid_color _
  | Invalid_duration _
  | Invalid_size _ ->
      Lexical

  | Unexpected_token _
  | Expected_token _
  | Unexpected_end_of_file ->
      Syntax

  | Duplicate_key _
  | Undefined_reference _
  | Invalid_reference _
  | Type_mismatch _
  | Invalid_assignment _
  | Invalid_value _
  | Invalid_condition _ ->
      Semantic

  | Include_not_found _
  | Include_cycle _
  | Include_depth_exceeded _
  | Invalid_include _ ->
      Include

  | Schema_violation _
  | Missing_required_field _
  | Unknown_field _ ->
      Schema

  | Evaluation_failed _
  | Division_by_zero ->
      Evaluation

  | File_not_found _
  | Cannot_read_file _ ->
      Io

  | Internal_error _ ->
      Internal

let make ?span kind =
  {
    category = category_of_kind kind;
    kind;
    span;
  }

(* ---------------------------------------------------------- *)
(* Conversion to canonical diagnostic                         *)
(* ---------------------------------------------------------- *)

let to_diagnostic error =
  Diagnostic.error
    ~code:(code_of_kind error.kind)
    ?span:error.span
    (message_of_kind error.kind)

let to_diagnostic_with_notes
    ?(notes = [])
    error =
  Diagnostic.error
    ~code:(code_of_kind error.kind)
    ?span:error.span
    ~notes
    (message_of_kind error.kind)

(* ---------------------------------------------------------- *)
(* Convenience constructors                                   *)
(* ---------------------------------------------------------- *)

let unexpected_character ?span character =
  make
    ?span
    (Unexpected_character character)

let invalid_token ?span token =
  make
    ?span
    (Invalid_token token)

let unterminated_string ?span () =
  make
    ?span
    Unterminated_string

let unterminated_comment ?span () =
  make
    ?span
    Unterminated_comment

let invalid_escape ?span escape =
  make
    ?span
    (Invalid_escape escape)

let invalid_number ?span value =
  make
    ?span
    (Invalid_number value)

let invalid_color ?span value =
  make
    ?span
    (Invalid_color value)

let invalid_duration ?span value =
  make
    ?span
    (Invalid_duration value)

let invalid_size ?span value =
  make
    ?span
    (Invalid_size value)

let unexpected_token ?span token =
  make
    ?span
    (Unexpected_token token)

let expected_token
    ?span
    ?found
    expected =
  make
    ?span
    (Expected_token
       {
         expected;
         found;
       })

let unexpected_end_of_file ?span () =
  make
    ?span
    Unexpected_end_of_file

let duplicate_key ?span key =
  make
    ?span
    (Duplicate_key key)

let undefined_reference ?span reference =
  make
    ?span
    (Undefined_reference reference)

let invalid_reference ?span reference =
  make
    ?span
    (Invalid_reference reference)

let type_mismatch
    ?span
    ~expected
    ~found
    () =
  make
    ?span
    (Type_mismatch
       {
         expected;
         found;
       })

let invalid_assignment
    ?span
    ~key
    ~operator
    () =
  make
    ?span
    (Invalid_assignment
       {
         key;
         operator;
       })

let invalid_value ?span message =
  make
    ?span
    (Invalid_value message)

let invalid_condition ?span message =
  make
    ?span
    (Invalid_condition message)

let include_not_found ?span path =
  make
    ?span
    (Include_not_found path)

let include_cycle ?span paths =
  make
    ?span
    (Include_cycle paths)

let include_depth_exceeded
    ?span
    ~maximum
    path =
  make
    ?span
    (Include_depth_exceeded
       {
         maximum;
         path;
       })

let invalid_include ?span path =
  make
    ?span
    (Invalid_include path)

let schema_violation ?span message =
  make
    ?span
    (Schema_violation message)

let missing_required_field ?span field =
  make
    ?span
    (Missing_required_field field)

let unknown_field ?span field =
  make
    ?span
    (Unknown_field field)

let evaluation_failed ?span message =
  make
    ?span
    (Evaluation_failed message)

let division_by_zero ?span () =
  make
    ?span
    Division_by_zero

let file_not_found ?span path =
  make
    ?span
    (File_not_found path)

let cannot_read_file
    ?span
    ~path
    message =
  make
    ?span
    (Cannot_read_file
       {
         path;
         message;
       })

let internal_error ?span message =
  make
    ?span
    (Internal_error message)

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

let code error =
  code_of_kind error.kind

let message error =
  message_of_kind error.kind

let category error =
  error.category

let span error =
  error.span

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp formatter error =
  Diagnostic.pp
    formatter
    (to_diagnostic error)

let to_string error =
  Format.asprintf
    "%a"
    pp
    error
(* ---------------------------------------------------------- *)
(* Diagnostic explanations                                    *)
(* ---------------------------------------------------------- *)

type explanation = {
  code : string;
  category : category;
  title : string;
  description : string;
}

let explanation kind title description =
  {
    code = code_of_kind kind;
    category = category_of_kind kind;
    title;
    description;
  }

let explanations =
  [
    explanation
      (Unexpected_character '\000')
      "Unexpected character"
      "The source contains a character that is not valid in VFConf.";

    explanation
      (Invalid_token "")
      "Invalid token"
      "The lexer recognized input that cannot form a valid VFConf token.";

    explanation
      Unterminated_string
      "Unterminated string"
      "A string literal was opened but not closed before the end of its valid lexical region.";

    explanation
      Unterminated_comment
      "Unterminated comment"
      "A block comment was opened with /* but was not closed with */.";

    explanation
      (Invalid_escape "")
      "Invalid escape"
      "A string contains an escape sequence that VFConf does not recognize.";

    explanation
      (Invalid_number "")
      "Invalid number"
      "A numeric literal does not conform to the VFConf numeric syntax.";

    explanation
      (Invalid_color "")
      "Invalid color"
      "A color literal does not conform to a supported VFConf color representation.";

    explanation
      (Invalid_duration "")
      "Invalid duration"
      "A duration literal contains an invalid number or duration unit.";

    explanation
      (Invalid_size "")
      "Invalid size"
      "A size literal contains an invalid number or size unit.";

    explanation
      (Unexpected_token "")
      "Unexpected token"
      "The parser encountered a token that is not valid at this position.";

    explanation
      (Expected_token { expected = ""; found = None })
      "Expected token"
      "The parser expected a different token at this position.";

    explanation
      Unexpected_end_of_file
      "Unexpected end of file"
      "The source ended before the current VFConf construct was complete.";

    explanation
      (Duplicate_key "")
      "Duplicate key"
      "A configuration key is declared more than once in a scope where duplicate declarations are not allowed.";

    explanation
      (Undefined_reference "")
      "Undefined reference"
      "A reference does not resolve to a visible definition or configuration value. Section-relative references are resolved locally first, then globally.";

    explanation
      (Invalid_reference "")
      "Invalid reference"
      "A reference exists syntactically but cannot be resolved correctly, for example because reference resolution forms an invalid chain or cycle.";

    explanation
      (Type_mismatch { expected = ""; found = "" })
      "Type mismatch"
      "A value has a type that is incompatible with the type required by the operation or schema.";

    explanation
      (Invalid_assignment { key = ""; operator = "" })
      "Invalid assignment"
      "The selected assignment operator cannot be applied to the target configuration key.";

    explanation
      (Invalid_value "")
      "Invalid value"
      "A value is syntactically valid but violates a semantic VFConf requirement.";

    explanation
      (Invalid_condition "")
      "Invalid condition"
      "A conditional expression is semantically invalid.";

    explanation
      (Include_not_found "")
      "Include not found"
      "An included VFConf file could not be found.";

    explanation
      (Include_cycle [])
      "Include cycle"
      "The include graph contains a recursive cycle.";

    explanation
      (Include_depth_exceeded { maximum = 0; path = "" })
      "Include depth exceeded"
      "Nested includes exceeded the configured maximum include depth.";

    explanation
      (Invalid_include "")
      "Invalid include"
      "An include path or include operation is invalid.";

    explanation
      (Schema_violation "")
      "Schema violation"
      "The configuration violates a rule defined by its schema.";

    explanation
      (Missing_required_field "")
      "Missing required field"
      "A field required by the active schema is absent.";

    explanation
      (Unknown_field "")
      "Unknown field"
      "The configuration contains a field that is not recognized by the active schema.";

    explanation
      (Evaluation_failed "")
      "Evaluation failed"
      "VFConf could not evaluate a configuration expression or condition.";

    explanation
      Division_by_zero
      "Division by zero"
      "Evaluation attempted to divide a numeric value by zero.";

    explanation
      (File_not_found "")
      "File not found"
      "A file required by the VFConf operation does not exist.";

    explanation
      (Cannot_read_file { path = ""; message = "" })
      "Cannot read file"
      "A file exists but VFConf could not read it.";

    explanation
      (Internal_error "")
      "Internal error"
      "VFConf encountered an internal failure. This normally indicates an implementation defect rather than an invalid configuration.";
  ]

let explain code =
  let code =
    String.uppercase_ascii code
  in

  List.find_opt
    (fun explanation ->
      String.equal
        explanation.code
        code)
    explanations
