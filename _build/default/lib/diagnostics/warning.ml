(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/diagnostics/warning.ml
 *
 * Canonical VFConf warning constructors.
 *
 * Warning codes are centralized here so semantic analysis,
 * schema validation, configuration loading and formatting use
 * stable warning identifiers and canonical English messages.
 *)

type category =
  | Semantic
  | Configuration
  | Include
  | Schema
  | Evaluation
  | Style
  | Compatibility
  | Deprecation

type kind =
  | Duplicate_definition of string
  | Shadowed_definition of string
  | Unused_definition of string
  | Unused_section of string
  | Unused_value of string
  | Redundant_assignment of string
  | Overwritten_value of string
  | Empty_section of string
  | Empty_array of string
  | Empty_object of string
  | Deprecated_key of {
      key : string;
      replacement : string option;
    }
  | Deprecated_value of {
      value : string;
      replacement : string option;
    }
  | Deprecated_syntax of {
      syntax : string;
      replacement : string option;
    }
  | Unknown_key of string
  | Unknown_section of string
  | Suspicious_value of {
      key : string option;
      value : string;
    }
  | Implicit_conversion of {
      from_type : string;
      to_type : string;
    }
  | Include_repeated of string
  | Include_outside_root of string
  | Schema_default_used of string
  | Schema_additional_field of string
  | Condition_always_true
  | Condition_always_false
  | Unreachable_configuration
  | Non_canonical_boolean of string
  | Non_canonical_size of string
  | Non_canonical_duration of string
  | Non_canonical_color of string
  | Compatibility_issue of string
  | Style_issue of string

type t = {
  category : category;
  kind : kind;
  span : Node.span option;
}

(* ---------------------------------------------------------- *)
(* Categories                                                 *)
(* ---------------------------------------------------------- *)

let string_of_category = function
  | Semantic ->
      "semantic"

  | Configuration ->
      "configuration"

  | Include ->
      "include"

  | Schema ->
      "schema"

  | Evaluation ->
      "evaluation"

  | Style ->
      "style"

  | Compatibility ->
      "compatibility"

  | Deprecation ->
      "deprecation"

(* ---------------------------------------------------------- *)
(* Diagnostic codes                                           *)
(* ---------------------------------------------------------- *)

let code_of_kind = function
  | Duplicate_definition _ ->
      "VFW0201"

  | Shadowed_definition _ ->
      "VFW0202"

  | Unused_definition _ ->
      "VFW0203"

  | Unused_section _ ->
      "VFW0204"

  | Unused_value _ ->
      "VFW0205"

  | Redundant_assignment _ ->
      "VFW0301"

  | Overwritten_value _ ->
      "VFW0302"

  | Empty_section _ ->
      "VFW0303"

  | Empty_array _ ->
      "VFW0304"

  | Empty_object _ ->
      "VFW0305"

  | Deprecated_key _ ->
      "VFW0701"

  | Deprecated_value _ ->
      "VFW0702"

  | Deprecated_syntax _ ->
      "VFW0703"

  | Unknown_key _ ->
      "VFW0401"

  | Unknown_section _ ->
      "VFW0402"

  | Suspicious_value _ ->
      "VFW0403"

  | Implicit_conversion _ ->
      "VFW0501"

  | Include_repeated _ ->
      "VFW0601"

  | Include_outside_root _ ->
      "VFW0602"

  | Schema_default_used _ ->
      "VFW0404"

  | Schema_additional_field _ ->
      "VFW0405"

  | Condition_always_true ->
      "VFW0502"

  | Condition_always_false ->
      "VFW0503"

  | Unreachable_configuration ->
      "VFW0504"

  | Non_canonical_boolean _ ->
      "VFW0801"

  | Non_canonical_size _ ->
      "VFW0802"

  | Non_canonical_duration _ ->
      "VFW0803"

  | Non_canonical_color _ ->
      "VFW0804"

  | Compatibility_issue _ ->
      "VFW0901"

  | Style_issue _ ->
      "VFW0805"

(* ---------------------------------------------------------- *)
(* Messages                                                   *)
(* ---------------------------------------------------------- *)

let replacement_suffix = function
  | None ->
      ""

  | Some replacement ->
      Printf.sprintf
        "; use %s instead"
        replacement

let message_of_kind = function
  | Duplicate_definition name ->
      Printf.sprintf
        "definition '%s' is declared more than once"
        name

  | Shadowed_definition name ->
      Printf.sprintf
        "definition '%s' shadows a previous definition"
        name

  | Unused_definition name ->
      Printf.sprintf
        "definition '%s' is never used"
        name

  | Unused_section section ->
      Printf.sprintf
        "section '%s' is never used"
        section

  | Unused_value key ->
      Printf.sprintf
        "value assigned to '%s' is never used"
        key

  | Redundant_assignment key ->
      Printf.sprintf
        "assignment to '%s' is redundant"
        key

  | Overwritten_value key ->
      Printf.sprintf
        "value assigned to '%s' is overwritten"
        key

  | Empty_section section ->
      Printf.sprintf
        "section '%s' is empty"
        section

  | Empty_array key ->
      Printf.sprintf
        "array assigned to '%s' is empty"
        key

  | Empty_object key ->
      Printf.sprintf
        "object assigned to '%s' is empty"
        key

  | Deprecated_key { key; replacement } ->
      Printf.sprintf
        "configuration key '%s' is deprecated%s"
        key
        (replacement_suffix replacement)

  | Deprecated_value { value; replacement } ->
      Printf.sprintf
        "configuration value '%s' is deprecated%s"
        value
        (replacement_suffix replacement)

  | Deprecated_syntax { syntax; replacement } ->
      Printf.sprintf
        "syntax '%s' is deprecated%s"
        syntax
        (replacement_suffix replacement)

  | Unknown_key key ->
      Printf.sprintf
        "unknown configuration key '%s'"
        key

  | Unknown_section section ->
      Printf.sprintf
        "unknown configuration section '%s'"
        section

  | Suspicious_value { key = None; value } ->
      Printf.sprintf
        "suspicious configuration value '%s'"
        value

  | Suspicious_value
      {
        key = Some key;
        value;
      } ->
      Printf.sprintf
        "suspicious value '%s' for configuration key '%s'"
        value
        key

  | Implicit_conversion { from_type; to_type } ->
      Printf.sprintf
        "implicit conversion from %s to %s"
        from_type
        to_type

  | Include_repeated path ->
      Printf.sprintf
        "file '%s' is included more than once"
        path

  | Include_outside_root path ->
      Printf.sprintf
        "included file '%s' is outside the configuration root"
        path

  | Schema_default_used field ->
      Printf.sprintf
        "schema default is used for field '%s'"
        field

  | Schema_additional_field field ->
      Printf.sprintf
        "field '%s' is not declared by the schema"
        field

  | Condition_always_true ->
      "condition is always true"

  | Condition_always_false ->
      "condition is always false"

  | Unreachable_configuration ->
      "configuration block is unreachable"

  | Non_canonical_boolean value ->
      Printf.sprintf
        "non-canonical boolean representation '%s'"
        value

  | Non_canonical_size value ->
      Printf.sprintf
        "non-canonical size representation '%s'"
        value

  | Non_canonical_duration value ->
      Printf.sprintf
        "non-canonical duration representation '%s'"
        value

  | Non_canonical_color value ->
      Printf.sprintf
        "non-canonical color representation '%s'"
        value

  | Compatibility_issue message ->
      Printf.sprintf
        "compatibility issue: %s"
        message

  | Style_issue message ->
      Printf.sprintf
        "style issue: %s"
        message

(* ---------------------------------------------------------- *)
(* Category inference                                         *)
(* ---------------------------------------------------------- *)

let category_of_kind = function
  | Duplicate_definition _
  | Shadowed_definition _
  | Unused_definition _
  | Unused_section _
  | Unused_value _ ->
      Semantic

  | Redundant_assignment _
  | Overwritten_value _
  | Empty_section _
  | Empty_array _
  | Empty_object _ ->
      Configuration

  | Deprecated_key _
  | Deprecated_value _
  | Deprecated_syntax _ ->
      Deprecation

  | Unknown_key _
  | Unknown_section _
  | Suspicious_value _
  | Schema_default_used _
  | Schema_additional_field _ ->
      Schema

  | Implicit_conversion _
  | Condition_always_true
  | Condition_always_false
  | Unreachable_configuration ->
      Evaluation

  | Include_repeated _
  | Include_outside_root _ ->
      Include

  | Non_canonical_boolean _
  | Non_canonical_size _
  | Non_canonical_duration _
  | Non_canonical_color _
  | Style_issue _ ->
      Style

  | Compatibility_issue _ ->
      Compatibility

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let make ?span kind =
  {
    category = category_of_kind kind;
    kind;
    span;
  }

(* ---------------------------------------------------------- *)
(* Diagnostic conversion                                      *)
(* ---------------------------------------------------------- *)

let to_diagnostic warning =
  Diagnostic.warning
    ~code:(code_of_kind warning.kind)
    ?span:warning.span
    (message_of_kind warning.kind)

let to_diagnostic_with_notes
    ?(notes = [])
    warning =
  Diagnostic.warning
    ~code:(code_of_kind warning.kind)
    ?span:warning.span
    ~notes
    (message_of_kind warning.kind)

let to_diagnostic_with_fix
    ?message
    ~span
    ~replacement
    warning =
  to_diagnostic warning
  |> Diagnostic.add_replacement
       ?message
       span
       replacement

(* ---------------------------------------------------------- *)
(* Semantic constructors                                      *)
(* ---------------------------------------------------------- *)

let duplicate_definition ?span name =
  make
    ?span
    (Duplicate_definition name)

let shadowed_definition ?span name =
  make
    ?span
    (Shadowed_definition name)

let unused_definition ?span name =
  make
    ?span
    (Unused_definition name)

let unused_section ?span section =
  make
    ?span
    (Unused_section section)

let unused_value ?span key =
  make
    ?span
    (Unused_value key)

(* ---------------------------------------------------------- *)
(* Configuration constructors                                 *)
(* ---------------------------------------------------------- *)

let redundant_assignment ?span key =
  make
    ?span
    (Redundant_assignment key)

let overwritten_value ?span key =
  make
    ?span
    (Overwritten_value key)

let empty_section ?span section =
  make
    ?span
    (Empty_section section)

let empty_array ?span key =
  make
    ?span
    (Empty_array key)

let empty_object ?span key =
  make
    ?span
    (Empty_object key)

(* ---------------------------------------------------------- *)
(* Deprecation constructors                                   *)
(* ---------------------------------------------------------- *)

let deprecated_key
    ?span
    ?replacement
    key =
  make
    ?span
    (Deprecated_key
       {
         key;
         replacement;
       })

let deprecated_value
    ?span
    ?replacement
    value =
  make
    ?span
    (Deprecated_value
       {
         value;
         replacement;
       })

let deprecated_syntax
    ?span
    ?replacement
    syntax =
  make
    ?span
    (Deprecated_syntax
       {
         syntax;
         replacement;
       })

(* ---------------------------------------------------------- *)
(* Schema constructors                                        *)
(* ---------------------------------------------------------- *)

let unknown_key ?span key =
  make
    ?span
    (Unknown_key key)

let unknown_section ?span section =
  make
    ?span
    (Unknown_section section)

let suspicious_value
    ?span
    ?key
    value =
  make
    ?span
    (Suspicious_value
       {
         key;
         value;
       })

let schema_default_used ?span field =
  make
    ?span
    (Schema_default_used field)

let schema_additional_field ?span field =
  make
    ?span
    (Schema_additional_field field)

(* ---------------------------------------------------------- *)
(* Evaluation constructors                                    *)
(* ---------------------------------------------------------- *)

let implicit_conversion
    ?span
    ~from_type
    ~to_type
    () =
  make
    ?span
    (Implicit_conversion
       {
         from_type;
         to_type;
       })

let condition_always_true ?span () =
  make
    ?span
    Condition_always_true

let condition_always_false ?span () =
  make
    ?span
    Condition_always_false

let unreachable_configuration ?span () =
  make
    ?span
    Unreachable_configuration

(* ---------------------------------------------------------- *)
(* Include constructors                                       *)
(* ---------------------------------------------------------- *)

let include_repeated ?span path =
  make
    ?span
    (Include_repeated path)

let include_outside_root ?span path =
  make
    ?span
    (Include_outside_root path)

(* ---------------------------------------------------------- *)
(* Style constructors                                         *)
(* ---------------------------------------------------------- *)

let non_canonical_boolean ?span value =
  make
    ?span
    (Non_canonical_boolean value)

let non_canonical_size ?span value =
  make
    ?span
    (Non_canonical_size value)

let non_canonical_duration ?span value =
  make
    ?span
    (Non_canonical_duration value)

let non_canonical_color ?span value =
  make
    ?span
    (Non_canonical_color value)

let style_issue ?span message =
  make
    ?span
    (Style_issue message)

(* ---------------------------------------------------------- *)
(* Compatibility constructors                                 *)
(* ---------------------------------------------------------- *)

let compatibility_issue ?span message =
  make
    ?span
    (Compatibility_issue message)

(* ---------------------------------------------------------- *)
(* Inspection                                                 *)
(* ---------------------------------------------------------- *)

let code warning =
  code_of_kind warning.kind

let message warning =
  message_of_kind warning.kind

let category warning =
  warning.category

let span warning =
  warning.span

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp formatter warning =
  Diagnostic.pp
    formatter
    (to_diagnostic warning)

let to_string warning =
  Format.asprintf
    "%a"
    pp
    warning