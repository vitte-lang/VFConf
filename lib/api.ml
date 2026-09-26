type document = Statement.t Node.t list
type 'a outcome = ('a, Diagnostic.t list) result

let parse ?(filename = "<memory>") source =
  match Parse.string_result ~filename source with
  | Ok document -> Ok document
  | Error error -> Error [Parse.diagnostic_of_error error]

let validate document =
  let validation = Validator.validate document in
  let diagnostics =
    Validator.diagnostics validation
    |> Validator.unique_diagnostics
    |> Diagnostic.sort
  in
  if Diagnostic.has_errors diagnostics then Error diagnostics
  else Ok validation

let check ?filename source =
  match parse ?filename source with
  | Error diagnostics -> Error diagnostics
  | Ok document ->
      begin
        match validate document with
        | Ok _ -> Ok document
        | Error diagnostics -> Error diagnostics
      end

let format ?options ?filename source =
  Source_formatter.format_source ?options ?filename source

let load ?security_root ?allow_symlinks ?maximum_include_depth filename =
  try
    Ok
      (Loader.load_file
         ?security_root
         ?allow_symlinks
         ?maximum_include_depth
         filename)
  with
  | Loader.Load_error error -> Error [Loader.diagnostic_of_error error]
