#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT="/Users/vincent/Documents/ucl-lang/vfconf"

cd "$PROJECT"

echo "============================================================"
echo " VFConf build diagnostic"
echo "============================================================"

echo
echo "===== NODE.SPAN IMPLEMENTATION ====="
grep -n -A10 -B4 'let span' lib/ast/node.ml || true

echo
echo "===== NODE.SPAN INTERFACE ====="
grep -n -A8 -B4 'val span' lib/ast/node.mli || true

echo
echo "===== AST TYPES ====="
nl -ba lib/ast/ast.ml | sed -n '1,180p'

echo
echo "===== AST ERROR AREA ====="
nl -ba lib/ast/ast.ml | sed -n '355,405p'

echo
echo "===== DIAGNOSTIC TYPES ====="
nl -ba lib/diagnostics/diagnostic.ml | sed -n '1,130p'

echo
echo "===== DIAGNOSTIC PP_FIX ====="
nl -ba lib/diagnostics/diagnostic.ml | sed -n '520,565p'

echo
echo "===== PARSER SPAN ====="
nl -ba lib/parser/parser.mly | sed -n '8,40p'

echo
echo "===== SEARCH SPAN DEFINITIONS ====="
grep -RIn \
  --include='*.ml' \
  --include='*.mli' \
  -E 'type (span|fix)|let span|val span' \
  lib || true

echo
echo "===== CURRENT BUILD ERRORS ====="

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo " Build exit status: $STATUS"
echo " Log: /tmp/vfconf-build.log"
echo "============================================================"

exit "$STATUS"
