(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/value.ml
 *
 * Canonical value representation and helpers.
 *)

type path = string list
type reference = path

(* ---------------------------------------------------------- *)
(* Units                                                      *)
(* ---------------------------------------------------------- *)

type duration_unit =
  | Nanosecond
  | Microsecond
  | Millisecond
  | Second
  | Minute
  | Hour

type size_unit =
  | Byte
  | Kilobyte
  | Megabyte
  | Gigabyte
  | Kibibyte
  | Mebibyte
  | Gibibyte

(* ---------------------------------------------------------- *)
(* Colors                                                     *)
(* ---------------------------------------------------------- *)

type color =
  | Hex of string
  | Rgb of {
      red : int;
      green : int;
      blue : int;
    }
  | Rgba of {
      red : int;
      green : int;
      blue : int;
      alpha : float;
    }

(* ---------------------------------------------------------- *)
(* Values                                                     *)
(* ---------------------------------------------------------- *)

type t =
  | String of string
  | Integer of int64
  | Float of float
  | Boolean of bool
  | Null
  | Array of t Node.t list
  | Object of object_entry list
  | Reference of reference
  | Color of color
  | Duration of float * duration_unit
  | Size of float * size_unit

and object_entry = {
  key : path;
  value : t Node.t;
  span : Node.span;
}

(* ---------------------------------------------------------- *)
(* Constructors                                               *)
(* ---------------------------------------------------------- *)

let string value =
  String value

let integer value =
  Integer value

let int value =
  Integer (Int64.of_int value)

let float value =
  Float value

let boolean value =
  Boolean value

let true_ =
  Boolean true

let false_ =
  Boolean false

let null =
  Null

let array values =
  Array values

let object_ entries =
  Object entries

let reference path =
  Reference path

let hex value =
  Hex value

let rgb red green blue =
  Rgb
    {
      red;
      green;
      blue;
    }

let rgba red green blue alpha =
  Rgba
    {
      red;
      green;
      blue;
      alpha;
    }

let color value =
  Color value

let duration value unit =
  Duration (value, unit)

let size value unit =
  Size (value, unit)

let object_entry
    ?(span = Node.dummy_span)
    key
    value =
  {
    key;
    value;
    span;
  }

(* ---------------------------------------------------------- *)
(* Located constructors                                       *)
(* ---------------------------------------------------------- *)

let located span value =
  Node.located span value

let located_string span value =
  Node.located span (String value)

let located_integer span value =
  Node.located span (Integer value)

let located_float span value =
  Node.located span (Float value)

let located_boolean span value =
  Node.located span (Boolean value)

let located_null span =
  Node.located span Null

let located_array span values =
  Node.located span (Array values)

let located_object span entries =
  Node.located span (Object entries)

let located_reference span path =
  Node.located span (Reference path)

let located_color span value =
  Node.located span (Color value)

let located_duration span value unit =
  Node.located span (Duration (value, unit))

let located_size span value unit =
  Node.located span (Size (value, unit))

(* ---------------------------------------------------------- *)
(* Predicates                                                 *)
(* ---------------------------------------------------------- *)

let is_string = function
  | String _ -> true
  | _ -> false

let is_integer = function
  | Integer _ -> true
  | _ -> false

let is_float = function
  | Float _ -> true
  | _ -> false

let is_number = function
  | Integer _
  | Float _ ->
      true
  | _ ->
      false

let is_boolean = function
  | Boolean _ -> true
  | _ -> false

let is_null = function
  | Null -> true
  | _ -> false

let is_array = function
  | Array _ -> true
  | _ -> false

let is_object = function
  | Object _ -> true
  | _ -> false

let is_reference = function
  | Reference _ -> true
  | _ -> false

let is_color = function
  | Color _ -> true
  | _ -> false

let is_duration = function
  | Duration _ -> true
  | _ -> false

let is_size = function
  | Size _ -> true
  | _ -> false

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

let as_string = function
  | String value ->
      Some value
  | _ ->
      None

let as_integer = function
  | Integer value ->
      Some value
  | _ ->
      None

let as_float = function
  | Float value ->
      Some value
  | Integer value ->
      Some (Int64.to_float value)
  | _ ->
      None

let as_boolean = function
  | Boolean value ->
      Some value
  | _ ->
      None

let as_array = function
  | Array values ->
      Some values
  | _ ->
      None

let as_object = function
  | Object entries ->
      Some entries
  | _ ->
      None

let as_reference = function
  | Reference path ->
      Some path
  | _ ->
      None

let as_color = function
  | Color color ->
      Some color
  | _ ->
      None

let as_duration = function
  | Duration (value, unit) ->
      Some (value, unit)
  | _ ->
      None

let as_size = function
  | Size (value, unit) ->
      Some (value, unit)
  | _ ->
      None

(* ---------------------------------------------------------- *)
(* Unit conversion                                            *)
(* ---------------------------------------------------------- *)

let string_of_duration_unit = function
  | Nanosecond -> "ns"
  | Microsecond -> "us"
  | Millisecond -> "ms"
  | Second -> "s"
  | Minute -> "min"
  | Hour -> "h"

let string_of_size_unit = function
  | Byte -> "B"
  | Kilobyte -> "KB"
  | Megabyte -> "MB"
  | Gigabyte -> "GB"
  | Kibibyte -> "KiB"
  | Mebibyte -> "MiB"
  | Gibibyte -> "GiB"

let duration_multiplier = function
  | Nanosecond -> 0.000000001
  | Microsecond -> 0.000001
  | Millisecond -> 0.001
  | Second -> 1.0
  | Minute -> 60.0
  | Hour -> 3600.0

let duration_to_seconds value unit =
  value *. duration_multiplier unit

let size_multiplier = function
  | Byte -> 1.
  | Kilobyte -> 1_000.
  | Megabyte -> 1_000_000.
  | Gigabyte -> 1_000_000_000.
  | Kibibyte -> 1_024.
  | Mebibyte -> 1_048_576.
  | Gibibyte -> 1_073_741_824.

let size_to_bytes value unit =
  value *. size_multiplier unit

(* ---------------------------------------------------------- *)
(* Path helpers                                               *)
(* ---------------------------------------------------------- *)

let string_of_path path =
  String.concat "." path

(* ---------------------------------------------------------- *)
(* Color validation                                           *)
(* ---------------------------------------------------------- *)

let valid_rgb_component value =
  value >= 0 && value <= 255

let valid_alpha value =
  value >= 0.0 && value <= 1.0

let is_hex_digit = function
  | '0' .. '9'
  | 'a' .. 'f'
  | 'A' .. 'F' ->
      true
  | _ ->
      false

let valid_hex value =
  let length = String.length value in

  (length = 3
   || length = 4
   || length = 6
   || length = 8)
  &&
  let rec loop index =
    index = length
    ||
    (is_hex_digit value.[index]
     && loop (index + 1))
  in
  loop 0

let valid_color = function
  | Hex value ->
      valid_hex value

  | Rgb { red; green; blue } ->
      valid_rgb_component red
      && valid_rgb_component green
      && valid_rgb_component blue

  | Rgba { red; green; blue; alpha } ->
      valid_rgb_component red
      && valid_rgb_component green
      && valid_rgb_component blue
      && valid_alpha alpha

(* ---------------------------------------------------------- *)
(* Equality                                                   *)
(* ---------------------------------------------------------- *)

let equal_duration_unit left right =
  left = right

let equal_size_unit left right =
  left = right

let equal_color left right =
  left = right

let rec equal left right =
  match left, right with
  | String left, String right ->
      String.equal left right

  | Integer left, Integer right ->
      Int64.equal left right

  | Float left, Float right ->
      Float.equal left right

  | Boolean left, Boolean right ->
      Bool.equal left right

  | Null, Null ->
      true

  | Reference left, Reference right ->
      left = right

  | Color left, Color right ->
      equal_color left right

  | Duration (left_value, left_unit),
    Duration (right_value, right_unit) ->
      Float.equal left_value right_value
      && equal_duration_unit left_unit right_unit

  | Size (left_value, left_unit),
    Size (right_value, right_unit) ->
      Float.equal left_value right_value
      && equal_size_unit left_unit right_unit

  | Array left, Array right ->
      List.length left = List.length right
      &&
      List.for_all2
        (fun left right ->
          equal left.Node.value right.Node.value)
        left
        right

  | Object left, Object right ->
      List.length left = List.length right
      &&
      List.for_all2
        (fun left right ->
          left.key = right.key
          && equal
               left.value.Node.value
               right.value.Node.value)
        left
        right

  | _ ->
      false

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

let pp_path formatter path =
  Format.pp_print_string
    formatter
    (string_of_path path)

let pp_color formatter = function
  | Hex value ->
      Format.fprintf
        formatter
        "#%s"
        value

  | Rgb { red; green; blue } ->
      Format.fprintf
        formatter
        "rgb(%d, %d, %d)"
        red
        green
        blue

  | Rgba { red; green; blue; alpha } ->
      Format.fprintf
        formatter
        "rgba(%d, %d, %d, %g)"
        red
        green
        blue
        alpha

let escape_string value =
  String.escaped value

let rec pp formatter = function
  | String value ->
      Format.fprintf
        formatter
        "\"%s\""
        (escape_string value)

  | Integer value ->
      Format.fprintf
        formatter
        "%Ld"
        value

  | Float value ->
      Format.fprintf
        formatter
        "%g"
        value

  | Boolean value ->
      Format.pp_print_bool
        formatter
        value

  | Null ->
      Format.pp_print_string
        formatter
        "null"

  | Reference path ->
      Format.fprintf
        formatter
        "$%a"
        pp_path
        path

  | Color color ->
      pp_color formatter color

  | Duration (value, unit) ->
      Format.fprintf
        formatter
        "%g%s"
        value
        (string_of_duration_unit unit)

  | Size (value, unit) ->
      Format.fprintf
        formatter
        "%g%s"
        value
        (string_of_size_unit unit)

  | Array values ->
      Format.fprintf formatter "[";

      List.iteri
        (fun index value ->
          if index > 0 then
            Format.fprintf formatter ", ";

          pp formatter value.Node.value)
        values;

      Format.fprintf formatter "]"

  | Object entries ->
      Format.fprintf formatter "{";

      List.iteri
        (fun index entry ->
          if index > 0 then
            Format.fprintf formatter ", ";

          Format.fprintf
            formatter
            "%a: %a"
            pp_path
            entry.key
            pp
            entry.value.Node.value)
        entries;

      Format.fprintf formatter "}"

let to_string value =
  Format.asprintf "%a" pp value

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

let type_name = function
  | String _ -> "string"
  | Integer _ -> "integer"
  | Float _ -> "float"
  | Boolean _ -> "boolean"
  | Null -> "null"
  | Array _ -> "array"
  | Object _ -> "object"
  | Reference _ -> "reference"
  | Color _ -> "color"
  | Duration _ -> "duration"
  | Size _ -> "size"

let rec dump formatter depth value =
  let indentation =
    String.make (depth * 2) ' '
  in

  Format.pp_print_string
    formatter
    indentation;

  match value with
  | Array values ->
      Format.fprintf formatter "Array@.";

      List.iter
        (fun value ->
          dump
            formatter
            (depth + 1)
            value.Node.value)
        values

  | Object entries ->
      Format.fprintf formatter "Object@.";

      List.iter
        (fun entry ->
          Format.fprintf
            formatter
            "%s  %s:@."
            indentation
            (string_of_path entry.key);

          dump
            formatter
            (depth + 2)
            entry.value.Node.value)
        entries

  | _ ->
      Format.fprintf
        formatter
        "%s(%s)@."
        (type_name value)
        (to_string value)