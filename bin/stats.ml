(*
 * VFConf - Vitte Foundation Configuration Language
 * bin/stats.ml
 *
 * Structural statistics for VFConf documents.
 *)

type stats = {
  statements : int;
  sections : int;
  assignments : int;
  includes : int;
  defines : int;
  conditionals : int;
  references : int;
}

let empty_stats =
  {
    statements = 0;
    sections = 0;
    assignments = 0;
    includes = 0;
    defines = 0;
    conditionals = 0;
    references = 0;
  }

let rec count_value_references value =
  match value.Vfconf.Node.value with
  | Vfconf.Value.Reference _ ->
      1

  | Vfconf.Value.Array values ->
      List.fold_left
        (fun count value ->
          count + count_value_references value)
        0
        values

  | Vfconf.Value.Object entries ->
      List.fold_left
        (fun count entry ->
          count
          + count_value_references
              entry.Vfconf.Value.value)
        0
        entries

  | Vfconf.Value.String _
  | Vfconf.Value.Integer _
  | Vfconf.Value.Float _
  | Vfconf.Value.Boolean _
  | Vfconf.Value.Null
  | Vfconf.Value.Color _
  | Vfconf.Value.Duration _
  | Vfconf.Value.Size _ ->
      0

let rec count_condition_references condition =
  match condition.Vfconf.Node.value with
  | Vfconf.Statement.Reference _ ->
      1

  | Vfconf.Statement.Boolean _ ->
      0

  | Vfconf.Statement.Not condition ->
      count_condition_references condition

  | Vfconf.Statement.Logical { left; right; _ } ->
      count_condition_references left
      + count_condition_references right

  | Vfconf.Statement.Compare { value; _ } ->
      1 + count_value_references value

let add_statement stats statement =
  let stats =
    {
      stats with
      statements = stats.statements + 1;
    }
  in

  match statement.Vfconf.Node.value with
  | Vfconf.Statement.Assignment assignment ->
      {
        stats with
        assignments = stats.assignments + 1;
        references =
          stats.references
          + count_value_references assignment.value;
      }

  | Vfconf.Statement.Include _ ->
      {
        stats with
        includes = stats.includes + 1;
      }

  | Vfconf.Statement.Define definition ->
      {
        stats with
        defines = stats.defines + 1;
        references =
          stats.references
          + count_value_references definition.value;
      }

  | Vfconf.Statement.Section _ ->
      {
        stats with
        sections = stats.sections + 1;
      }

  | Vfconf.Statement.Conditional conditional ->
      {
        stats with
        conditionals = stats.conditionals + 1;
        references =
          stats.references
          + count_condition_references
              conditional.condition;
      }

let collect statements =
  List.fold_left
    (fun stats statement ->
      Vfconf.Statement.fold
        add_statement
        stats
        statement)
    empty_stats
    statements

let read_file filename =
  try
    let channel = open_in_bin filename in
    Fun.protect
      ~finally:(fun () -> close_in_noerr channel)
      (fun () ->
        really_input_string
          channel
          (in_channel_length channel))
  with
  | Sys_error message ->
      Printf.eprintf "vfconf-stats: %s\n" message;
      exit 3

let run filename =
  let source = read_file filename in

  match Vfconf.Parse.string_result ~filename source with
  | Error error ->
      Format.eprintf
        "%a@."
        Vfconf.Diagnostic.pp
        (Vfconf.Parse.diagnostic_of_error error);
      exit 1

  | Ok document ->
      let stats =
        collect document
      in

      Printf.printf
        "VFConf statistics\n\
         File: %s\n\
         \n\
         Statements:   %d\n\
         Sections:     %d\n\
         Assignments:  %d\n\
         Includes:     %d\n\
         Defines:      %d\n\
         Conditionals: %d\n\
         References:   %d\n"
        filename
        stats.statements
        stats.sections
        stats.assignments
        stats.includes
        stats.defines
        stats.conditionals
        stats.references

let main () =
  match Array.to_list Sys.argv with
  | [_; "-h"]
  | [_; "--help"] ->
      print_string
        "Usage: vfconf-stats FILE.vf.conf\n"

  | [_; filename] ->
      run filename

  | [_] ->
      Printf.eprintf "vfconf-stats: missing input file\n";
      exit 2

  | _ ->
      Printf.eprintf "vfconf-stats: invalid arguments\n";
      exit 2

let () =
  main ()
