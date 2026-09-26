let comments source =
  let length = String.length source in
  let substring start finish = String.sub source start (finish - start) in
  let rec quoted index escaped accumulator =
    if index >= length then List.rev accumulator
    else if escaped then quoted (index + 1) false accumulator
    else
      match source.[index] with
      | '\\' -> quoted (index + 1) true accumulator
      | '"' -> code (index + 1) accumulator
      | _ -> quoted (index + 1) false accumulator
  and line_comment start index accumulator =
    if index >= length || source.[index] = '\n' || source.[index] = '\r' then
      code index (substring start index :: accumulator)
    else
      line_comment start (index + 1) accumulator
  and block_comment start index depth accumulator =
    if index >= length then
      List.rev (substring start length :: accumulator)
    else if index + 1 < length && source.[index] = '/' && source.[index + 1] = '*' then
      block_comment start (index + 2) (depth + 1) accumulator
    else if index + 1 < length && source.[index] = '*' && source.[index + 1] = '/' then
      if depth = 1 then
        code (index + 2) (substring start (index + 2) :: accumulator)
      else
        block_comment start (index + 2) (depth - 1) accumulator
    else
      block_comment start (index + 1) depth accumulator
  and code index accumulator =
    if index >= length then List.rev accumulator
    else
      match source.[index] with
      | '"' -> quoted (index + 1) false accumulator
      | '/' when index + 1 < length && source.[index + 1] = '/' ->
          line_comment index (index + 2) accumulator
      | '/' when index + 1 < length && source.[index + 1] = '*' ->
          block_comment index (index + 2) 1 accumulator
      | '#' ->
          let hash_comment =
            index + 1 = length
            || source.[index + 1] = ' '
            || source.[index + 1] = '\t'
            || source.[index + 1] = '\n'
            || source.[index + 1] = '\r'
          in
          if hash_comment then line_comment index (index + 1) accumulator
          else code (index + 1) accumulator
      | _ -> code (index + 1) accumulator
  in
  code 0 []

let format_source
    ?options
    ?(filename = "<memory>")
    source =
  match Parse.string_result ~filename source with
  | Error error ->
      Error [Parse.diagnostic_of_error error]
  | Ok document ->
      let formatted = Formatter.format ?options document in
      let preserved = comments source in
      let output =
        match preserved, formatted with
        | [], _ -> formatted
        | comments, "" -> String.concat "\n" comments ^ "\n"
        | comments, formatted -> String.concat "\n" comments ^ "\n\n" ^ formatted
      in
      Ok output
