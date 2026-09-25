let version = "0.1.0"

let usage () =
  Printf.printf
    {|NAME
       vfconf - compiler-grade toolchain for the Vitte Foundation
       Configuration Language

SYNOPSIS
       vfconf [GLOBAL-OPTIONS] COMMAND [ARGUMENTS]
       vfconf COMMAND --help
       vfconf --version

DESCRIPTION
       VFConf is the command-line interface for reading, validating,
       formatting, inspecting, modifying, comparing, merging, resolving
       and evaluating Vitte Foundation Configuration Language files.

       VFConf configuration files conventionally use the .vf.conf
       extension and the text/x-vfconf MIME type.

       A configuration may contain sections, assignments, typed values,
       arrays, objects, references, definitions, conditional statements
       and includes.

       Commands are divided into parsing, validation, formatting,
       configuration manipulation, evaluation, schema inspection,
       dependency inspection and project tooling.

CORE COMMANDS
       check FILE
              Parse and semantically validate FILE.

              Lexical, syntax and semantic diagnostics are reported with
              their source locations when available.

              No configuration data is modified.

              Example:
                     vfconf check config.vf.conf

       check-all [PATH]
              Recursively search PATH for VFConf files and validate each
              discovered configuration.

              Useful for validating an entire configuration repository.

              Example:
                     vfconf check-all config/

       parse FILE
              Parse FILE and verify that its VFConf syntax can be
              recognized by the frontend.

              Example:
                     vfconf parse config.vf.conf

       dump FILE
              Parse FILE and display its internal parsed representation.

              Intended primarily for frontend development, debugging and
              parser inspection.

              Example:
                     vfconf dump config.vf.conf

       ast FILE
              Display the abstract syntax tree produced from FILE.

              This exposes the structural representation used internally
              by VFConf.

              Example:
                     vfconf ast config.vf.conf

       tokens FILE
              Run the VFConf lexer and display the generated tokens,
              including source position information where available.

              Useful for debugging lexical problems.

              Example:
                     vfconf tokens config.vf.conf

       diagnostics FILE
              Parse and validate FILE and display its diagnostics.

              Unlike check, this command is intended specifically for
              diagnostic inspection and tooling integration.

              Example:
                     vfconf diagnostics config.vf.conf

       explain CODE
              Display the description of a VFConf diagnostic code.

              Diagnostic codes use namespaces such as VF0001, VF0101,
              VF0202 and related codes from the canonical diagnostic
              catalogue.

              Example:
                     vfconf explain VF0202

       stats FILE
              Display statistics collected from FILE.

              Example:
                     vfconf stats config.vf.conf

FORMATTING COMMANDS
       fmt FILE
              Parse FILE and print its canonical VFConf representation to
              standard output.

              The original file is not modified.

              Example:
                     vfconf fmt config.vf.conf

       fmt --write FILE
              Parse and format FILE, then replace its contents with the
              canonical representation.

              Example:
                     vfconf fmt --write config.vf.conf

       fmt --check FILE
              Check whether FILE already uses canonical formatting.

              The file is not modified.

              Exit status 0 indicates canonical formatting. Exit status 1
              indicates that formatting changes are required.

              Example:
                     vfconf fmt --check config.vf.conf

       fmt --stdout FILE
              Explicit form of "fmt FILE". Write canonical VFConf to
              standard output without modifying FILE.

              Example:
                     vfconf fmt --stdout config.vf.conf

       fmt --diff FILE
              Compare FILE with its canonical formatted representation and
              display the textual differences.

              Exit status 0 means no formatting differences were found.
              Exit status 1 means differences were found.

              Example:
                     vfconf fmt --diff config.vf.conf

       fmt-all PATH
              Recursively format VFConf files below PATH.

              Example:
                     vfconf fmt-all config/

CONFIGURATION COMMANDS
       get PATH FILE
              Read the configuration value stored at the exact dotted PATH.

              PATH components are separated with ".".

              Examples:
                     vfconf get language.id config.vf.conf
                     vfconf get build.timeout config.vf.conf
                     vfconf get compiler.backend.name config.vf.conf

              A missing path produces exit status 1.

       set PATH VALUE FILE
              Set PATH to VALUE in FILE.

              VALUE must use valid VFConf value syntax. Strings therefore
              need VFConf quotes.

              Examples:
                     vfconf set language.id '"zig"' config.vf.conf
                     vfconf set build.timeout 30 config.vf.conf
                     vfconf set build.enabled true config.vf.conf

              Existing values are replaced. New paths may be created
              according to the configuration structure supported by the
              command.

       unset PATH FILE
              Remove the configuration entry identified by PATH.

              Example:
                     vfconf unset build.timeout config.vf.conf

              A path is expressed using its complete dotted configuration
              name.

       exists PATH FILE
              Test whether PATH exists in FILE.

              The command prints a boolean result.

              Exit status 0 means the path exists.
              Exit status 1 means the path does not exist.

              Example:
                     vfconf exists language.id config.vf.conf

       list FILE
              Display the configuration as a flat list of complete paths
              and values.

              Example output:
                     build.enabled = true
                     build.timeout = 30
                     language.id = "zig"
                     language.name = "Zig"

              Example:
                     vfconf list config.vf.conf

       tree FILE
              Display configuration entries hierarchically.

              Example output:
                     compiler
                       backend
                         name = "llvm"
                         optimization = 3

              Example:
                     vfconf tree config.vf.conf

       diff FILE1 FILE2
              Compare two configurations semantically.

              The comparison operates on configuration entries rather than
              raw source formatting.

              Output uses:
                     +    entry added
                     -    entry removed
                     ~    entry changed

              Example:
                     vfconf diff old.vf.conf new.vf.conf

              Exit status 0 means the configurations are equal.
              Exit status 1 means semantic differences were found.

       merge FILE1 FILE2 [FILE...]
              Merge two or more configurations and write the resulting
              VFConf configuration to standard output.

              Files are processed from left to right. With the default
              merge policy, later scalar values override earlier values.

              The current default policy uses replacement for arrays and
              recursive merging for objects.

              Example:
                     vfconf merge base.vf.conf local.vf.conf

              Save the result with shell redirection:

                     vfconf merge base.vf.conf local.vf.conf \
                            > merged.vf.conf

       resolve FILE
              Resolve references in FILE and print the resulting canonical
              configuration to standard output.

              Configuration references and definition references are
              resolved through the VFConf evaluator/reference engine.

              Example input:
                     [paths]
                     root = "/opt/vitte"
                     compiler = $paths.root

              Example:
                     vfconf resolve config.vf.conf

              Undefined references, cycles and resolution-depth failures
              are reported as reference errors.

       eval PATH FILE
              Evaluate FILE and print the final value associated with PATH.

              Unlike get, eval operates on the evaluated configuration and
              resolves references before printing the requested value.

              Example:
                     vfconf eval paths.compiler config.vf.conf

              Conceptually:

                     get      read a stored configuration value
                     eval     evaluate and resolve one value
                     resolve  resolve the complete configuration

       query EXPR FILE
              Select configuration entries using a VFConf query expression.

              Supported query forms:

                     language.id
                            Match one exact path.

                     build.*
                            Match one component below build.

                     compiler.**
                            Recursively match entries below compiler.

                     **.name
                            Recursively match entries whose final component
                            is "name".

                     **
                            Match every configuration entry.

              When exactly one entry matches, its value is printed.

              When multiple entries match, complete paths and values are
              printed.

              Exit status 1 means no entry matched the expression.

              Examples:
                     vfconf query language.id config.vf.conf
                     vfconf query 'build.*' config.vf.conf
                     vfconf query 'compiler.**' config.vf.conf
                     vfconf query '**.name' config.vf.conf
                     vfconf query '**' config.vf.conf

SCHEMA COMMANDS
       schema check FILE
              Check schema-related information associated with FILE.

       schema validate SCHEMA FILE
              Validate FILE against SCHEMA.

       schema fields FILE
              Display schema fields.

       schema rules FILE
              Display schema validation rules.

       schema infer FILE
              Infer schema information from an existing configuration.

INCLUDE COMMANDS
       include list FILE
              List include directives associated with FILE.

       include tree FILE
              Display include relationships hierarchically.

       include check FILE
              Check include declarations and include-related errors.

       include resolve FILE
              Resolve includes and inspect the resulting configuration.

REFERENCE COMMANDS
       ref list FILE
              List references found in FILE.

       ref check FILE
              Check references for resolution errors.

       ref resolve PATH FILE
              Resolve the reference associated with PATH.

       ref graph FILE
              Display reference dependencies as a graph representation.

PROJECT COMMANDS
       init [FILE]
              Initialize a VFConf configuration.

       new NAME
              Create a new VFConf-based project.

       doctor
              Inspect the current VFConf installation and project for
              configuration problems.

       info
              Display information about the current project.

       files
              List project-related VFConf files.

       clean
              Remove generated VFConf project artifacts.

LANGUAGE COMMANDS
       language list
              List registered language definitions.

       language show NAME
              Display the configuration for language NAME.

       language check NAME
              Validate language NAME.

       language detect FILE
              Detect the language associated with FILE.

THEME COMMANDS
       theme list
              List registered VFConf themes.

       theme show NAME
              Display theme NAME.

       theme check NAME
              Validate theme NAME.

TOOLS
       completion bash
       completion zsh
       completion fish
              Generate shell completion code for the selected shell.

              Example:
                     vfconf completion zsh

       version
              Display the VFConf version.

       help
              Display the global VFConf manual.

GLOBAL OPTIONS
       --color MODE
              Configure diagnostic/output colors.

              MODE is:
                     auto
                     always
                     never

       --output FORMAT
              Select the output representation.

              FORMAT is:
                     human
                     json

       --strict
              Enable strict validation behavior.

       --quiet
              Suppress normal informational output.

       --verbose
              Enable additional command output.

       --debug
              Enable debugging information.

       --max-errors N
              Stop reporting diagnostics after N errors.

       --root PATH
              Use PATH as the VFConf project root.

       -V, --version
              Display VFConf version information and exit.

       -h, --help
              Display this manual and exit.

VALUE SYNTAX
       VFConf values include strings, integers, floating-point values,
       booleans, null, arrays, objects, references, colors, durations and
       sizes.

       Examples:
              "zig"
              30
              3.14
              true
              null
              ["vit", "vitl"]
              $compiler.backend
              #ff8800
              30s
              512MiB

PATH SYNTAX
       Configuration paths use dot-separated components.

       Examples:
              language.id
              build.timeout
              compiler.backend.name

QUERY SYNTAX
       *
              Match exactly one path component.

       **
              Match zero or more path components recursively.

       Exact components may be combined with wildcards.

       Examples:
              build.*
              compiler.**
              **.name

EXIT STATUS
       0      Command completed successfully.

       1      Configuration invalid, requested path/query absent,
              configurations differ, or formatting changes are required.

       2      Invalid command-line arguments or command usage.

       3      Input/output failure.

       4      Schema validation failure.

       5      Evaluation failure.

       6      Include or reference resolution failure.

       7      Internal VFConf failure.

FILES
       *.vf.conf
              Standard VFConf source/configuration file extension.

       text/x-vfconf
              VFConf MIME type.

EXAMPLES
       Validate a configuration:

              vfconf check config.vf.conf

       Format a configuration:

              vfconf fmt --write config.vf.conf

       Read a value:

              vfconf get language.id config.vf.conf

       Modify a value:

              vfconf set build.timeout 60 config.vf.conf

       Inspect the complete configuration:

              vfconf tree config.vf.conf

       Compare configurations:

              vfconf diff old.vf.conf new.vf.conf

       Merge configurations:

              vfconf merge base.vf.conf local.vf.conf > merged.vf.conf

       Resolve all references:

              vfconf resolve config.vf.conf > resolved.vf.conf

       Evaluate one value:

              vfconf eval paths.compiler config.vf.conf

       Query a subtree:

              vfconf query 'compiler.**' config.vf.conf

VERSION
       VFConf %s

|}
    version

type color_mode =
  | Color_auto
  | Color_always
  | Color_never

type output_format =
  | Output_human
  | Output_json

type global_options = {
  color : color_mode;
  output : output_format;
  strict : bool;
  quiet : bool;
  verbose : bool;
  debug : bool;
  max_errors : int option;
  root : string option;
}

let default_global_options =
  {
    color = Color_auto;
    output = Output_human;
    strict = false;
    quiet = false;
    verbose = false;
    debug = false;
    max_errors = None;
    root = None;
  }

let cli_error message =
  Printf.eprintf
    "vfconf: %s\nTry 'vfconf --help' for usage.\n"
    message;
  exit 2

let parse_color = function
  | "auto" -> Color_auto
  | "always" -> Color_always
  | "never" -> Color_never
  | value ->
      cli_error
        (Printf.sprintf
           "invalid --color value '%s' (expected auto, always, or never)"
           value)

let parse_output = function
  | "human" -> Output_human
  | "json" -> Output_json
  | value ->
      cli_error
        (Printf.sprintf
           "invalid --output value '%s' (expected human or json)"
           value)

let parse_max_errors value =
  match int_of_string_opt value with
  | Some value when value > 0 ->
      value
  | _ ->
      cli_error
        (Printf.sprintf
           "invalid --max-errors value '%s' (expected a positive integer)"
           value)

let rec parse_global_options options = function
  | "--color" :: value :: rest ->
      parse_global_options
        { options with color = parse_color value }
        rest

  | "--color" :: [] ->
      cli_error "--color requires MODE"

  | "--output" :: value :: rest ->
      parse_global_options
        { options with output = parse_output value }
        rest

  | "--output" :: [] ->
      cli_error "--output requires FORMAT"

  | "--strict" :: rest ->
      parse_global_options
        { options with strict = true }
        rest

  | "--quiet" :: rest ->
      parse_global_options
        { options with quiet = true }
        rest

  | "--verbose" :: rest ->
      parse_global_options
        { options with verbose = true }
        rest

  | "--debug" :: rest ->
      parse_global_options
        { options with debug = true }
        rest

  | "--max-errors" :: value :: rest ->
      parse_global_options
        { options with max_errors = Some (parse_max_errors value) }
        rest

  | "--max-errors" :: [] ->
      cli_error "--max-errors requires N"

  | "--root" :: value :: rest ->
      parse_global_options
        { options with root = Some value }
        rest

  | "--root" :: [] ->
      cli_error "--root requires PATH"

  | arguments ->
      options, arguments

let apply_root options =
  match options.root with
  | None ->
      ()

  | Some root ->
      if not (Sys.file_exists root) then
        cli_error
          (Printf.sprintf
             "root path does not exist: %s"
             root);

      if not (Sys.is_directory root) then
        cli_error
          (Printf.sprintf
             "root path is not a directory: %s"
             root);

      begin
        try Unix.chdir root
        with
        | Unix.Unix_error (error, _, _) ->
            Printf.eprintf
              "vfconf: cannot use root '%s': %s\n"
              root
              (Unix.error_message error);
            exit 3
      end

let string_of_color_mode = function
  | Color_auto -> "auto"
  | Color_always -> "always"
  | Color_never -> "never"

let string_of_output_format = function
  | Output_human -> "human"
  | Output_json -> "json"

let debug_global_options options =
  if options.debug then begin
    Printf.eprintf
      "vfconf: debug: color=%s output=%s strict=%b quiet=%b verbose=%b debug=%b"
      (string_of_color_mode options.color)
      (string_of_output_format options.output)
      options.strict
      options.quiet
      options.verbose
      options.debug;

    begin
      match options.max_errors with
      | None ->
          Printf.eprintf " max-errors=unlimited"
      | Some value ->
          Printf.eprintf " max-errors=%d" value
    end;

    begin
      match options.root with
      | None ->
          Printf.eprintf " root=<current>"
      | Some root ->
          Printf.eprintf " root=%s" root
    end;

    Printf.eprintf "\n"
  end

let executable_name = function
  | "vfconf-check" -> "check.exe"
  | "vfconf-dump" -> "dump.exe"
  | "vfconf-fmt" -> "fmt.exe"
  | name -> name

let executable_directory () =
  Filename.dirname Sys.executable_name

let local_executable program =
  Filename.concat
    (executable_directory ())
    (executable_name program)

let run_external ?(quiet = false) program arguments =
  let local = local_executable program in
  let executable =
    if Sys.file_exists local then
      local
    else
      program
  in
  let argv =
    Array.of_list (program :: arguments)
  in
  try
    if quiet then begin
      let dev_null =
        Unix.openfile
          "/dev/null"
          [Unix.O_WRONLY]
          0
      in
      Unix.dup2 dev_null Unix.stdout;
      Unix.close dev_null
    end;
    Unix.execvp executable argv
  with
  | Unix.Unix_error
      (Unix.ENOENT, _, _) ->
      Printf.eprintf
        "vfconf: required command not found: %s\n"
        program;
      exit 7

  | Unix.Unix_error
      (error, _, _) ->
      Printf.eprintf
        "vfconf: cannot execute %s: %s\n"
        program
        (Unix.error_message error);
      exit 7


let unsupported command =
  Printf.eprintf
    "vfconf: command '%s' is registered but not implemented yet\n"
    command;
  exit 2

let run_fmt options = function
  | [] ->
      Printf.eprintf "vfconf: fmt requires FILE.vf.conf\n";
      exit 2

  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--version"]

  | [file] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--stdout"; file]

  | ["--write"; file]
  | ["-w"; file] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--write"; file]

  | ["--check"; file]
  | ["-c"; file] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--check"; file]

  | ["--stdout"; file]
  | ["-p"; file] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--stdout"; file]

  | ["--diff"; file] ->
      run_external ~quiet:options.quiet "vfconf-fmt" ["--diff"; file]

  | _ ->
      Printf.eprintf "vfconf: invalid fmt arguments\n";
      exit 2

let run_fmt_all options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-fmt-all" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-fmt-all" ["--version"]

  | [path] ->
      run_external ~quiet:options.quiet "vfconf-fmt-all" [path]

  | _ ->
      Printf.eprintf "vfconf: invalid fmt-all arguments\n";
      exit 2

let run_get options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-get" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-get" ["--version"]

  | [path; filename] ->
      run_external ~quiet:options.quiet "vfconf-get" [path; filename]

  | _ ->
      Printf.eprintf "vfconf: invalid get arguments\n";
      exit 2

let run_exists options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-exists" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-exists" ["--version"]

  | [path; filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-exists"
        [path; filename]

  | _ ->
      Printf.eprintf "vfconf: invalid exists arguments\n";
      exit 2

let run_list options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-list" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-list" ["--version"]

  | [filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-list"
        [filename]

  | _ ->
      Printf.eprintf "vfconf: invalid list arguments\n";
      exit 2

let run_tree options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-tree" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-tree" ["--version"]

  | [filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-tree"
        [filename]

  | _ ->
      Printf.eprintf "vfconf: invalid tree arguments\n";
      exit 2

let run_diff options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-diff" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-diff" ["--version"]

  | [left_filename; right_filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-diff"
        [left_filename; right_filename]

  | _ ->
      Printf.eprintf "vfconf: invalid diff arguments\n";
      exit 2

let run_merge options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-merge" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-merge" ["--version"]

  | files when List.length files >= 2 ->
      run_external
        ~quiet:options.quiet
        "vfconf-merge"
        files

  | _ ->
      Printf.eprintf "vfconf: invalid merge arguments\n";
      exit 2

let run_resolve options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-resolve" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-resolve" ["--version"]

  | [filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-resolve"
        [filename]

  | _ ->
      Printf.eprintf "vfconf: invalid resolve arguments\n";
      exit 2

let run_eval options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-eval" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-eval" ["--version"]

  | [path; filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-eval"
        [path; filename]

  | _ ->
      Printf.eprintf "vfconf: invalid eval arguments\n";
      exit 2

let run_query options = function
  | ["--help"]
  | ["-h"] ->
      run_external ~quiet:options.quiet "vfconf-query" ["--help"]

  | ["--version"]
  | ["-V"] ->
      run_external ~quiet:options.quiet "vfconf-query" ["--version"]

  | [expression; filename] ->
      run_external
        ~quiet:options.quiet
        "vfconf-query"
        [expression; filename]

  | _ ->
      Printf.eprintf "vfconf: invalid query arguments\n";
      exit 2

let registered_commands =
  [
    "check";
    "check-all";
    "parse";
    "dump";
    "ast";
    "tokens";
    "diagnostics";
    "explain";
    "stats";

    "fmt";
    "fmt-all";

    "get";
    "set";
    "unset";
    "exists";
    "list";
    "tree";
    "diff";
    "merge";
    "resolve";
    "eval";
    "query";

    "schema";
    "include";
    "ref";

    "init";
    "new";
    "doctor";
    "info";
    "files";
    "clean";

    "language";
    "theme";

    "completion";
  ]

let is_registered command =
  List.mem command registered_commands

let completion_commands =
  String.concat " " registered_commands
  ^ " help version"

let completion_global_options =
  "--color --output --strict --quiet --verbose --debug \
--max-errors --root --version --help -V -h"

let generate_bash_completion () =
  Printf.printf
{|_vfconf_completion()
{
    local cur prev commands

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="%s"
    local global_options="%s"

    case "$prev" in
        --color)
            COMPREPLY=( $(compgen -W "auto always never" -- "$cur") )
            return 0
            ;;
        --output)
            COMPREPLY=( $(compgen -W "human json" -- "$cur") )
            return 0
            ;;
        completion)
            COMPREPLY=( $(compgen -W "bash zsh fish" -- "$cur") )
            return 0
            ;;
        fmt)
            COMPREPLY=( $(compgen -W "--write --check --stdout --diff" -- "$cur") )
            return 0
            ;;
        schema)
            COMPREPLY=( $(compgen -W "check validate fields rules infer" -- "$cur") )
            return 0
            ;;
        include)
            COMPREPLY=( $(compgen -W "list tree check resolve" -- "$cur") )
            return 0
            ;;
        ref)
            COMPREPLY=( $(compgen -W "list check resolve graph" -- "$cur") )
            return 0
            ;;
        language)
            COMPREPLY=( $(compgen -W "list show check detect" -- "$cur") )
            return 0
            ;;
        theme)
            COMPREPLY=( $(compgen -W "list show check" -- "$cur") )
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$global_options" -- "$cur") )
        return 0
    fi

    if (( COMP_CWORD == 1 )); then
        COMPREPLY=( $(compgen -W "$commands $global_options" -- "$cur") )
        return 0
    fi

    case "${COMP_WORDS[1]}" in
        check|parse|dump|ast|tokens|diagnostics|stats|fmt)
            compopt -o filenames 2>/dev/null
            COMPREPLY=( $(compgen -f -- "$cur") )
            ;;
    esac
}
complete -F _vfconf_completion vfconf
|}
    completion_commands
    completion_global_options

let generate_zsh_completion () =
  Printf.printf
{|#compdef vfconf

_vfconf()
{
  local -a commands

  commands=(
    'check:Parse and validate a file'
    'check-all:Validate files recursively'
    'parse:Parse a file'
    'dump:Dump parsed configuration'
    'ast:Display AST'
    'tokens:Display lexer tokens'
    'diagnostics:Display diagnostics'
    'explain:Explain a diagnostic code'
    'stats:Display configuration statistics'
    'fmt:Format VFConf source'
    'fmt-all:Format recursively'
    'get:Read a value'
    'set:Set a value'
    'unset:Remove a value'
    'exists:Test whether a path exists'
    'list:List configuration paths'
    'tree:Display configuration tree'
    'diff:Compare configurations'
    'merge:Merge configurations'
    'resolve:Resolve configuration'
    'eval:Evaluate a value'
    'query:Query configuration'
    'schema:Schema operations'
    'include:Include operations'
    'ref:Reference operations'
    'init:Create configuration'
    'new:Create project'
    'doctor:Check installation or project'
    'info:Display project information'
    'files:List project files'
    'clean:Clean generated artifacts'
    'language:Language operations'
    'theme:Theme operations'
    'completion:Generate shell completion'
    'version:Display version'
    'help:Display help'
  )

  _arguments -C \
    '--color[Color mode]:mode:(auto always never)' \
    '--output[Output format]:format:(human json)' \
    '--strict[Enable strict validation]' \
    '--quiet[Suppress normal output]' \
    '--verbose[Verbose output]' \
    '--debug[Debug output]' \
    '--max-errors[Limit diagnostics]:number:' \
    '--root[Set project root]:directory:_directories' \
    '(-V --version)'{-V,--version}'[Display version]' \
    '(-h --help)'{-h,--help}'[Display help]' \
    '1:command:->command' \
    '*::argument:->args'

  case $state in
    command)
      _describe 'vfconf command' commands
      ;;

    args)
      case $words[2] in
        completion)
          _values 'shell' bash zsh fish
          ;;
        fmt)
          _arguments \
            '--write[Format file in place]' \
            '--check[Check canonical formatting]' \
            '--stdout[Format to stdout]' \
            '--diff[Display formatting differences]' \
            '*:file:_files -g "*.vf.conf"'
          ;;
        schema)
          _values 'schema command' check validate fields rules infer
          ;;
        include)
          _values 'include command' list tree check resolve
          ;;
        ref)
          _values 'reference command' list check resolve graph
          ;;
        language)
          _values 'language command' list show check detect
          ;;
        theme)
          _values 'theme command' list show check
          ;;
        check|parse|dump|ast|tokens|diagnostics|stats)
          _files -g '*.vf.conf'
          ;;
      esac
      ;;
  esac
}

_vfconf "$@"
|}

let generate_fish_completion () =
  print_string
{|complete -c vfconf -f

complete -c vfconf -l color -x -a "auto always never" -d "Color mode"
complete -c vfconf -l output -x -a "human json" -d "Output format"
complete -c vfconf -l strict -d "Enable strict validation"
complete -c vfconf -l quiet -d "Suppress normal output"
complete -c vfconf -l verbose -d "Verbose output"
complete -c vfconf -l debug -d "Debug output"
complete -c vfconf -l max-errors -x -d "Limit diagnostics"
complete -c vfconf -l root -r -d "Set project root"
complete -c vfconf -s V -l version -d "Display version"
complete -c vfconf -s h -l help -d "Display help"

complete -c vfconf -n "__fish_use_subcommand" -a check -d "Parse and validate a file"
complete -c vfconf -n "__fish_use_subcommand" -a check-all -d "Validate files recursively"
complete -c vfconf -n "__fish_use_subcommand" -a parse -d "Parse a file"
complete -c vfconf -n "__fish_use_subcommand" -a dump -d "Dump parsed configuration"
complete -c vfconf -n "__fish_use_subcommand" -a ast -d "Display AST"
complete -c vfconf -n "__fish_use_subcommand" -a tokens -d "Display lexer tokens"
complete -c vfconf -n "__fish_use_subcommand" -a diagnostics -d "Display diagnostics"
complete -c vfconf -n "__fish_use_subcommand" -a explain -d "Explain diagnostic code"
complete -c vfconf -n "__fish_use_subcommand" -a stats -d "Display statistics"
complete -c vfconf -n "__fish_use_subcommand" -a fmt -d "Format VFConf source"
complete -c vfconf -n "__fish_use_subcommand" -a fmt-all -d "Format recursively"
complete -c vfconf -n "__fish_use_subcommand" -a get -d "Read a value"
complete -c vfconf -n "__fish_use_subcommand" -a set -d "Set a value"
complete -c vfconf -n "__fish_use_subcommand" -a unset -d "Remove a value"
complete -c vfconf -n "__fish_use_subcommand" -a exists -d "Test whether a path exists"
complete -c vfconf -n "__fish_use_subcommand" -a list -d "List configuration paths"
complete -c vfconf -n "__fish_use_subcommand" -a tree -d "Display configuration tree"
complete -c vfconf -n "__fish_use_subcommand" -a diff -d "Compare configurations"
complete -c vfconf -n "__fish_use_subcommand" -a merge -d "Merge configurations"
complete -c vfconf -n "__fish_use_subcommand" -a resolve -d "Resolve configuration"
complete -c vfconf -n "__fish_use_subcommand" -a eval -d "Evaluate a value"
complete -c vfconf -n "__fish_use_subcommand" -a query -d "Query configuration"
complete -c vfconf -n "__fish_use_subcommand" -a schema -d "Schema operations"
complete -c vfconf -n "__fish_use_subcommand" -a include -d "Include operations"
complete -c vfconf -n "__fish_use_subcommand" -a ref -d "Reference operations"
complete -c vfconf -n "__fish_use_subcommand" -a init -d "Create configuration"
complete -c vfconf -n "__fish_use_subcommand" -a new -d "Create project"
complete -c vfconf -n "__fish_use_subcommand" -a doctor -d "Check installation or project"
complete -c vfconf -n "__fish_use_subcommand" -a info -d "Display project information"
complete -c vfconf -n "__fish_use_subcommand" -a files -d "List project files"
complete -c vfconf -n "__fish_use_subcommand" -a clean -d "Clean generated artifacts"
complete -c vfconf -n "__fish_use_subcommand" -a language -d "Language operations"
complete -c vfconf -n "__fish_use_subcommand" -a theme -d "Theme operations"
complete -c vfconf -n "__fish_use_subcommand" -a completion -d "Generate shell completion"
complete -c vfconf -n "__fish_use_subcommand" -a version -d "Display version"
complete -c vfconf -n "__fish_use_subcommand" -a help -d "Display help"

complete -c vfconf -n "__fish_seen_subcommand_from completion" -a "bash zsh fish"

complete -c vfconf -n "__fish_seen_subcommand_from fmt" -l write -d "Format file in place"
complete -c vfconf -n "__fish_seen_subcommand_from fmt" -l check -d "Check canonical formatting"
complete -c vfconf -n "__fish_seen_subcommand_from fmt" -l stdout -d "Format to stdout"
complete -c vfconf -n "__fish_seen_subcommand_from fmt" -l diff -d "Display formatting differences"

complete -c vfconf -n "__fish_seen_subcommand_from schema" -a "check validate fields rules infer"
complete -c vfconf -n "__fish_seen_subcommand_from include" -a "list tree check resolve"
complete -c vfconf -n "__fish_seen_subcommand_from ref" -a "list check resolve graph"
complete -c vfconf -n "__fish_seen_subcommand_from language" -a "list show check detect"
complete -c vfconf -n "__fish_seen_subcommand_from theme" -a "list show check"
|}

let run_completion = function
  | ["bash"] ->
      generate_bash_completion ()

  | ["zsh"] ->
      generate_zsh_completion ()

  | ["fish"] ->
      generate_fish_completion ()

  | [] ->
      Printf.eprintf
        "vfconf: completion requires bash, zsh, or fish\n";
      exit 2

  | [shell] ->
      Printf.eprintf
        "vfconf: unsupported completion shell '%s'\n"
        shell;
      exit 2

  | _ ->
      Printf.eprintf
        "vfconf: invalid completion arguments\n";
      exit 2


let arguments () =
  Array.to_list Sys.argv
  |> List.tl

let () =
  let options, command_arguments =
    parse_global_options
      default_global_options
      (arguments ())
  in

  apply_root options;
  debug_global_options options;

  match command_arguments with
  | []
  | ["help"]
  | ["--help"]
  | ["-h"] ->
      usage ()

  | ["version"]
  | ["--version"]
  | ["-V"] ->
      Printf.printf "vfconf %s\n" version

  | "check" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-check"
        arguments

  | "check-all" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-check-all"
        arguments

  | "parse" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-dump"
        ("--parse" :: arguments)

  | "dump" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-dump"
        arguments

  | "ast" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-dump"
        ("--ast" :: arguments)

  | "tokens" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-dump"
        ("--tokens" :: arguments)

  | "diagnostics" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-diagnostics"
        arguments

  | "explain" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-explain"
        arguments

  | "stats" :: arguments ->
      run_external
        ~quiet:options.quiet
        "vfconf-stats"
        arguments

  | "fmt" :: arguments ->
      run_fmt options arguments

  | "fmt-all" :: arguments ->
      run_fmt_all options arguments

  | "get" :: arguments ->
      run_get options arguments

  | "exists" :: arguments ->
      run_exists options arguments

  | "list" :: arguments ->
      run_list options arguments

  | "tree" :: arguments ->
      run_tree options arguments

  | "diff" :: arguments ->
      run_diff options arguments

  | "merge" :: arguments ->
      run_merge options arguments

  | "resolve" :: arguments ->
      run_resolve options arguments

  | "eval" :: arguments ->
      run_eval options arguments

  | "query" :: arguments ->
      run_query options arguments

  | "completion" :: arguments ->
      run_completion arguments

  | command :: _ when is_registered command ->
      unsupported command

  | command :: _ ->
      Printf.eprintf
        "vfconf: unknown command '%s'\n\
         Try 'vfconf --help' for usage.\n"
        command;
      exit 2

