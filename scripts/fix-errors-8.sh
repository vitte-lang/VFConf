#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-fix8-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"

echo "[vfconf] Backup: $BACKUP"

# ============================================================
# FIELD.ML
#
# Do NOT rewrite the whole block.
#
# Current:
#
# Error.to_diagnostic_with_notes
#   (Error.make ...)
#   [ ... ]
#
# Required:
#
# Error.to_diagnostic_with_notes
#   ~notes:[ ... ]
#   (Error.make ...)
#
# Use line ranges we have already verified.
# ============================================================

python3 <<'PY'
from pathlib import Path

p = Path("lib/schema/field.ml")
lines = p.read_text().splitlines()

def find_line(text, start=0):
    for i in range(start, len(lines)):
        if text in lines[i]:
            return i
    raise RuntimeError(f"not found: {text}")

def find_matching_paren(start):
    depth = 0
    started = False

    for i in range(start, len(lines)):
        for c in lines[i]:
            if c == '(':
                depth += 1
                started = True
            elif c == ')':
                depth -= 1

        if started and depth == 0:
            return i

    raise RuntimeError("unclosed parenthesis")

def find_list_end(start):
    depth = 0
    started = False

    for i in range(start, len(lines)):
        for c in lines[i]:
            if c == '[':
                depth += 1
                started = True
            elif c == ']':
                depth -= 1

        if started and depth == 0:
            return i

    raise RuntimeError("unclosed list")

def fix_call(search_from):
    call = find_line("Error.to_diagnostic_with_notes", search_from)

    error_start = call + 1

    while not lines[error_start].lstrip().startswith("(Error.make"):
        error_start += 1

    error_end = find_matching_paren(error_start)

    notes_start = error_end + 1

    while not lines[notes_start].lstrip().startswith("["):
        notes_start += 1

    notes_end = find_list_end(notes_start)

    indent = lines[error_start][:len(lines[error_start]) -
                                len(lines[error_start].lstrip())]

    error_block = lines[error_start:error_end + 1]
    notes_block = lines[notes_start:notes_end + 1]

    # Convert first '[' to '~notes:['
    stripped = notes_block[0].lstrip()
    notes_indent = notes_block[0][
        :len(notes_block[0]) - len(stripped)
    ]

    notes_block[0] = notes_indent + "~notes:["

    replacement = notes_block + error_block

    lines[error_start:notes_end + 1] = replacement

    return call + len(replacement) + 1


pos = fix_call(0)
pos = fix_call(pos)

p.write_text("\n".join(lines) + "\n")

print("[fixed] field.ml: 2 to_diagnostic_with_notes calls")
PY


# ============================================================
# REPORTER.ML
# ============================================================

python3 <<'PY'
from pathlib import Path

p = Path("lib/diagnostics/reporter.ml")
s = p.read_text()

s = s.replace(
'''let summary reporter =
    Format.asprintf
      "%a"
      (pp_summary reporter)
      ()''',
'''let summary reporter =
    Format.asprintf
      "%t"
      (pp_summary reporter)'''
)

p.write_text(s)

print("[fixed] reporter.ml summary")
PY


# ============================================================
# ANALYZER.ML
# Explicit state annotations.
# ============================================================

python3 <<'PY'
from pathlib import Path

p = Path("lib/semantic/analyzer.ml")
s = p.read_text()

changes = {
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

count = 0

for old, new in changes.items():
    if old in s:
        s = s.replace(old, new)
        count += 1

p.write_text(s)

print(f"[fixed] analyzer.ml annotations: {count}")
PY


# ============================================================
# PARSE.ML
# Node.position requires final ()
# ============================================================

python3 <<'PY'
from pathlib import Path

p = Path("lib/parser/parse.ml")
lines = p.read_text().splitlines()

for i, line in enumerate(lines):
    if "Node.position" not in line:
        continue

    # Look at following lines.
    window = lines[i:i+8]

    has_offset = any("~offset:" in x for x in window)
    has_line = any("~line:" in x for x in window)
    has_column = any("~column:" in x for x in window)

    if not (has_offset and has_line and has_column):
        continue

    # Locate ~column line.
    for j in range(i + 1, min(i + 8, len(lines))):
        if "~column:" in lines[j]:
            # If next meaningful line is already (), leave it.
            k = j + 1

            while k < len(lines) and not lines[k].strip():
                k += 1

            if k < len(lines) and lines[k].strip() == "()":
                break

            indent = lines[j][:len(lines[j]) -
                              len(lines[j].lstrip())]

            lines.insert(j + 1, indent + "()")
            print(
                f"[fixed] parse.ml Node.position at line {i+1}"
            )
            break

p.write_text("\n".join(lines) + "\n")
PY


# ============================================================
# LOADER.ML
#
# Lexer.Error contains inline record.
# Rewrite only its exception handler.
# ============================================================

python3 <<'PY'
from pathlib import Path

p = Path("lib/config/loader.ml")
lines = p.read_text().splitlines()

start = None
end = None

for i, line in enumerate(lines):
    if "| Lexer.Error message ->" in line:
        start = i
        break

if start is None:
    print("[loader] handler already modified or not found")
else:
    for i in range(start + 1, len(lines)):
        if lines[i].lstrip().startswith("| Parser.Error"):
            end = i
            break

    if end is None:
        raise RuntimeError("Parser.Error boundary not found")

    indent = lines[start][
        :len(lines[start]) - len(lines[start].lstrip())
    ]

    block = [
        indent + "| Lexer.Error { message; start_pos; end_pos = _ } ->",
        indent + "    let line =",
        indent + "      start_pos.Lexing.pos_lnum",
        indent + "    in",
        "",
        indent + "    let column =",
        indent + "      start_pos.Lexing.pos_cnum",
        indent + "      - start_pos.Lexing.pos_bol",
        indent + "    in",
        "",
        indent + "    raise",
        indent + "      (Load_error",
        indent + "         (Lexing_error",
        indent + "            {",
        indent + "              filename;",
        indent + "              line;",
        indent + "              column;",
        indent + "              message;",
        indent + "            }))",
        "",
    ]

    lines[start:end] = block

    p.write_text("\n".join(lines) + "\n")

    print("[fixed] loader.ml Lexer.Error inline record")
PY


echo
echo "============================================================"
echo "VERIFY FIELD"
echo "============================================================"

nl -ba lib/schema/field.ml | sed -n '535,580p'

echo
echo "============================================================"
echo "VERIFY ANALYZER"
echo "============================================================"

nl -ba lib/semantic/analyzer.ml | sed -n '145,180p'

echo
echo "============================================================"
echo "VERIFY REPORTER"
echo "============================================================"

nl -ba lib/diagnostics/reporter.ml | sed -n '540,558p'

echo
echo "============================================================"
echo "VERIFY PARSE"
echo "============================================================"

nl -ba lib/parser/parse.ml | sed -n '243,265p'

echo
echo "============================================================"
echo "VERIFY LOADER"
echo "============================================================"

nl -ba lib/config/loader.ml | sed -n '125,170p'


echo
echo "============================================================"
echo "BUILD"
echo "============================================================"

dune clean

set +e

dune build --profile release \
    2>&1 | tee /tmp/vfconf-build-fix8.log

STATUS=${PIPESTATUS[0]}

set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-fix8.log"
echo "============================================================"

exit "$STATUS"
