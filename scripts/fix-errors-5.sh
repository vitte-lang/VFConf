#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

BACKUP="../vfconf-fix5-backup-$(date +%Y%m%d-%H%M%S)"
cp -R . "$BACKUP"

echo "[vfconf] Backup: $BACKUP"

python3 scripts/fix-errors-5.py

echo
echo "===== FIELD ====="
nl -ba lib/schema/field.ml | sed -n '535,575p'

echo
echo "===== PARSE ====="
nl -ba lib/parser/parse.ml | sed -n '46,58p'

echo
echo "===== REPORTER ====="
nl -ba lib/diagnostics/reporter.ml | sed -n '510,530p'

echo
echo "===== BUILD ====="

dune clean

set +e
dune build --profile release 2>&1 | tee /tmp/vfconf-build-fix5.log
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "============================================================"
echo "BUILD STATUS: $STATUS"
echo "LOG: /tmp/vfconf-build-fix5.log"
echo "============================================================"

exit "$STATUS"
