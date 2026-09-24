#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-next-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"

echo "[vfconf] Backup: $BACKUP"

python3 <<'PY'
from pathlib import Path
import re

# ============================================================
# 1. MENHIR
#
# value_node/condition_node were removed from the OCaml header
# because they illegally depended on Menhir $startpos/$endpos.
#
# Their uses are inside semantic actions, where Menhir keywords
# ARE legal.
# ============================================================

p = Path("lib/parser/parser.mly")
s = p.read_text(encoding="utf-8")

s, n1 = re.subn(
    r'\bvalue_node\b',
    'located $startpos $endpos',
    s
)

s, n2 = re.subn(
    r'\bcondition_node\b',
    'located $startpos $endpos',
    s
)

p.write_text(s, encoding="utf-8")

print(f"[fixed] parser.mly: {n1} value_node call(s)")
print(f"[fixed] parser.mly: {n2} condition_node call(s)")


# ============================================================
# 2. LEGACY AST
#
# Ast.Array is currently defined with a double located layer.
# We only repair its legacy pretty-printer here.
# This does NOT affect canonical Value.t.
# ============================================================

p = Path("lib/ast/ast.ml")
s = p.read_text(encoding="utf-8")

old = "pp_value formatter value.value)"
new = "pp_value formatter value.value.value)"

if old in s:
    s = s.replace(old, new, 1)
    print("[fixed] ast.ml legacy Array pretty-printer")
else:
    print("[info] ast.ml Array pattern already changed")

p.write_text(s, encoding="utf-8")


# ============================================================
# 3. FIELD
#
# to_diagnostic_with_notes exposes notes as an optional
# labelled argument.
# ============================================================

p = Path("lib/schema/field.ml")
s = p.read_text(encoding="utf-8")

# Specifically convert:
#
# Error.to_diagnostic_with_notes
#   (...)
#   [
#
# into:
#
# Error.to_diagnostic_with_notes
#   ~notes:[
#     ...
#   ]
#   (...)
#
# Rather than reorder blindly, inspect the known failing block.
pattern = re.compile(
    r'''Error\.to_diagnostic_with_notes
\s*\(
(?P<error>.*?)
\)
\s*\[
(?P<notes>.*?)
\]''',
    re.DOTALL
)

def fix_notes(m):
    error = m.group("error")
    notes = m.group("notes")

    return (
        "Error.to_diagnostic_with_notes\n"
        "          ~notes:["
        + notes
        + "]\n"
        "          ("
        + error
        + ")"
    )

s2, count = pattern.subn(fix_notes, s)

if count:
    p.write_text(s2, encoding="utf-8")
    print(f"[fixed] field.ml: {count} diagnostic notes call(s)")
else:
    print("[info] field.ml notes pattern not automatically changed")


# ============================================================
# 4. REPORTER
#
# Record-field ambiguity makes OCaml infer Diagnostic.t instead
# of Diagnostic.label/fix.
# ============================================================

p = Path("lib/diagnostics/reporter.ml")
s = p.read_text(encoding="utf-8")

s = s.replace(
    "let json_label label =",
    "let json_label (label : Diagnostic.label) ="
)

s = s.replace(
    "let json_fix fix =",
    "let json_fix (fix : Diagnostic.fix) ="
)

p.write_text(s, encoding="utf-8")
print("[fixed] reporter.ml record annotations")


# ============================================================
# 5. RULE
#
# Same record ambiguity: violation is inferred as Rule.t.
# ============================================================

p = Path("lib/schema/rule.ml")
s = p.read_text(encoding="utf-8")

s = s.replace(
    "let diagnostic_of_violation violation =",
    "let diagnostic_of_violation (violation : violation) ="
)

p.write_text(s, encoding="utf-8")
print("[fixed] rule.ml violation annotation")


# ============================================================
# 6. SCHEMA
#
# section and t share record fields. Explicit annotations make
# the implementation conform to schema.mli.
# ============================================================

p = Path("lib/schema/schema.ml")
s = p.read_text(encoding="utf-8")

replacements = {
    "let section_path section =":
        "let section_path (section : section) =",

    "let section_description section =":
        "let section_description (section : section) =",

    "let section_allows_unknown_fields section =":
        "let section_allows_unknown_fields (section : section) =",

    "let section_fields section =":
        "let section_fields (section : section) =",

    "let find_field section name =":
        "let find_field (section : section) name =",

    "let mem_field section name =":
        "let mem_field (section : section) name =",

    "let add_field field section =":
        "let add_field field (section : section) =",
}

for old, new in replacements.items():
    s = s.replace(old, new)

p.write_text(s, encoding="utf-8")
print("[fixed] schema.ml section annotations")

PY

echo
echo "============================================================"
echo "MENHIR HELPERS"
echo "============================================================"

grep -nE 'value_node|condition_node' lib/parser/parser.mly || true

echo
echo "============================================================"
echo "SCHEMA SECTION FUNCTIONS"
echo "============================================================"

grep -nE \
'let section_(path|description|allows_unknown_fields|fields)' \
lib/schema/schema.ml

echo
echo "============================================================"
echo "BUILD"
echo "============================================================"

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-next.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-next.log"
echo "============================================================"

exit "$STATUS"
