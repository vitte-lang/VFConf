type category =
  | Core
  | Format
  | Config
  | Schema
  | Include
  | Reference
  | Project
  | Registry
  | Tool

type command = {
  name : string;
  category : category;
  description : string;
}

let commands =
  [
    { name = "check";       category = Core;      description = "Parse and validate a VFConf file" };
    { name = "check-all";   category = Core;      description = "Validate VFConf files recursively" };
    { name = "parse";       category = Core;      description = "Parse a VFConf file" };
    { name = "dump";        category = Core;      description = "Dump parsed configuration" };
    { name = "ast";         category = Core;      description = "Display the abstract syntax tree" };
    { name = "tokens";      category = Core;      description = "Display lexer tokens" };
    { name = "diagnostics"; category = Core;      description = "Display detailed diagnostics" };
    { name = "explain";     category = Core;      description = "Explain a VFConf diagnostic code" };
    { name = "stats";       category = Core;      description = "Display configuration statistics" };

    { name = "fmt";         category = Format;    description = "Format VFConf source" };
    { name = "fmt-all";     category = Format;    description = "Format VFConf files recursively" };

    { name = "get";         category = Config;    description = "Read a configuration value" };
    { name = "set";         category = Config;    description = "Set a configuration value" };
    { name = "unset";       category = Config;    description = "Remove a configuration value" };
    { name = "exists";      category = Config;    description = "Test whether a path exists" };
    { name = "list";        category = Config;    description = "List configuration paths" };
    { name = "tree";        category = Config;    description = "Display configuration tree" };
    { name = "merge";       category = Config;    description = "Merge configurations" };
    { name = "diff";        category = Config;    description = "Compare configurations" };
    { name = "resolve";     category = Config;    description = "Resolve includes and references" };
    { name = "eval";        category = Config;    description = "Evaluate a configuration value" };
    { name = "query";       category = Config;    description = "Query configuration" };

    { name = "schema";      category = Schema;    description = "Schema operations" };

    { name = "include";     category = Include;   description = "Include operations" };
    { name = "ref";         category = Reference; description = "Reference operations" };

    { name = "init";        category = Project;   description = "Create a VFConf configuration" };
    { name = "new";         category = Project;   description = "Create a VFConf project" };
    { name = "doctor";      category = Project;   description = "Check VFConf installation and project" };
    { name = "info";        category = Project;   description = "Display project information" };
    { name = "files";       category = Project;   description = "List project VFConf files" };
    { name = "clean";       category = Project;   description = "Clean generated VFConf artifacts" };

    { name = "language";    category = Registry;  description = "Language definition operations" };
    { name = "theme";       category = Registry;  description = "Theme operations" };

    { name = "completion";  category = Tool;      description = "Generate shell completion" };
    { name = "man";         category = Tool;      description = "Display manual information" };
  ]

let category_name = function
  | Core -> "Core"
  | Format -> "Format"
  | Config -> "Configuration"
  | Schema -> "Schema"
  | Include -> "Includes"
  | Reference -> "References"
  | Project -> "Project"
  | Registry -> "Registry"
  | Tool -> "Tools"

let find name =
  List.find_opt
    (fun command -> command.name = name)
    commands
