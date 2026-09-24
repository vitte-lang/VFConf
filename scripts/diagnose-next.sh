#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/vincent/Documents/ucl-lang/vfconf"
cd "$ROOT"

show () {
    local title="$1"
    local file="$2"
    local from="$3"
    local to="$4"

    echo
    echo "============================================================"
    echo "$title"
    echo "============================================================"
    nl -ba "$file" | sed -n "${from},${to}p"
}

show "AST / pp_value" \
    lib/ast/ast.ml 350 400

show "PARSER / value_node use" \
    lib/parser/parser.mly 570 605

show "FIELD / Diagnostic call" \
    lib/schema/field.ml 530 565

show "REPORTER / label" \
    lib/diagnostics/reporter.ml 200 240

show "RULE / violation" \
    lib/schema/rule.ml 625 670

show "ANALYZER / Error constructor" \
    lib/semantic/analyzer.ml 55 100

show "RESOLVER / context-result" \
    lib/semantic/resolver.ml 230 275

show "SCHEMA IMPLEMENTATION" \
    lib/schema/schema.ml 75 120

show "SCHEMA INTERFACE" \
    lib/schema/schema.mli 65 105

echo
echo "============================================================"
echo "ERROR TYPE DEFINITIONS"
echo "============================================================"
nl -ba lib/diagnostics/error.ml | sed -n '1,180p'

echo
echo "============================================================"
echo "SEARCH value_node"
echo "============================================================"
grep -n 'value_node' lib/parser/parser.mly || true

echo
echo "============================================================"
echo "SEARCH condition_node"
echo "============================================================"
grep -n 'condition_node' lib/parser/parser.mly || true

echo
echo "============================================================"
echo "SEARCH DIAGNOSTIC CONSTRUCTORS"
echo "============================================================"
grep -nE \
'type (fix|label|t)|let (make|error|warning)|val (make|error|warning)' \
lib/diagnostics/diagnostic.ml \
lib/diagnostics/diagnostic.mli || true
