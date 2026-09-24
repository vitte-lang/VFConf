(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/utils/string_utils.ml
 *
 * General string manipulation utilities.
 *)

(* ---------------------------------------------------------- *)
(* Basic predicates                                           *)
(* ---------------------------------------------------------- *)

let is_empty string =
  String.length string = 0

let is_blank string =
  let rec loop index =
    if index >= String.length string then
      true
    else
      match string.[index] with
      | ' '
      | '\t'
      | '\r'
      | '\n'
      | '\012' ->
          loop (index + 1)

      | _ ->
          false
  in

  loop 0

let equal =
  String.equal

let equal_case_insensitive left right =
  String.equal
    (String.lowercase_ascii left)
    (String.lowercase_ascii right)

(* ---------------------------------------------------------- *)
(* Prefix / suffix                                            *)
(* ---------------------------------------------------------- *)

let starts_with
    ~prefix
    string =
  let prefix_length =
    String.length prefix
  in

  let string_length =
    String.length string
  in

  string_length >= prefix_length
  && String.equal
       (String.sub string 0 prefix_length)
       prefix

let ends_with
    ~suffix
    string =
  let suffix_length =
    String.length suffix
  in

  let string_length =
    String.length string
  in

  string_length >= suffix_length
  && String.equal
       (String.sub
          string
          (string_length - suffix_length)
          suffix_length)
       suffix

let remove_prefix
    ~prefix
    string =
  if starts_with ~prefix string then
    Some
      (String.sub
         string
         (String.length prefix)
         (String.length string - String.length prefix))
  else
    None

let remove_suffix
    ~suffix
    string =
  if ends_with ~suffix string then
    Some
      (String.sub
         string
         0
         (String.length string - String.length suffix))
  else
    None

let strip_prefix
    ~prefix
    string =
  match remove_prefix ~prefix string with
  | Some result ->
      result

  | None ->
      string

let strip_suffix
    ~suffix
    string =
  match remove_suffix ~suffix string with
  | Some result ->
      result

  | None ->
      string

(* ---------------------------------------------------------- *)
(* Whitespace                                                 *)
(* ---------------------------------------------------------- *)

let is_whitespace = function
  | ' '
  | '\t'
  | '\r'
  | '\n'
  | '\012' ->
      true

  | _ ->
      false

let trim_left string =
  let length =
    String.length string
  in

  let rec find index =
    if index >= length then
      length
    else if is_whitespace string.[index] then
      find (index + 1)
    else
      index
  in

  let start =
    find 0
  in

  if start = 0 then
    string
  else if start = length then
    ""
  else
    String.sub
      string
      start
      (length - start)

let trim_right string =
  let length =
    String.length string
  in

  let rec find index =
    if index < 0 then
      -1
    else if is_whitespace string.[index] then
      find (index - 1)
    else
      index
  in

  let finish =
    find (length - 1)
  in

  if finish = length - 1 then
    string
  else if finish < 0 then
    ""
  else
    String.sub
      string
      0
      (finish + 1)

let trim string =
  string
  |> trim_left
  |> trim_right

(* ---------------------------------------------------------- *)
(* Splitting                                                  *)
(* ---------------------------------------------------------- *)

let split_on_char
    separator
    string =
  String.split_on_char
    separator
    string

let split
    ~separator
    string =
  if String.equal separator "" then
    invalid_arg
      "String_utils.split: separator cannot be empty";

  let separator_length =
    String.length separator
  in

  let string_length =
    String.length string
  in

  let rec matches index offset =
    if offset = separator_length then
      true
    else if index + offset >= string_length then
      false
    else if string.[index + offset] <> separator.[offset] then
      false
    else
      matches index (offset + 1)
  in

  let rec search index start accumulator =
    if index > string_length - separator_length then
      let part =
        String.sub
          string
          start
          (string_length - start)
      in

      List.rev
        (part :: accumulator)
    else if matches index 0 then
      let part =
        String.sub
          string
          start
          (index - start)
      in

      search
        (index + separator_length)
        (index + separator_length)
        (part :: accumulator)
    else
      search
        (index + 1)
        start
        accumulator
  in

  if string_length = 0 then
    [""]
  else if separator_length > string_length then
    [string]
  else
    search 0 0 []

let split_lines string =
  let length =
    String.length string
  in

  let rec loop start index accumulator =
    if index >= length then
      let line =
        String.sub
          string
          start
          (length - start)
      in

      List.rev
        (line :: accumulator)
    else
      match string.[index] with
      | '\r'
        when index + 1 < length
             && string.[index + 1] = '\n' ->
          let line =
            String.sub
              string
              start
              (index - start)
          in

          loop
            (index + 2)
            (index + 2)
            (line :: accumulator)

      | '\r'
      | '\n' ->
          let line =
            String.sub
              string
              start
              (index - start)
          in

          loop
            (index + 1)
            (index + 1)
            (line :: accumulator)

      | _ ->
          loop
            start
            (index + 1)
            accumulator
  in

  if length = 0 then
    [""]
  else
    loop 0 0 []

let words string =
  let length =
    String.length string
  in

  let rec skip index =
    if index < length && is_whitespace string.[index] then
      skip (index + 1)
    else
      index
  in

  let rec finish index =
    if index < length && not (is_whitespace string.[index]) then
      finish (index + 1)
    else
      index
  in

  let rec loop index accumulator =
    let start =
      skip index
    in

    if start >= length then
      List.rev accumulator
    else
      let stop =
        finish start
      in

      let word =
        String.sub
          string
          start
          (stop - start)
      in

      loop
        stop
        (word :: accumulator)
  in

  loop 0 []

(* ---------------------------------------------------------- *)
(* Joining                                                    *)
(* ---------------------------------------------------------- *)

let join
    ~separator
    strings =
  String.concat
    separator
    strings

let join_lines strings =
  String.concat
    "\n"
    strings

(* ---------------------------------------------------------- *)
(* Search                                                     *)
(* ---------------------------------------------------------- *)

let contains_char character string =
  String.contains
    string
    character

let index_opt character string =
  String.index_opt
    string
    character

let rindex_opt character string =
  String.rindex_opt
    string
    character

let contains
    ~substring
    string =
  let substring_length =
    String.length substring
  in

  let string_length =
    String.length string
  in

  if substring_length = 0 then
    true
  else if substring_length > string_length then
    false
  else
    let rec matches index offset =
      if offset = substring_length then
        true
      else if string.[index + offset] <> substring.[offset] then
        false
      else
        matches index (offset + 1)
    in

    let rec search index =
      if index > string_length - substring_length then
        false
      else if matches index 0 then
        true
      else
        search (index + 1)
    in

    search 0

let count_char character string =
  let count =
    ref 0
  in

  String.iter
    (fun current ->
      if current = character then
        incr count)
    string;

  !count

(* ---------------------------------------------------------- *)
(* Replacement                                                *)
(* ---------------------------------------------------------- *)

let replace_char
    ~target
    ~replacement
    string =
  String.map
    (fun character ->
      if character = target then
        replacement
      else
        character)
    string

let replace_all
    ~substring
    ~replacement
    string =
  if String.equal substring "" then
    invalid_arg
      "String_utils.replace_all: substring cannot be empty";

  split
    ~separator:substring
    string
  |> String.concat replacement

(* ---------------------------------------------------------- *)
(* Repetition / padding                                       *)
(* ---------------------------------------------------------- *)

let repeat count string =
  if count < 0 then
    invalid_arg
      "String_utils.repeat: count must be non-negative";

  if count = 0 || String.equal string "" then
    ""
  else
    let buffer =
      Buffer.create
        (count * String.length string)
    in

    for _ = 1 to count do
      Buffer.add_string
        buffer
        string
    done;

    Buffer.contents buffer

let pad_left
    ~length
    ~character
    string =
  let current =
    String.length string
  in

  if current >= length then
    string
  else
    String.make
      (length - current)
      character
    ^ string

let pad_right
    ~length
    ~character
    string =
  let current =
    String.length string
  in

  if current >= length then
    string
  else
    string
    ^ String.make
        (length - current)
        character

(* ---------------------------------------------------------- *)
(* Case conversion                                            *)
(* ---------------------------------------------------------- *)

let lowercase =
  String.lowercase_ascii

let uppercase =
  String.uppercase_ascii

let capitalize string =
  if String.equal string "" then
    ""
  else
    String.capitalize_ascii string

let uncapitalize string =
  if String.equal string "" then
    ""
  else
    String.uncapitalize_ascii string

(* ---------------------------------------------------------- *)
(* Identifier helpers                                         *)
(* ---------------------------------------------------------- *)

let is_ascii_letter = function
  | 'a' .. 'z'
  | 'A' .. 'Z' ->
      true

  | _ ->
      false

let is_ascii_digit = function
  | '0' .. '9' ->
      true

  | _ ->
      false

let is_identifier_start character =
  is_ascii_letter character
  || character = '_'

let is_identifier_continue character =
  is_identifier_start character
  || is_ascii_digit character
  || character = '-'

let is_identifier string =
  let length =
    String.length string
  in

  if length = 0 then
    false
  else if not (is_identifier_start string.[0]) then
    false
  else
    let rec loop index =
      if index >= length then
        true
      else if is_identifier_continue string.[index] then
        loop (index + 1)
      else
        false
    in

    loop 1

(* ---------------------------------------------------------- *)
(* Escaping                                                   *)
(* ---------------------------------------------------------- *)

let escape string =
  let buffer =
    Buffer.create
      (String.length string)
  in

  String.iter
    (function
      | '"' ->
          Buffer.add_string buffer "\\\""

      | '\\' ->
          Buffer.add_string buffer "\\\\"

      | '\n' ->
          Buffer.add_string buffer "\\n"

      | '\r' ->
          Buffer.add_string buffer "\\r"

      | '\t' ->
          Buffer.add_string buffer "\\t"

      | '\b' ->
          Buffer.add_string buffer "\\b"

      | '\012' ->
          Buffer.add_string buffer "\\f"

      | character ->
          Buffer.add_char buffer character)
    string;

  Buffer.contents buffer

let quote string =
  "\""
  ^ escape string
  ^ "\""

(* ---------------------------------------------------------- *)
(* Numeric parsing                                            *)
(* ---------------------------------------------------------- *)

let int_opt string =
  try
    Some (int_of_string string)
  with
  | Failure _ ->
      None

let int64_opt string =
  try
    Some (Int64.of_string string)
  with
  | Failure _ ->
      None

let float_opt string =
  try
    Some (float_of_string string)
  with
  | Failure _ ->
      None

(* ---------------------------------------------------------- *)
(* Miscellaneous                                              *)
(* ---------------------------------------------------------- *)

let non_empty string =
  if String.equal string "" then
    None
  else
    Some string

let default
    fallback = function
  | Some string ->
      string

  | None ->
      fallback

let map_non_empty function_ string =
  string
  |> function_
  |> non_empty

let compare =
  String.compare

let pp formatter string =
  Format.pp_print_string
    formatter
    string

let pp_quoted formatter string =
  Format.pp_print_string
    formatter
    (quote string)