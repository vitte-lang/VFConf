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

val commands : command list
val category_name : category -> string
val find : string -> command option
