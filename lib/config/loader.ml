(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/config/loader.ml
 *
 * VFConf configuration loader.
 *
 * Responsibilities:
 *   - read VFConf files;
 *   - initialize the lexer/parser;
 *   - preserve source filenames and spans;
 *   - recursively resolve include statements;
 *   - detect include cycles through Include;
 *   - flatten sections into configuration paths;
 *   - evaluate basic assignment operators;
 *   - produce Config.t;
 *   - convert loader failures to canonical VFConf diagnostics.
 *)

type error =
  | Io_error of {
      filename : string;
      message : string;
    }
  | Lexing_error of {
      filename : string;
      line : int;
      column : int;
      message : string;
    }
  | Parsing_error of {
      filename : string;
      line : int;
      column : int;
      message : string;
    }
  | Include_error of Include.error
  | Duplicate_key of Config.path
  | Invalid_assignment of {
      path : Config.path;
      operator : Statement.assignment_operator;
    }
  | Unsupported_statement of string

exception Load_error of error

(* ---------------------------------------------------------- *)
(* Result                                                     *)
(* ---------------------------------------------------------- *)

type result = {
  config : Config.t;
  files : string list;
}

(* ---------------------------------------------------------- *)
(* Position helpers                                           *)
(* ---------------------------------------------------------- *)

let line_column_of_lexbuf lexbuf =
  let position =
    lexbuf.Lexing.lex_curr_p
  in

  let line =
    position.Lexing.pos_lnum
  in

  let column =
    position.Lexing.pos_cnum
    - position.Lexing.pos_bol
    + 1
  in

  (line, column)

let initialize_lexbuf filename source =
  let lexbuf =
    Lexing.from_string source
  in

  let position =
    {
      Lexing.pos_fname = filename;
      Lexing.pos_lnum = 1;
      Lexing.pos_bol = 0;
      Lexing.pos_cnum = 0;
    }
  in

  lexbuf.Lexing.lex_curr_p <- position;
  lexbuf

let span_of_location
    ~filename
    ~line
    ~column =
  let column =
    max 0 column
  in

  let position =
    Node.position
      ~offset:0
      ~line
      ~column
      ()
  in

  Node.span
    ~filename
    position
    position

(* ---------------------------------------------------------- *)
(* File reading                                               *)
(* ---------------------------------------------------------- *)

let read_file filename =
  try
    Include.read_file filename
  with
  | Include.Include_error error ->
      raise
        (Load_error
           (Include_error error))

  | Sys_error message ->
      raise
        (Load_error
           (Io_error
              {
                filename;
                message;
              }))

(* ---------------------------------------------------------- *)
(* Parsing                                                    *)
(* ---------------------------------------------------------- *)

let parse_source
    ~filename
    source =
  let lexbuf =
    initialize_lexbuf filename source
  in

  try
    Parser.document
      Lexer.token
      lexbuf

  with
  | Lexer.Error
      {
        kind;
        start_pos;
        end_pos = _;
      } ->
      let line =
        start_pos.Lexing.pos_lnum
      in

      let column =
        start_pos.Lexing.pos_cnum
        - start_pos.Lexing.pos_bol
      in

      let message =
        Lexer.message_of_error_kind kind
      in

      raise
        (Load_error
           (Lexing_error
              {
                filename;
                line;
                column;
                message;
              }))

  | Parser.Error ->
      let line, column =
        line_column_of_lexbuf lexbuf
      in

      raise
        (Load_error
           (Parsing_error
              {
                filename;
                line;
                column;
                message = "syntax error";
              }))

let parse_file filename =
  let filename =
    Include.canonicalize filename
  in

  let source =
    read_file filename
  in

  parse_source
    ~filename
    source

(* ---------------------------------------------------------- *)
(* Value operations                                           *)
(* ---------------------------------------------------------- *)

let append_values left right =
  match left.Node.value, right.Node.value with
  | Value.Array left_values,
    Value.Array right_values ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Array
              (left_values @ right_values)))

  | Value.String left_value,
    Value.String right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.String
              (left_value ^ right_value)))

  | Value.Integer left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Integer
              (Int64.add left_value right_value)))

  | Value.Float left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value +. right_value)))

  | Value.Integer left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (Int64.to_float left_value +. right_value)))

  | Value.Float left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value +. Int64.to_float right_value)))

  | _ ->
      None

let subtract_values left right =
  match left.Node.value, right.Node.value with
  | Value.Integer left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Integer
              (Int64.sub left_value right_value)))

  | Value.Float left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value -. right_value)))

  | Value.Integer left_value,
    Value.Float right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (Int64.to_float left_value -. right_value)))

  | Value.Float left_value,
    Value.Integer right_value ->
      Some
        (Node.located
           (Node.merge left right)
           (Value.Float
              (left_value -. Int64.to_float right_value)))

  | Value.Array left_values,
    Value.Array right_values ->
      let filtered =
        List.filter
          (fun left_item ->
            not
              (List.exists
                 (fun right_item ->
                   Value.equal
                     left_item.Node.value
                     right_item.Node.value)
                 right_values))
          left_values
      in

      Some
        (Node.located
           (Node.merge left right)
           (Value.Array filtered))

  | _ ->
      None

(* ---------------------------------------------------------- *)
(* Assignment application                                     *)
(* ---------------------------------------------------------- *)

let apply_assignment
    config
    path
    operator
    value =
  match operator with
  | Statement.Assign ->
      Config.set
        path
        value
        config

  | Statement.Define_assign ->
      if Config.mem path config then
        raise
          (Load_error
             (Duplicate_key path))
      else
        Config.add
          path
          value
          config

  | Statement.Add_assign ->
      begin
        match Config.find_opt path config with
        | None ->
            Config.set
              path
              value
              config

        | Some current ->
            begin
              match append_values current value with
              | Some value ->
                  Config.set
                    path
                    value
                    config

              | None ->
                  raise
                    (Load_error
                       (Invalid_assignment
                          {
                            path;
                            operator;
                          }))
            end
      end

  | Statement.Sub_assign ->
      begin
        match Config.find_opt path config with
        | None ->
            raise
              (Load_error
                 (Invalid_assignment
                    {
                      path;
                      operator;
                    }))

        | Some current ->
            begin
              match subtract_values current value with
              | Some value ->
                  Config.set
                    path
                    value
                    config

              | None ->
                  raise
                    (Load_error
                       (Invalid_assignment
                          {
                            path;
                            operator;
                          }))
            end
      end

(* ---------------------------------------------------------- *)
(* Condition evaluation                                       *)
(* ---------------------------------------------------------- *)

let compare_values operator left right =
  let compare_result result =
    match operator with
    | Statement.Equal ->
        result = 0
    | Statement.Not_equal ->
        result <> 0
    | Statement.Less ->
        result < 0
    | Statement.Less_equal ->
        result <= 0
    | Statement.Greater ->
        result > 0
    | Statement.Greater_equal ->
        result >= 0
  in

  match left, right with
  | Value.Integer left,
    Value.Integer right ->
      compare_result
        (Int64.compare left right)

  | Value.Float left,
    Value.Float right ->
      compare_result
        (Float.compare left right)

  | Value.Integer left,
    Value.Float right ->
      compare_result
        (Float.compare
           (Int64.to_float left)
           right)

  | Value.Float left,
    Value.Integer right ->
      compare_result
        (Float.compare
           left
           (Int64.to_float right))

  | Value.String left,
    Value.String right ->
      compare_result
        (String.compare left right)

  | Value.Boolean left,
    Value.Boolean right ->
      compare_result
        (Bool.compare left right)

  | _ ->
      begin
        match operator with
        | Statement.Equal ->
            Value.equal left right

        | Statement.Not_equal ->
            not (Value.equal left right)

        | _ ->
            false
      end

let find_condition_value
    prefix
    config
    path =
  let local_path =
    prefix @ path
  in

  match
    if prefix = [] then
      None
    else
      Config.find_value_opt local_path config
  with
  | Some value ->
      Some value

  | None ->
      Config.find_value_opt path config

let rec evaluate_condition
    prefix
    config
    condition =
  match condition.Node.value with
  | Statement.Reference path ->
      begin
        match find_condition_value prefix config path with
        | Some (Value.Boolean value) ->
            value

        | Some Value.Null ->
            false

        | Some _ ->
            true

        | None ->
            false
      end

  | Statement.Boolean value ->
      value

  | Statement.Not condition ->
      not
        (evaluate_condition
           prefix
           config
           condition)

  | Statement.Logical
      {
        left;
        operator = Statement.And;
        right;
      } ->
      evaluate_condition prefix config left
      && evaluate_condition prefix config right

  | Statement.Logical
      {
        left;
        operator = Statement.Or;
        right;
      } ->
      evaluate_condition prefix config left
      || evaluate_condition prefix config right

  | Statement.Compare
      {
        reference;
        operator;
        value;
      } ->
      begin
        match
          find_condition_value
            prefix
            config
            reference
        with
        | None ->
            false

        | Some left ->
            compare_values
              operator
              left
              value.Node.value
      end

(* ---------------------------------------------------------- *)
(* Statement loading                                          *)
(* ---------------------------------------------------------- *)

let rec load_statements
    include_context
    prefix
    config
    files
    statements =
  List.fold_left
    (fun (config, files) statement ->
      load_statement
        include_context
        prefix
        config
        files
        statement)
    (config, files)
    statements

and load_statement
    include_context
    prefix
    config
    files
    statement =
  match statement.Node.value with
  | Statement.Assignment assignment ->
      let path =
        prefix @ assignment.Statement.key
      in

      let config =
        apply_assignment
          config
          path
          assignment.Statement.operator
          assignment.Statement.value
      in

      (config, files)

  | Statement.Define definition ->
      let path =
        prefix @ [definition.Statement.name]
      in

      let config =
        if Config.mem path config then
          raise
            (Load_error
               (Duplicate_key path))
        else
          Config.add
            path
            definition.Statement.value
            config
      in

      (config, files)

  | Statement.Section section ->
      let prefix =
        prefix @ section.Statement.name
      in

      load_statements
        include_context
        prefix
        config
        files
        section.Statement.body

  | Statement.Conditional conditional ->
      let selected =
        if
          evaluate_condition
            prefix
            config
            conditional.Statement.condition
        then
          conditional.Statement.then_branch
        else
          match conditional.Statement.else_branch with
          | Some statements ->
              statements
          | None ->
              []
      in

      load_statements
        include_context
        prefix
        config
        files
        selected

  | Statement.Include include_statement ->
      let include_path =
        include_statement.Statement.path
      in

      let resolved, child_context =
        try
          Include.enter
            include_context
            include_path
        with
        | Include.Include_error error ->
            raise
              (Load_error
                 (Include_error error))
      in

      let document =
        parse_file resolved
      in

      let files =
        if List.mem resolved files then
          files
        else
          resolved :: files
      in

      load_statements
        child_context
        prefix
        config
        files
        document

(* ---------------------------------------------------------- *)
(* Document loading                                           *)
(* ---------------------------------------------------------- *)

let load_document
    ?filename
    statements =
  let config =
    Config.empty ?filename ()
  in

  let include_context =
    match filename with
    | Some filename ->
        let filename =
          Include.canonicalize filename
        in

        let context =
          Include.create_context
            (Filename.dirname filename)
        in

        Include.push
          filename
          context

    | None ->
        Include.empty_context ()
  in

  let config, files =
    load_statements
      include_context
      []
      config
      []
      statements
  in

  {
    config;
    files = List.rev files;
  }

(* ---------------------------------------------------------- *)
(* Source loading                                             *)
(* ---------------------------------------------------------- *)

let load_source
    ?(filename = "<memory>")
    source =
  let document =
    parse_source
      ~filename
      source
  in

  if String.equal filename "<memory>" then
    load_document document
  else
    load_document
      ~filename
      document

(* ---------------------------------------------------------- *)
(* File loading                                               *)
(* ---------------------------------------------------------- *)

let load_file filename =
  let filename =
    Include.canonicalize filename
  in

  try
    Include.validate_file filename;

    let source =
      read_file filename
    in

    let document =
      parse_source
        ~filename
        source
    in

    let context =
      Include.create_context
        (Filename.dirname filename)
      |> Include.push filename
    in

    let config =
      Config.empty
        ~filename
        ()
    in

    let config, files =
      load_statements
        context
        []
        config
        [filename]
        document
    in

    {
      config;
      files = List.rev files;
    }

  with
  | Include.Include_error
      (Include.File_not_found path) ->
      raise
        (Load_error
           (Io_error
              {
                filename = path;
                message = "file not found";
              }))

  | Include.Include_error error ->
      raise
        (Load_error
           (Include_error error))

(* ---------------------------------------------------------- *)
(* Convenience API                                            *)
(* ---------------------------------------------------------- *)

let config_of_file filename =
  (load_file filename).config

let config_of_source
    ?filename
    source =
  (load_source ?filename source).config

let files result =
  result.files

let config result =
  result.config

(* ---------------------------------------------------------- *)
(* Canonical diagnostics                                      *)
(* ---------------------------------------------------------- *)

let diagnostic_of_include_error = function
  | Include.File_not_found path ->
      Error.make
        (Error.Include_not_found path)
      |> Error.to_diagnostic

  | Include.Include_cycle paths ->
      Error.make
        (Error.Include_cycle paths)
      |> Error.to_diagnostic

  | Include.Maximum_depth_exceeded
      {
        maximum;
        path;
      } ->
      Error.make
        (Error.Include_depth_exceeded
           {
             maximum;
             path;
           })
      |> Error.to_diagnostic

  | Include.Empty_path ->
      Error.make
        (Error.Invalid_include "")
      |> Error.to_diagnostic

  | Include.Invalid_extension path
  | Include.Is_directory path ->
      Error.make
        (Error.Invalid_include path)
      |> Error.to_diagnostic

  | Include.Io_error { path; message } ->
      Error.make
        (Error.Cannot_read_file
           {
             path;
             message;
           })
      |> Error.to_diagnostic

let diagnostic_of_error = function
  | Io_error { filename; message }
    when String.equal message "file not found" ->
      Error.make
        (Error.File_not_found filename)
      |> Error.to_diagnostic

  | Io_error { filename; message } ->
      Error.make
        (Error.Cannot_read_file
           {
             path = filename;
             message;
           })
      |> Error.to_diagnostic

  | Lexing_error
      {
        filename;
        line;
        column;
        message;
      } ->
      let span =
        span_of_location
          ~filename
          ~line
          ~column
      in

      Error.make
        ~span
        (Error.Invalid_token message)
      |> Error.to_diagnostic

  | Parsing_error
      {
        filename;
        line;
        column;
        message;
      } ->
      let span =
        span_of_location
          ~filename
          ~line
          ~column
      in

      Error.make
        ~span
        (Error.Unexpected_token message)
      |> Error.to_diagnostic

  | Include_error error ->
      diagnostic_of_include_error error

  | Duplicate_key path ->
      Error.make
        (Error.Duplicate_key
           (Config.string_of_path path))
      |> Error.to_diagnostic

  | Invalid_assignment { path; operator } ->
      Error.make
        (Error.Invalid_assignment
           {
             key =
               Config.string_of_path path;
             operator =
               Statement.string_of_assignment_operator
                 operator;
           })
      |> Error.to_diagnostic

  | Unsupported_statement statement ->
      Error.make
        (Error.Evaluation_failed
           (Printf.sprintf
              "unsupported VFConf statement: %s"
              statement))
      |> Error.to_diagnostic

(* ---------------------------------------------------------- *)
(* Error formatting                                           *)
(* ---------------------------------------------------------- *)

let string_of_error = function
  | Io_error { filename; message } ->
      Printf.sprintf
        "%s: %s"
        filename
        message

  | Lexing_error
      {
        filename;
        line;
        column;
        message;
      } ->
      Printf.sprintf
        "%s:%d:%d: lexical error: %s"
        filename
        line
        column
        message

  | Parsing_error
      {
        filename;
        line;
        column;
        message;
      } ->
      Printf.sprintf
        "%s:%d:%d: syntax error: %s"
        filename
        line
        column
        message

  | Include_error error ->
      Include.string_of_error error

  | Duplicate_key path ->
      Printf.sprintf
        "duplicate configuration key: %s"
        (Config.string_of_path path)

  | Invalid_assignment { path; operator } ->
      Printf.sprintf
        "invalid '%s' assignment for configuration key: %s"
        (Statement.string_of_assignment_operator operator)
        (Config.string_of_path path)

  | Unsupported_statement statement ->
      Printf.sprintf
        "unsupported VFConf statement: %s"
        statement

let pp_error formatter error =
  Format.pp_print_string
    formatter
    (string_of_error error)

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

let dump_result formatter result =
  Format.fprintf
    formatter
    "@[<v>VFConf loader result:@,\
     files:";

  List.iter
    (fun filename ->
      Format.fprintf
        formatter
        "@,  %s"
        filename)
    result.files;

  Format.fprintf
    formatter
    "@,@,configuration:@,%a@]"
    Config.pp
    result.config