type family =
  | Lexical
  | Syntax
  | Semantic
  | Reference
  | Include
  | Schema
  | Evaluation
  | Configuration
  | Style
  | Compatibility
  | Io
  | Internal

type entry = {
  code : string;
  family : family;
  title : string;
  description : string;
}

let string_of_family = function
  | Lexical -> "lexical"
  | Syntax -> "syntax"
  | Semantic -> "semantic"
  | Reference -> "reference"
  | Include -> "include"
  | Schema -> "schema"
  | Evaluation -> "evaluation"
  | Configuration -> "configuration"
  | Style -> "style"
  | Compatibility -> "compatibility"
  | Io -> "io"
  | Internal -> "internal"

let entries =
  [
    {
      code = "VF0001";
      family = Lexical;
      title = "Unexpected character";
      description =
        "The lexer encountered a character that is not valid in this context.";
    };

    {
      code = "VF0002";
      family = Lexical;
      title = "Invalid token";
      description =
        "The lexer could not construct a valid VFConf token.";
    };

    {
      code = "VF0003";
      family = Lexical;
      title = "Unterminated string";
      description =
        "A string literal reached the end of its input without a closing delimiter.";
    };

    {
      code = "VF0004";
      family = Lexical;
      title = "Unterminated comment";
      description =
        "A block comment was not terminated.";
    };

    {
      code = "VF0005";
      family = Lexical;
      title = "Invalid escape";
      description =
        "A string contains an invalid escape sequence.";
    };

    {
      code = "VF0006";
      family = Lexical;
      title = "Invalid number";
      description =
        "A numeric literal is malformed or cannot be represented.";
    };

    {
      code = "VF0007";
      family = Lexical;
      title = "Invalid color";
      description =
        "A color literal is malformed.";
    };

    {
      code = "VF0008";
      family = Lexical;
      title = "Invalid duration";
      description =
        "A duration literal is malformed.";
    };

    {
      code = "VF0009";
      family = Lexical;
      title = "Invalid size";
      description =
        "A size literal is malformed.";
    };

    {
      code = "VF0101";
      family = Syntax;
      title = "Unexpected token";
      description =
        "The parser encountered a token that is not valid at this position.";
    };

    {
      code = "VF0102";
      family = Syntax;
      title = "Expected token";
      description =
        "The parser expected another token.";
    };

    {
      code = "VF0103";
      family = Syntax;
      title = "Unexpected end of file";
      description =
        "The parser reached the end of the source before the construct was complete.";
    };

    {
      code = "VF0201";
      family = Semantic;
      title = "Duplicate configuration key";
      description =
        "A configuration key is declared more than once in the same resolved path.";
    };

    {
      code = "VF0202";
      family = Reference;
      title = "Undefined reference";
      description =
        "A reference points to a definition or configuration path that does not exist.";
    };

    {
      code = "VF0203";
      family = Reference;
      title = "Invalid reference";
      description =
        "A reference is not valid in this semantic context.";
    };

    {
      code = "VF0204";
      family = Semantic;
      title = "Type mismatch";
      description =
        "A value does not have the type required by its context.";
    };

    {
      code = "VF0205";
      family = Semantic;
      title = "Invalid assignment";
      description =
        "The assignment operator cannot be applied to this configuration key.";
    };

    {
      code = "VF0206";
      family = Semantic;
      title = "Invalid value";
      description =
        "The value is not valid in this semantic context.";
    };

    {
      code = "VF0207";
      family = Semantic;
      title = "Invalid condition";
      description =
        "A conditional expression is semantically invalid.";
    };

    {
      code = "VF0401";
      family = Include;
      title = "Include not found";
      description =
        "An included VFConf source file could not be found.";
    };

    {
      code = "VF0402";
      family = Include;
      title = "Include cycle";
      description =
        "The include graph contains a cycle.";
    };

    {
      code = "VF0403";
      family = Include;
      title = "Include depth exceeded";
      description =
        "The configured maximum include depth was exceeded.";
    };

    {
      code = "VF0404";
      family = Include;
      title = "Invalid include";
      description =
        "An include directive cannot be processed.";
    };

    {
      code = "VF0501";
      family = Schema;
      title = "Schema violation";
      description =
        "The configuration violates a schema rule.";
    };

    {
      code = "VF0502";
      family = Schema;
      title = "Missing required field";
      description =
        "A required schema field is absent.";
    };

    {
      code = "VF0503";
      family = Schema;
      title = "Unknown field";
      description =
        "A field is not recognized by the active schema.";
    };

    {
      code = "VF0601";
      family = Evaluation;
      title = "Evaluation failed";
      description =
        "A VFConf value or expression could not be evaluated.";
    };

    {
      code = "VF0602";
      family = Evaluation;
      title = "Division by zero";
      description =
        "Evaluation attempted to divide by zero.";
    };

    {
      code = "VF9001";
      family = Io;
      title = "File not found";
      description =
        "A required file does not exist.";
    };

    {
      code = "VF9002";
      family = Io;
      title = "Cannot read file";
      description =
        "VFConf could not read a required file.";
    };

    {
      code = "VF9901";
      family = Internal;
      title = "Internal error";
      description =
        "VFConf encountered an internal invariant failure.";
    };
  ]

let find code =
  List.find_opt
    (fun entry ->
      String.equal entry.code code)
    entries

let mem code =
  Option.is_some (find code)

let codes () =
  List.map
    (fun entry -> entry.code)
    entries

let duplicate_codes () =
  let table =
    Hashtbl.create 64
  in

  let duplicates =
    ref []
  in

  List.iter
    (fun entry ->
      if Hashtbl.mem table entry.code then
        duplicates := entry.code :: !duplicates
      else
        Hashtbl.add table entry.code ())
    entries;

  List.sort_uniq
    String.compare
    !duplicates

let validate () =
  let errors =
    ref []
  in

  let duplicates =
    duplicate_codes ()
  in

  List.iter
    (fun code ->
      errors :=
        ("duplicate diagnostic code: " ^ code)
        :: !errors)
    duplicates;

  List.iter
    (fun entry ->
      let valid =
        String.length entry.code = 6
        && String.sub entry.code 0 2 = "VF"
        &&
        let rec digits index =
          if index = String.length entry.code then
            true
          else
            match entry.code.[index] with
            | '0' .. '9' ->
                digits (index + 1)
            | _ ->
                false
        in
        digits 2
      in

      if not valid then
        errors :=
          ("invalid diagnostic code: " ^ entry.code)
          :: !errors)
    entries;

  match List.rev !errors with
  | [] ->
      Ok ()

  | errors ->
      Error errors
