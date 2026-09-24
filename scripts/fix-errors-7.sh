#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-fix7-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"
echo "[vfconf] Backup: $BACKUP"

python3 <<'PY'
from pathlib import Path

ROOT = Path("/Users/vincent/Documents/ucl-lang/vfconf")


# ============================================================
# 1. FIELD
# Exact replacement, line-oriented.
# ============================================================

p = ROOT / "lib/schema/field.ml"
s = p.read_text()

old = '''    | Type_mismatch { field; expected; found } ->
        Error.to_diagnostic_with_notes
          (Error.make
             ?span
             (Error.Type_mismatch
                {
                  expected =
                    string_of_value_type expected;
                  found =
                    string_of_value_type found;
                }))
          [
            Printf.sprintf
              "Schema field: %s"
              field;
          ]

    | Constraint_violation
        {
          field;
          message;
          _;
        } ->
        Error.to_diagnostic_with_notes
          (Error.make
             ?span
             (Error.Schema_violation message))
          [
            Printf.sprintf
              "Schema field: %s"
              field;
          ]'''

new = '''    | Type_mismatch { field; expected; found } ->
        Error.to_diagnostic_with_notes
          ~notes:
            [
              Printf.sprintf
                "Schema field: %s"
                field;
            ]
          (Error.make
             ?span
             (Error.Type_mismatch
                {
                  expected =
                    string_of_value_type expected;
                  found =
                    string_of_value_type found;
                }))

    | Constraint_violation
        {
          field;
          message;
          _;
        } ->
        Error.to_diagnostic_with_notes
          ~notes:
            [
              Printf.sprintf
                "Schema field: %s"
                field;
            ]
          (Error.make
             ?span
             (Error.Schema_violation message))'''

if old not in s:
    raise SystemExit("[ERROR] field.ml expected block not found")

s = s.replace(old, new, 1)
p.write_text(s)

print("[fixed] field.ml ~notes")


# ============================================================
# 2. ANALYZER
# state/result share symbols + diagnostics fields.
# Explicitly type state accessors and analysis functions.
# ============================================================

p = ROOT / "lib/semantic/analyzer.ml"
s = p.read_text()

replacements = {
    "let find_configuration_symbol state path =":
        "let find_configuration_symbol (state : state) path =",

    "let find_definition_symbol state name =":
        "let find_definition_symbol (state : state) name =",

    "let reference_exists state path =":
        "let reference_exists (state : state) path =",

    "let rec analyze_value state value =":
        "let rec analyze_value (state : state) value =",

    "let analyze_condition state condition =":
        "let analyze_condition (state : state) condition =",

    "let validate_assignment_operator state statement =":
        "let validate_assignment_operator (state : state) statement =",
}

for old, new in replacements.items():
    if old in s:
        s = s.replace(old, new)
        print("[fixed] analyzer:", old.split("=")[0].strip())

p.write_text(s)


# ============================================================
# 3. REPORTER SUMMARY
#
# pp_summary reporter : formatter -> unit
# => %t, not %a + ()
# ============================================================

p = ROOT / "lib/diagnostics/reporter.ml"
s = p.read_text()

old = '''let summary reporter =
    Format.asprintf
      "%a"
      (pp_summary reporter)
      ()'''

new = '''let summary reporter =
    Format.asprintf
      "%t"
      (pp_summary reporter)'''

if old not in s:
    raise SystemExit("[ERROR] reporter summary block not found")

s = s.replace(old, new, 1)
p.write_text(s)

print("[fixed] reporter.ml summary %t")


# ============================================================
# 4. PARSE
#
# Node.position has optional labelled args and requires final ().
# ============================================================

p = ROOT / "lib/parser/parse.ml"
s = p.read_text()

old = '''        let position =
          Node.position
            ~offset:0
            ~line:1
            ~column:0
        in'''

new = '''        let position =
          Node.position
            ~offset:0
            ~line:1
            ~column:0
            ()
        in'''

if old not in s:
    raise SystemExit("[ERROR] parse.ml Node.position block not found")

s = s.replace(old, new, 1)
p.write_text(s)

print("[fixed] parse.ml Node.position ()")


# ============================================================
# 5. LOADER
#
# Lexer.Error carries an inline record.
# Destructure it immediately.
#
# Use start_pos for exact lexical line/column instead of
# lex_curr_p, preserving the lexer's real source position.
# ============================================================

p = ROOT / "lib/config/loader.ml"
s = p.read_text()

old = '''    | Lexer.Error message ->
        let line, column =
          line_column_of_lexbuf lexbuf
        in

        raise
          (Load_error
             (Lexing_error
                {
                  filename;
                  line;
                  column;
                  message;
                }))'''

new = '''    | Lexer.Error { message; start_pos; end_pos = _ } ->
        let line =
          start_pos.Lexing.pos_lnum
        in

        let column =
          start_pos.Lexing.pos_cnum
          - start_pos.Lexing.pos_bol
        in

        raise
          (Load_error
             (Lexing_error
                {
                  filename;
                  line;
                  column;
                  message;
                }))'''

if old not in s:
    raise SystemExit("[ERROR] loader.ml Lexer.Error block not found")

s = s.replace(old, new, 1)
p.write_text(s)

print("[fixed] loader.ml Lexer.Error destructuring")

PY

echo
echo "============================================================"
echo "VERIFY"
echo "============================================================"

echo "-- FIELD --"
nl -ba lib/schema/field.ml | sed -n '540,575p'

echo
echo "-- ANALYZER --"
nl -ba lib/semantic/analyzer.ml | sed -n '145,180p'

echo
echo "-- REPORTER --"
nl -ba lib/diagnostics/reporter.ml | sed -n '540,558p'

echo
echo "-- PARSE --"
nl -ba lib/parser/parse.ml | sed -n '243,263p'

echo
echo "-- LOADER --"
nl -ba lib/config/loader.ml | sed -n '126,165p'

echo
echo "============================================================"
echo "BUILD"
echo "============================================================"

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-fix7.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-fix7.log"
echo "============================================================"

exit "$STATUS"
