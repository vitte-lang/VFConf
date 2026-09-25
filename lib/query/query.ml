type component =
  | Exact of string
  | Wildcard
  | Recursive

type t = component list

type error =
  | Empty_query
  | Empty_component

exception Query_error of error

let parse_component = function
  | "*" ->
      Wildcard
  | "**" ->
      Recursive
  | value ->
      Exact value

let parse source =
  if String.equal source "" then
    raise (Query_error Empty_query);

  let parts =
    String.split_on_char '.' source
  in

  if List.exists (String.equal "") parts then
    raise (Query_error Empty_component);

  List.map parse_component parts

let rec matches query path =
  match query, path with
  | [], [] ->
      true

  | [], _ ->
      false

  | Recursive :: rest, [] ->
      matches rest []

  | Recursive :: rest, (_ :: path_rest as path) ->
      matches rest path
      || matches query path_rest

  | Wildcard :: query_rest, _ :: path_rest ->
      matches query_rest path_rest

  | Exact expected :: query_rest, actual :: path_rest ->
      String.equal expected actual
      && matches query_rest path_rest

  | _ ->
      false

let select query config =
  Config.entries config
  |> List.filter
       (fun entry ->
         matches query entry.Config.path)
  |> List.sort
       (fun left right ->
         String.compare
           (Config.string_of_path left.Config.path)
           (Config.string_of_path right.Config.path))

let execute source config =
  select (parse source) config

let string_of_error = function
  | Empty_query ->
      "query must not be empty"

  | Empty_component ->
      "query contains an empty path component"
