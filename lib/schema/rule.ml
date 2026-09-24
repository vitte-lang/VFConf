(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/schema/rule.ml
 *
 * Reusable schema rules for validating complete configurations.
 *)

type severity =
  | Error
  | Warning

type context = {
  config : Config.t;
  path : Config.path option;
}

type violation = {
  rule : string;
  message : string;
  severity : severity;
  path : Config.path option;
  span : Node.span option;
}

type validator =
  context ->
  violation list

type t = {
  name : string;
  description : string option;
  severity : severity;
  validator : validator;
}

(* ---------------------------------------------------------- *)
(* Construction                                               *)
(* ---------------------------------------------------------- *)

let make
    ?description
    ?(severity = Error)
    name
    validator =
  {
    name;
    description;
    severity;
    validator;
  }

let error
    ?description
    name
    validator =
  make
    ?description
    ~severity:Error
    name
    validator

let warning
    ?description
    name
    validator =
  make
    ?description
    ~severity:Warning
    name
    validator

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let name rule =
  rule.name

let description rule =
  rule.description

let severity rule =
  rule.severity

(* ---------------------------------------------------------- *)
(* Context                                                    *)
(* ---------------------------------------------------------- *)

let context
    ?path
    config =
  {
    config;
    path;
  }

let with_path path (context : context) =
  {
    context with
    path = Some path;
  }

let clear_path (context : context) =
  {
    context with
    path = None;
  }

(* ---------------------------------------------------------- *)
(* Violation construction                                     *)
(* ---------------------------------------------------------- *)

let violation
    ?path
    ?span
    ?(severity = Error)
    ~rule
    message =
  {
    rule;
    message;
    severity;
    path;
    span;
  }

let violation_for_entry
    ?(severity = Error)
    ~rule
    message
    entry =
  {
    rule;
    message;
    severity;
    path = Some entry.Config.path;
    span = Some entry.Config.span;
  }

(* ---------------------------------------------------------- *)
(* Running rules                                              *)
(* ---------------------------------------------------------- *)

let validate rule context =
  rule.validator context
  |> List.map
       (fun violation ->
         {
           violation with
           rule =
             if violation.rule = "" then
               rule.name
             else
               violation.rule;
           severity =
             rule.severity;
         })

let validate_config rule config =
  validate
    rule
    (context config)

let validate_rules rules config =
  List.concat_map
    (fun rule ->
      validate_config rule config)
    rules

let passes rule context =
  validate rule context = []

let passes_config rule config =
  validate_config rule config = []

(* ---------------------------------------------------------- *)
(* Lookup helpers                                             *)
(* ---------------------------------------------------------- *)

let entry context path =
  Config.find_entry_opt
    path
    context.config

let value context path =
  Config.find_opt
    path
    context.config

let value_raw context path =
  Config.find_value_opt
    path
    context.config

let exists context path =
  Config.mem
    path
    context.config

(* ---------------------------------------------------------- *)
(* Basic rules                                                *)
(* ---------------------------------------------------------- *)

let required_path
    ?(severity = Error)
    path =
  let rule_name =
    "required:" ^ Config.string_of_path path
  in

  make
    ~severity
    rule_name
    (fun context ->
      if exists context path then
        []
      else
        [
          violation
            ~severity
            ~rule:rule_name
            ~path
            (Printf.sprintf
               "required configuration field '%s' is missing"
               (Config.string_of_path path));
        ])

let forbidden_path
    ?(severity = Error)
    path =
  let rule_name =
    "forbidden:" ^ Config.string_of_path path
  in

  make
    ~severity
    rule_name
    (fun context ->
      match entry context path with
      | None ->
          []

      | Some entry ->
          [
            violation_for_entry
              ~severity
              ~rule:rule_name
              (Printf.sprintf
                 "configuration field '%s' is forbidden"
                 (Config.string_of_path path))
              entry;
          ])

let deprecated_path
    ?replacement
    path =
  let rule_name =
    "deprecated:" ^ Config.string_of_path path
  in

  warning
    rule_name
    (fun context ->
      match entry context path with
      | None ->
          []

      | Some entry ->
          let message =
            match replacement with
            | None ->
                Printf.sprintf
                  "configuration field '%s' is deprecated"
                  (Config.string_of_path path)

            | Some replacement ->
                Printf.sprintf
                  "configuration field '%s' is deprecated; use '%s' instead"
                  (Config.string_of_path path)
                  (Config.string_of_path replacement)
          in

          [
            violation_for_entry
              ~severity:Warning
              ~rule:rule_name
              message
              entry;
          ])

(* ---------------------------------------------------------- *)
(* Field rule                                                 *)
(* ---------------------------------------------------------- *)

let field
    path
    field =
  let rule_name =
    "field:" ^ Config.string_of_path path
  in

  error
    rule_name
    (fun context ->
      let current =
        value context path
      in

      Field.validate field current
      |> List.map
           (fun validation_error ->
             let span =
               match entry context path with
               | Some entry ->
                   Some entry.Config.span
               | None ->
                   None
             in

             violation
               ?span
               ~path
               ~rule:rule_name
               (Field.string_of_validation_error
                  validation_error)))

(* ---------------------------------------------------------- *)
(* Dependency rules                                           *)
(* ---------------------------------------------------------- *)

let requires
    ?(severity = Error)
    path
    required =
  let rule_name =
    Printf.sprintf
      "requires:%s:%s"
      (Config.string_of_path path)
      (Config.string_of_path required)
  in

  make
    ~severity
    rule_name
    (fun context ->
      if not (exists context path) || exists context required then
        []
      else
        let span =
          match entry context path with
          | None ->
              None
          | Some entry ->
              Some entry.Config.span
        in

        [
          violation
            ?span
            ~severity
            ~path
            ~rule:rule_name
            (Printf.sprintf
               "'%s' requires '%s'"
               (Config.string_of_path path)
               (Config.string_of_path required));
        ])

let conflicts
    ?(severity = Error)
    left
    right =
  let rule_name =
    Printf.sprintf
      "conflicts:%s:%s"
      (Config.string_of_path left)
      (Config.string_of_path right)
  in

  make
    ~severity
    rule_name
    (fun context ->
      if exists context left && exists context right then
        let span =
          match entry context left with
          | None ->
              None
          | Some entry ->
              Some entry.Config.span
        in

        [
          violation
            ?span
            ~severity
            ~path:left
            ~rule:rule_name
            (Printf.sprintf
               "'%s' conflicts with '%s'"
               (Config.string_of_path left)
               (Config.string_of_path right));
        ]
      else
        [])

let exactly_one_of
    ?(severity = Error)
    paths =
  let names =
    List.map
      Config.string_of_path
      paths
  in

  let rule_name =
    "exactly-one-of:" ^ String.concat "," names
  in

  make
    ~severity
    rule_name
    (fun context ->
      let present =
        List.filter
          (exists context)
          paths
      in

      if List.length present = 1 then
        []
      else
        [
          violation
            ~severity
            ~rule:rule_name
            (Printf.sprintf
               "exactly one of [%s] must be configured"
               (String.concat ", " names));
        ])

let at_least_one_of
    ?(severity = Error)
    paths =
  let names =
    List.map
      Config.string_of_path
      paths
  in

  let rule_name =
    "at-least-one-of:" ^ String.concat "," names
  in

  make
    ~severity
    rule_name
    (fun context ->
      if List.exists (exists context) paths then
        []
      else
        [
          violation
            ~severity
            ~rule:rule_name
            (Printf.sprintf
               "at least one of [%s] must be configured"
               (String.concat ", " names));
        ])

let at_most_one_of
    ?(severity = Error)
    paths =
  let names =
    List.map
      Config.string_of_path
      paths
  in

  let rule_name =
    "at-most-one-of:" ^ String.concat "," names
  in

  make
    ~severity
    rule_name
    (fun context ->
      let present =
        List.filter
          (exists context)
          paths
      in

      if List.length present <= 1 then
        []
      else
        [
          violation
            ~severity
            ~rule:rule_name
            (Printf.sprintf
               "at most one of [%s] may be configured"
               (String.concat ", " names));
        ])

(* ---------------------------------------------------------- *)
(* Conditional rules                                          *)
(* ---------------------------------------------------------- *)

let when_present
    path
    rule =
  {
    rule with
    validator =
      (fun context ->
        if exists context path then
          rule.validator context
        else
          []);
  }

let unless_present
    path
    rule =
  {
    rule with
    validator =
      (fun context ->
        if exists context path then
          []
        else
          rule.validator context);
  }

let when_value
    path
    predicate
    rule =
  {
    rule with
    validator =
      (fun context ->
        match value context path with
        | Some value when predicate value ->
            rule.validator context

        | _ ->
            []);
  }

(* ---------------------------------------------------------- *)
(* Custom predicates                                          *)
(* ---------------------------------------------------------- *)

let predicate
    ?(severity = Error)
    ?description
    name
    test
    message =
  make
    ?description
    ~severity
    name
    (fun context ->
      if test context then
        []
      else
        [
          violation
            ~severity
            ~rule:name
            message;
        ])

let value_predicate
    ?(severity = Error)
    ?description
    path
    name
    test
    message =
  make
    ?description
    ~severity
    name
    (fun context ->
      match entry context path with
      | None ->
          []

      | Some entry ->
          if test entry.Config.value then
            []
          else
            [
              violation_for_entry
                ~severity
                ~rule:name
                message
                entry;
            ])

(* ---------------------------------------------------------- *)
(* Violation utilities                                        *)
(* ---------------------------------------------------------- *)

let is_error (violation : violation) =
  violation.severity = Error

let is_warning (violation : violation) =
  violation.severity = Warning

let errors violations =
  List.filter is_error violations

let warnings violations =
  List.filter is_warning violations

let has_errors violations =
  List.exists is_error violations

let has_warnings violations =
  List.exists is_warning violations

let count_errors violations =
  List.fold_left
    (fun count violation ->
      if is_error violation then
        count + 1
      else
        count)
    0
    violations

let count_warnings violations =
  List.fold_left
    (fun count violation ->
      if is_warning violation then
        count + 1
      else
        count)
    0
    violations

(* ---------------------------------------------------------- *)
(* Diagnostics                                                *)
(* ---------------------------------------------------------- *)

let diagnostic_of_violation (violation : violation) =
  match violation.severity with
  | Error ->
      Error.to_diagnostic
        (Error.make
           ?span:violation.span
           (Error.Schema_violation
              violation.message))

  | Warning ->
      Diagnostic.warning
        ?span:violation.span
        ~code:"VFW0401"
        violation.message

let diagnostics violations =
  List.map
    diagnostic_of_violation
    violations

(* ---------------------------------------------------------- *)
(* Formatting                                                 *)
(* ---------------------------------------------------------- *)

let string_of_severity = function
  | Error ->
      "error"
  | Warning ->
      "warning"

let string_of_violation violation =
  let location =
    match violation.path with
    | None ->
        ""
    | Some path ->
        Printf.sprintf
          "%s: "
          (Config.string_of_path path)
  in

  Printf.sprintf
    "%s%s [%s: %s]"
    location
    violation.message
    (string_of_severity violation.severity)
    violation.rule

let pp_severity formatter severity =
  Format.pp_print_string
    formatter
    (string_of_severity severity)

let pp_violation formatter violation =
  Format.pp_print_string
    formatter
    (string_of_violation violation)

let pp formatter rule =
  match rule.description with
  | None ->
      Format.fprintf
        formatter
        "%s (%s)"
        rule.name
        (string_of_severity rule.severity)

  | Some description ->
      Format.fprintf
        formatter
        "%s (%s): %s"
        rule.name
        (string_of_severity rule.severity)
        description