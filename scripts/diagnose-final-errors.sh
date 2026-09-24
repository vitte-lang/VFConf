#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

show () {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    nl -ba "$2" | sed -n "$3,$4p"
}

show "AST TYPE DEFINITIONS" \
  lib/ast/ast.ml 1 150

show "AST ARRAY/OBJECT PRINTER" \
  lib/ast/ast.ml 375 425

show "PARSER STATEMENT USE" \
  lib/parser/parser.mly 285 320

echo
echo "===== ALL statement REFERENCES ====="
grep -n '\bstatement\b' lib/parser/parser.mly || true

show "FIELD DIAGNOSTICS" \
  lib/schema/field.ml 525 590

echo
echo "===== ERROR.to_diagnostic_with_notes ====="
grep -n -A15 -B5 'to_diagnostic_with_notes' \
  lib/diagnostics/error.ml \
  lib/diagnostics/error.mli || true

show "REPORTER FIX AREA" \
  lib/diagnostics/reporter.ml 400 445

echo
echo "===== DIAGNOSTIC FIX TYPE ====="
nl -ba lib/diagnostics/diagnostic.ml | sed -n '15,45p'
nl -ba lib/diagnostics/diagnostic.mli | sed -n '12,40p'

show "RULE TYPES + with_path" \
  lib/schema/rule.ml 1 120

show "RULE INTERFACE" \
  lib/schema/rule.mli 1 110

show "SCHEMA SECTION MUTATORS" \
  lib/schema/schema.ml 150 205

show "SCHEMA INTERFACE MUTATORS" \
  lib/schema/schema.mli 120 165

show "RESOLVER TYPES" \
  lib/semantic/resolver.ml 1 120

show "RESOLVER FUNCTIONS" \
  lib/semantic/resolver.ml 120 285

echo
echo "===== RESOLVER INTERFACE ====="
nl -ba lib/semantic/resolver.mli | sed -n '1,180p'

echo
echo "===== ANALYZER DUPLICATE DEFINITION ====="
grep -RIn 'Duplicate_definition\|duplicate_definition' \
  lib/semantic \
  lib/diagnostics || true
