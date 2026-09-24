#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$ROOT"

echo "============================================================"
echo " VFConf diagnostics gate"
echo "============================================================"

echo
echo "[1/4] Static diagnostic audit"
python3 scripts/audit-diagnostics.py

echo
echo "[2/4] Release build"
dune build --profile release

echo
echo "[3/4] Tests"
dune runtest

echo
echo "[4/4] Functional diagnostic tests"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CHECKER="./_build/default/bin/check.exe"

[[ -x "$CHECKER" ]] || {
    echo "[ERROR] vfconf-check executable not found" >&2
    exit 1
}

# Valid minimal source
printf 'name = "valid"\n' \
    > "$TMP/valid.vf.conf"

"$CHECKER" "$TMP/valid.vf.conf" >/dev/null

# Duplicate key must fail with VF0201
cat > "$TMP/duplicate.vf.conf" <<'EOF'
name = "first"
name = "second"
EOF

set +e
DUPLICATE_OUTPUT="$(
    "$CHECKER" "$TMP/duplicate.vf.conf" 2>&1
)"
DUPLICATE_STATUS=$?
set -e

if [[ $DUPLICATE_STATUS -eq 0 ]]; then
    echo "[ERROR] duplicate-key test unexpectedly succeeded" >&2
    exit 1
fi

if ! grep -q 'VF0201' <<<"$DUPLICATE_OUTPUT"; then
    echo "[ERROR] duplicate-key diagnostic VF0201 missing" >&2
    printf '%s\n' "$DUPLICATE_OUTPUT" >&2
    exit 1
fi

# Lexical error must fail
printf 'value = @@@\n' \
    > "$TMP/lexical.vf.conf"

set +e
LEXICAL_OUTPUT="$(
    "$CHECKER" "$TMP/lexical.vf.conf" 2>&1
)"
LEXICAL_STATUS=$?
set -e

if [[ $LEXICAL_STATUS -eq 0 ]]; then
    echo "[ERROR] lexical-error test unexpectedly succeeded" >&2
    exit 1
fi

# Semantic reference error must fail
printf 'value = $does.not.exist\n' \
    > "$TMP/reference.vf.conf"

set +e
REFERENCE_OUTPUT="$(
    "$CHECKER" "$TMP/reference.vf.conf" 2>&1
)"
REFERENCE_STATUS=$?
set -e

if [[ $REFERENCE_STATUS -eq 0 ]]; then
    echo "[ERROR] undefined-reference test unexpectedly succeeded" >&2
    exit 1
fi

echo
echo "============================================================"
echo " VFConf diagnostics: FINAL GATE PASSED"
echo "============================================================"
