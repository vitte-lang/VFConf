(*
 * VFConf - Vitte Foundation Configuration Language
 * lib/ast/node.mli
 *
 * Public interface for generic source-located AST nodes.
 *)

(* ---------------------------------------------------------- *)
(* Source position                                            *)
(* ---------------------------------------------------------- *)

type position = {
  offset : int;
  line : int;
  column : int;
}

val position :
  ?offset:int ->
  ?line:int ->
  ?column:int ->
  unit ->
  position

val dummy_position : position

(* ---------------------------------------------------------- *)
(* Source span                                                *)
(* ---------------------------------------------------------- *)

type span = {
  filename : string;
  start_pos : position;
  end_pos : position;
}

val span :
  ?filename:string ->
  position ->
  position ->
  span

val dummy_span : span

(* ---------------------------------------------------------- *)
(* Generic AST node                                           *)
(* ---------------------------------------------------------- *)

type 'a t = {
  value : 'a;
  span : span;
}

val make :
  ?span:span ->
  'a ->
  'a t

val located :
  span ->
  'a ->
  'a t

val dummy :
  'a ->
  'a t

(* ---------------------------------------------------------- *)
(* Accessors                                                  *)
(* ---------------------------------------------------------- *)

val value :
  'a t ->
  'a

val span_of :
  'a t ->
  span

val filename :
  'a t ->
  string

val start_position :
  'a t ->
  position

val end_position :
  'a t ->
  position

(* ---------------------------------------------------------- *)
(* Functional helpers                                         *)
(* ---------------------------------------------------------- *)

val map :
  ('a -> 'b) ->
  'a t ->
  'b t

val map_span :
  (span -> span) ->
  'a t ->
  'a t

val map_with_span :
  (span -> 'a -> 'b) ->
  'a t ->
  'b t

val replace :
  'b ->
  'a t ->
  'b t

val with_span :
  span ->
  'a t ->
  'a t

(* ---------------------------------------------------------- *)
(* Position operations                                        *)
(* ---------------------------------------------------------- *)

val compare_position :
  position ->
  position ->
  int

val position_before :
  position ->
  position ->
  bool

val position_after :
  position ->
  position ->
  bool

val position_equal :
  position ->
  position ->
  bool

(* ---------------------------------------------------------- *)
(* Span operations                                            *)
(* ---------------------------------------------------------- *)

val span_length :
  span ->
  int

val span_is_empty :
  span ->
  bool

val span_contains_position :
  span ->
  position ->
  bool

val span_contains_span :
  span ->
  span ->
  bool

val merge_spans :
  span ->
  span ->
  span

val merge :
  'a t ->
  'b t ->
  span

(* ---------------------------------------------------------- *)
(* Lexing integration                                         *)
(* ---------------------------------------------------------- *)

val position_of_lexing_position :
  Lexing.position ->
  position

val span_of_lexing_positions :
  Lexing.position ->
  Lexing.position ->
  span

val of_lexbuf :
  'a ->
  Lexing.lexbuf ->
  'a t

(* ---------------------------------------------------------- *)
(* Pretty printing                                            *)
(* ---------------------------------------------------------- *)

val pp_position :
  Format.formatter ->
  position ->
  unit

val pp_span :
  Format.formatter ->
  span ->
  unit

val pp :
  (Format.formatter -> 'a -> unit) ->
  Format.formatter ->
  'a t ->
  unit

(* ---------------------------------------------------------- *)
(* Debug                                                      *)
(* ---------------------------------------------------------- *)

val to_string :
  ('a -> string) ->
  'a t ->
  string

(* ---------------------------------------------------------- *)
(* Equality                                                   *)
(* ---------------------------------------------------------- *)

val equal_position :
  position ->
  position ->
  bool

val equal_span :
  span ->
  span ->
  bool

val equal :
  ('a -> 'a -> bool) ->
  'a t ->
  'a t ->
  bool

(* ---------------------------------------------------------- *)
(* Validation                                                 *)
(* ---------------------------------------------------------- *)

val valid_position :
  position ->
  bool

val valid_span :
  span ->
  bool

val valid :
  'a t ->
  bool