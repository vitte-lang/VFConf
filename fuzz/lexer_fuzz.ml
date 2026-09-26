let () =
  let source = really_input_string stdin (in_channel_length stdin) in
  ignore (Vfconf.Parse.string_result ~filename:"stdin" source)
