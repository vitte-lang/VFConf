#!/usr/bin/env bash
set -Eeuo pipefail

cd /Users/vincent/Documents/ucl-lang/vfconf

echo "[vfconf] Backup..."
BACKUP="../vfconf-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"
echo "[vfconf] Backup: $BACKUP"

python3 <<'PY'
from pathlib import Path
import re

# ============================================================
# 1. Statement.value : Ast.value -> Value.t
# ============================================================

for filename in [
    "lib/ast/statement.ml",
    "lib/ast/statement.mli",
]:
    p = Path(filename)
    s = p.read_text(encoding="utf-8")

    if "type value = Ast.value" in s:
        s = s.replace(
            "type value = Ast.value",
            "type value = Value.t"
        )
        p.write_text(s, encoding="utf-8")
        print("[fixed]", filename, "Ast.value -> Value.t")
    else:
        print("[info]", filename, "already changed or declaration differs")


# ============================================================
# 2. Statement printer : Ast.pp_value -> Value.pp
# ============================================================

p = Path("lib/ast/statement.ml")
s = p.read_text(encoding="utf-8")

s = s.replace("Ast.pp_value", "Value.pp")

p.write_text(s, encoding="utf-8")
print("[fixed] Statement value printer")


# ============================================================
# 3. parser.mly : Node.span has ?filename labelled
# ============================================================

p = Path("lib/parser/parser.mly")
s = p.read_text(encoding="utf-8")

pattern = re.compile(
    r'Node\.span\s+'
    r'(?:~filename|filename)\s+'
    r'\(node_position start_position\)\s+'
    r'\(node_position end_position\)'
)

replacement = '''Node.span
      ~filename
      (node_position start_position)
      (node_position end_position)'''

s2, count = pattern.subn(replacement, s)

if count:
    p.write_text(s2, encoding="utf-8")
    print("[fixed] parser.mly Node.span")
else:
    print("[info] parser.mly Node.span pattern not changed")


# ============================================================
# 4. diagnostic.ml : fix.span is NOT optional
# ============================================================

p = Path("lib/diagnostics/diagnostic.ml")
s = p.read_text(encoding="utf-8")

start = s.find("let pp_fix formatter")
end = s.find("\nlet ", start + 1)

if start == -1:
    raise SystemExit("ERROR: pp_fix not found")

if end == -1:
    end = len(s)

block = s[start:end]

# Preserve the existing message formatting following the first match,
# but remove the incorrect optional-span match manually by reconstructing
# the known pp_fix prefix.
message_pos = block.find("match fix.message with")

if message_pos == -1:
    raise SystemExit("ERROR: match fix.message not found")

message_part = block[message_pos:]

new_block = '''let pp_fix formatter (fix : fix) =
  Format.fprintf
    formatter
    "replace %a with %S"
    Node.pp_span
    fix.span
    fix.replacement;

  ''' + message_part

s = s[:start] + new_block + s[end:]
p.write_text(s, encoding="utf-8")
print("[fixed] diagnostic.ml pp_fix")


# ============================================================
# 5. printer.ml : parameter shadows helper operator
# ============================================================

p = Path("lib/formatter/printer.ml")
s = p.read_text(encoding="utf-8")

s = s.replace(
    "let assignment_operator printer operator =\n"
    "  operator printer\n"
    "    (Formatter.assignment_operator operator)",
    "let assignment_operator printer assignment_operator =\n"
    "  operator printer\n"
    "    (Formatter.assignment_operator assignment_operator)"
)

p.write_text(s, encoding="utf-8")
print("[fixed] printer.ml assignment_operator shadowing")


# ============================================================
# 6. ast.ml : obvious double located in pp_value
#
# Do NOT automatically turn value.value into value.value.value.
# This legacy Ast is structurally duplicated and needs separate cleanup.
# ============================================================

print("[info] ast.ml legacy AST left untouched intentionally")

PY

echo
echo "===== STATEMENT VALUE ====="
grep -n 'type value' \
    lib/ast/statement.ml \
    lib/ast/statement.mli

echo
echo "===== PARSER NODE.SPAN ====="
nl -ba lib/parser/parser.mly | sed -n '18,34p'

echo
echo "===== PP_FIX ====="
nl -ba lib/diagnostics/diagnostic.ml | sed -n '535,558p'

echo
echo "===== CLEAN BUILD ====="
dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-after-structural-fix.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "Build exit status: $STATUS"
echo "Log: /tmp/vfconf-build-after-structural-fix.log"
echo "============================================================"

exit "$STATUS"
