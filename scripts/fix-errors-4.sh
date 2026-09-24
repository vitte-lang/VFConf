#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-fix4-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"
echo "[vfconf] Backup: $BACKUP"

python3 <<'PY'
from pathlib import Path
import re

# ------------------------------------------------------------
# 1. AST: force dump_condition's argument type
# ------------------------------------------------------------

p = Path("lib/ast/ast.ml")
s = p.read_text()

s = s.replace(
    "let rec dump_condition formatter depth located_condition =",
    "let rec dump_condition formatter depth (located_condition : condition located) ="
)

p.write_text(s)
print("[fixed] ast.ml dump_condition annotation")


# ------------------------------------------------------------
# 2. FIELD: to_diagnostic_with_notes uses labelled ~notes
# ------------------------------------------------------------

p = Path("lib/schema/field.ml")
s = p.read_text()

old1 = '''        Error.to_diagnostic_with_notes
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
          ]'''

new1 = '''        Error.to_diagnostic_with_notes
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
                }))'''

old2 = '''        Error.to_diagnostic_with_notes
          (Error.make
             ?span
             (Error.Schema_violation message))
          [
            Printf.sprintf
              "Schema field: %s"
              field;
          ]'''

new2 = '''        Error.to_diagnostic_with_notes
          ~notes:
            [
              Printf.sprintf
                "Schema field: %s"
                field;
            ]
          (Error.make
             ?span
             (Error.Schema_violation message))'''

if old1 in s:
    s = s.replace(old1, new1)
    print("[fixed] field.ml Type_mismatch notes")
else:
    print("[warning] field Type_mismatch block not found")

if old2 in s:
    s = s.replace(old2, new2)
    print("[fixed] field.ml Constraint_violation notes")
else:
    print("[warning] field Constraint_violation block not found")

p.write_text(s)


# ------------------------------------------------------------
# 3. ANALYZER: Warning.t -> Diagnostic.t
# ------------------------------------------------------------

p = Path("lib/semantic/analyzer.ml")
s = p.read_text()

old = '''  add_diagnostic
    (Warning.duplicate_definition
       ~span
       name)
    state'''

new = '''  add_diagnostic
    (Warning.to_diagnostic
       (Warning.duplicate_definition
          ~span
          name))
    state'''

if old in s:
    s = s.replace(old, new)
    print("[fixed] analyzer Warning.to_diagnostic")
else:
    print("[warning] analyzer duplicate block not found")

p.write_text(s)


# ------------------------------------------------------------
# 4. REPORTER
#
# Implementation:
#   let pp reporter formatter = ... : unit
#
# Therefore public interface must NOT contain unit -> unit.
# Same principle for pp_summary if implementation has no ().
# ------------------------------------------------------------

p = Path("lib/diagnostics/reporter.mli")
s = p.read_text()

s = re.sub(
    r'''val pp :
\s*t ->
\s*Format\.formatter ->
\s*unit ->
\s*unit''',
    '''val pp :
  t ->
  Format.formatter ->
  unit''',
    s
)

# Only modify pp_summary when implementation also takes no ().
ml = Path("lib/diagnostics/reporter.ml").read_text()

if re.search(r'let pp_summary\s+reporter\s+formatter\s*=', ml):
    s = re.sub(
        r'''val pp_summary :
\s*t ->
\s*Format\.formatter ->
\s*unit ->
\s*unit''',
        '''val pp_summary :
  t ->
  Format.formatter ->
  unit''',
        s
    )
    print("[fixed] reporter.mli pp_summary signature")

p.write_text(s)
print("[fixed] reporter.mli pp signature")


# reporter.ml callers still passing ()
p = Path("lib/diagnostics/reporter.ml")
s = p.read_text()

old = '''  Format.asprintf
      "%a"
      (pp reporter)
      ()'''

# %a requires printer: formatter -> x -> unit.
# pp reporter is formatter -> unit, therefore use %t thunk.
if old in s:
    s = s.replace(
        old,
        '''  Format.asprintf
      "%t"
      (pp reporter)'''
    )
else:
    s = s.replace(
        '''Format.asprintf
      "%a"
      (pp reporter)
      ()''',
        '''Format.asprintf
      "%t"
      (pp reporter)'''
    )

# Direct call must no longer supply ()
s = re.sub(
    r'''pp
\s+reporter
\s+Format\.std_formatter
\s+\(\);''',
    '''pp
      reporter
      Format.std_formatter;''',
    s
)

p.write_text(s)
print("[fixed] reporter.ml pp callers")


# ------------------------------------------------------------
# 5. RULE: record ambiguity t.severity vs violation.severity
# ------------------------------------------------------------

p = Path("lib/schema/rule.ml")
s = p.read_text()

s = s.replace(
    "let is_error violation =",
    "let is_error (violation : violation) ="
)

s = s.replace(
    "let is_warning violation =",
    "let is_warning (violation : violation) ="
)

p.write_text(s)
print("[fixed] rule.ml is_error/is_warning annotations")


# ------------------------------------------------------------
# 6. RESOLVER
#
# Error.Reference_cycle does not exist.
# Use canonical semantic Invalid_reference.
# ------------------------------------------------------------

p = Path("lib/semantic/resolver.ml")
s = p.read_text()

s = s.replace(
    '''(Error.Reference_cycle
               (string_of_cycle paths))''',
    '''(Error.Invalid_reference
               (Printf.sprintf
                  "reference cycle: %s"
                  (string_of_cycle paths)))'''
)

s = s.replace(
    '''(Error.Reference_cycle
               (Printf.sprintf
                  "maximum depth %d exceeded while resolving %s"
                  maximum
                  (string_of_path path)))''',
    '''(Error.Invalid_reference
               (Printf.sprintf
                  "maximum depth %d exceeded while resolving %s"
                  maximum
                  (string_of_path path)))'''
)

p.write_text(s)
print("[fixed] resolver.ml canonical Invalid_reference diagnostics")


# ------------------------------------------------------------
# 7. PARSE: Node.span arguments are positional
# ------------------------------------------------------------

p = Path("lib/parser/parse.ml")
s = p.read_text()

old = '''    Node.span
      ~filename
      ~start_pos:
        (node_position_of_lexing_position start_position)
      ~end_pos:
        (node_position_of_lexing_position end_position)'''

new = '''    Node.span
      ~filename
      (node_position_of_lexing_position start_position)
      (node_position_of_lexing_position end_position)'''

if old in s:
    s = s.replace(old, new)
    print("[fixed] parse.ml Node.span")
else:
    print("[warning] parse.ml Node.span exact block not found")

p.write_text(s)

PY

echo
echo "============================================================"
echo "VERIFY"
echo "============================================================"

grep -RIn 'Error.Reference_cycle' lib || true
grep -n 'let is_error\|let is_warning' lib/schema/rule.ml
grep -n -A4 '^val pp :' lib/diagnostics/reporter.mli

echo
echo "============================================================"
echo "BUILD"
echo "============================================================"

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-fix4.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-fix4.log"
echo "============================================================"

exit "$STATUS"
