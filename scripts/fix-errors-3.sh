#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-fix3-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"

echo "[vfconf] Backup: $BACKUP"

python3 <<'PY'
from pathlib import Path
import re

# ============================================================
# 1. parser.mly
#
# statement helper had the same Menhir-keyword problem.
# Replace uses in actions by direct located call.
# ============================================================

p = Path("lib/parser/parser.mly")
s = p.read_text(encoding="utf-8")

# There should no longer be a header helper. Replace remaining
# action uses.
s, n = re.subn(
    r'\bstatement\s*\n(\s*)\(',
    r'located $startpos $endpos\n\1(',
    s
)

p.write_text(s, encoding="utf-8")
print(f"[fixed] parser.mly: {n} statement action(s)")


# ============================================================
# 2. ast.ml
#
# Explicit annotation prevents OCaml from confusing the
# different records containing a `value` field.
# ============================================================

p = Path("lib/ast/ast.ml")
s = p.read_text(encoding="utf-8")

old = '''(fun index value ->
           if index > 0 then
             Format.fprintf formatter ", ";

           pp_value formatter value.value.value)'''

new = '''(fun index (value : value located) ->
           if index > 0 then
             Format.fprintf formatter ", ";

           pp_value formatter value.value)'''

if old in s:
    s = s.replace(old, new, 1)
    print("[fixed] ast.ml Array value annotation")
else:
    # Handle formatting variation.
    s = s.replace(
        "(fun index value ->",
        "(fun index (value : value located) ->",
        1
    )
    s = s.replace(
        "pp_value formatter value.value.value)",
        "pp_value formatter value.value)",
        1
    )
    print("[fixed] ast.ml Array fallback annotation")

p.write_text(s, encoding="utf-8")


# ============================================================
# 3. reporter.ml
#
# Diagnostic.fix.span is Node.span, NOT option.
# The previous error was record ambiguity.
# Annotate every fix lambda.
# ============================================================

p = Path("lib/diagnostics/reporter.ml")
s = p.read_text(encoding="utf-8")

s = re.sub(
    r'\(fun fix ->',
    '(fun (fix : Diagnostic.fix) ->',
    s
)

p.write_text(s, encoding="utf-8")
print("[fixed] reporter.ml fix annotations")


# ============================================================
# 4. rule.ml
#
# context and violation both have a `path` field.
# Force the Context API to context.
# ============================================================

p = Path("lib/schema/rule.ml")
s = p.read_text(encoding="utf-8")

s = s.replace(
    "let with_path path context =",
    "let with_path path (context : context) ="
)

s = s.replace(
    "let clear_path context =",
    "let clear_path (context : context) ="
)

p.write_text(s, encoding="utf-8")
print("[fixed] rule.ml context annotations")


# ============================================================
# 5. schema.ml
#
# section and schema t share description and other fields.
# Explicitly type all section mutators.
# ============================================================

p = Path("lib/schema/schema.ml")
s = p.read_text(encoding="utf-8")

replacements = {
    "let set_field field section =":
        "let set_field field (section : section) =",

    "let remove_field name section =":
        "let remove_field name (section : section) =",

    "let with_unknown_fields allowed section =":
        "let with_unknown_fields allowed (section : section) =",

    "let with_section_description description section =":
        "let with_section_description description (section : section) =",
}

for old, new in replacements.items():
    if old in s:
        s = s.replace(old, new)
        print("[fixed] schema.ml:", old.split("=")[0].strip())

p.write_text(s, encoding="utf-8")


# ============================================================
# 6. resolver.ml
#
# context and result both contain `environment`.
# Type annotation removes record ambiguity.
# ============================================================

p = Path("lib/semantic/resolver.ml")
s = p.read_text(encoding="utf-8")

replacements = {
    "let resolve_direct context path =":
        "let resolve_direct (context : context) path =",

    "let resolve_direct_opt context path =":
        "let resolve_direct_opt (context : context) path =",

    "let rec resolve_value context value =":
        "let rec resolve_value (context : context) value =",

    "and resolve context path =":
        "and resolve (context : context) path =",

    "let resolve_opt context path =":
        "let resolve_opt (context : context) path =",
}

for old, new in replacements.items():
    if old in s:
        s = s.replace(old, new)
        print("[fixed] resolver.ml:", old.split("=")[0].strip())

p.write_text(s, encoding="utf-8")


# ============================================================
# 7. analyzer.ml
#
# Duplicate_definition is canonically a Warning, according to
# diagnostics/warning.ml. Do NOT add an Error constructor.
# ============================================================

p = Path("lib/semantic/analyzer.ml")
s = p.read_text(encoding="utf-8")

pattern = re.compile(
    r'''let duplicate_definition name span state =
\s*add_error
\s*~span
\s*\(Error\.Duplicate_definition name\)
\s*state'''
)

replacement = '''let duplicate_definition name span state =
  add_diagnostic
    (Warning.duplicate_definition
       ~span
       name)
    state'''

s, n = pattern.subn(replacement, s)

p.write_text(s, encoding="utf-8")
print(f"[fixed] analyzer.ml duplicate_definition: {n}")


# ============================================================
# 8. field.ml
#
# Fix the concrete Type_mismatch call without broad regex.
# ============================================================

p = Path("lib/schema/field.ml")
s = p.read_text(encoding="utf-8")

old = '''        Error.to_diagnostic_with_notes
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

new = '''        Error.to_diagnostic_with_notes
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

if old in s:
    s = s.replace(old, new, 1)
    print("[fixed] field.ml Type_mismatch notes")
else:
    print("[warning] field.ml exact Type_mismatch block not found")

p.write_text(s, encoding="utf-8")

PY

echo
echo "============================================================"
echo "CHECKS"
echo "============================================================"

echo "-- remaining value_node/condition_node --"
grep -nE '\b(value_node|condition_node)\b' \
    lib/parser/parser.mly || true

echo
echo "-- Duplicate_definition --"
grep -n 'Duplicate_definition' \
    lib/semantic/analyzer.ml || true

echo
echo "-- resolver signatures --"
grep -nE \
'let resolve_direct|let resolve_direct_opt|let rec resolve_value|and resolve |let resolve_opt' \
    lib/semantic/resolver.ml

echo
echo "============================================================"
echo "CLEAN BUILD"
echo "============================================================"

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-fix3.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-fix3.log"
echo "============================================================"

exit "$STATUS"
