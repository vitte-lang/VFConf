#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-fix6-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"
echo "[vfconf] Backup: $BACKUP"

python3 <<'PY'
from pathlib import Path
import re

ROOT = Path("/Users/vincent/Documents/ucl-lang/vfconf")

# ============================================================
# FIELD
# ============================================================

p = ROOT / "lib/schema/field.ml"
s = p.read_text()

# These are exactly the two currently failing calls.
s = s.replace(
'''        Error.to_diagnostic_with_notes
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
          ]''',

'''        Error.to_diagnostic_with_notes
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
)

s = s.replace(
'''        Error.to_diagnostic_with_notes
          (Error.make
             ?span
             (Error.Schema_violation message))
          [
            Printf.sprintf
              "Schema field: %s"
              field;
          ]''',

'''        Error.to_diagnostic_with_notes
          ~notes:
            [
              Printf.sprintf
                "Schema field: %s"
                field;
            ]
          (Error.make
             ?span
             (Error.Schema_violation message))'''
)

p.write_text(s)
print("[fixed] field.ml labelled notes")


# ============================================================
# REPORTER
# pp : t -> formatter -> unit
# Remove remaining () callers.
# ============================================================

p = ROOT / "lib/diagnostics/reporter.ml"
s = p.read_text()

s = re.sub(
    r'''pp
\s+reporter
\s+Format\.err_formatter
\s+\(\);''',
    '''pp
      reporter
      Format.err_formatter;''',
    s
)

# Also catch std_formatter if another occurrence remains.
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
print("[fixed] reporter.ml remaining pp callers")


# ============================================================
# PARSE
#
# Convert every remaining:
#
# Node.span
#   ~filename
#   ~start_pos:X
#   ~end_pos:Y
#
# manually at token level by removing labels.
# ============================================================

p = ROOT / "lib/parser/parse.ml"
s = p.read_text()

s = re.sub(
    r'~start_pos:([A-Za-z0-9_\.]+)',
    r'\1',
    s
)

s = re.sub(
    r'~end_pos:([A-Za-z0-9_\.]+)',
    r'\1',
    s
)

p.write_text(s)
print("[fixed] parse.ml remaining Node.span labels")


# ============================================================
# ANALYZER
#
# state and result both expose symbols-like fields.
# Annotate every function parameter literally named state.
#
# Restricted to analyzer.ml.
# ============================================================

p = ROOT / "lib/semantic/analyzer.ml"
s = p.read_text()

# Functions ending in "... state =" where state has not
# already been annotated.
s, count = re.subn(
    r'^(let(?: rec)?\s+[A-Za-z0-9_]+\s+[^\n=]*?)\sstate\s*=',
    lambda m: m.group(1) + " (state : state) =",
    s,
    flags=re.MULTILINE
)

# 'and foo ... state =' cases.
s, count2 = re.subn(
    r'^(and\s+[A-Za-z0-9_]+\s+[^\n=]*?)\sstate\s*=',
    lambda m: m.group(1) + " (state : state) =",
    s,
    flags=re.MULTILINE
)

p.write_text(s)

print(f"[fixed] analyzer.ml state annotations: {count + count2}")

PY

echo
echo "============================================================"
echo "FIELD CHECK"
echo "============================================================"

nl -ba lib/schema/field.ml | sed -n '535,575p'

echo
echo "============================================================"
echo "REPORTER CHECK"
echo "============================================================"

nl -ba lib/diagnostics/reporter.ml | sed -n '513,540p'

echo
echo "============================================================"
echo "NODE.SPAN LABELS REMAINING"
echo "============================================================"

grep -nE '~start_pos:|~end_pos:' lib/parser/parse.ml || true

echo
echo "============================================================"
echo "LOADER TYPE DEFINITIONS"
echo "============================================================"

grep -RIn -A18 -B5 \
  'exception Error\|exception Load_error\|type load_error\|type error\|Lexing_error\|Parsing_error' \
  lib/config/loader.ml \
  lib/config/loader.mli \
  lib/lexer/lexer.mll \
  lib/lexer/lexer.ml 2>/dev/null || true

echo
echo "============================================================"
echo "BUILD"
echo "============================================================"

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-fix6.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-fix6.log"
echo "============================================================"

exit "$STATUS"
