#!/usr/bin/env python3

from pathlib import Path
from collections import defaultdict
import re
import sys

ROOT = Path(__file__).resolve().parent.parent

ERROR_MLI = ROOT / "lib/diagnostics/error.mli"
WARNING_MLI = ROOT / "lib/diagnostics/warning.mli"

SCAN_DIRS = [
    ROOT / "lib",
    ROOT / "bin",
    ROOT / "tests",
]

errors = []
warnings = []

CODE_RE = re.compile(r'\b(?:VF|VFW)[0-9]{4}\b')
ANY_VF_RE = re.compile(r'\b(?:VF|VFW)[0-9A-Za-z_-]*[0-9][0-9A-Za-z_-]*\b')


def files():
    for directory in SCAN_DIRS:
        if not directory.exists():
            continue

        for extension in ("*.ml", "*.mli", "*.mly", "*.mll"):
            yield from directory.rglob(extension)


def read(path):
    return path.read_text(errors="replace")


def constructors(path):
    if not path.exists():
        return []

    source = read(path)

    match = re.search(
        r"type\s+kind\s*=\s*(.*?)(?=\n(?:type|val|\(\*))",
        source,
        re.S,
    )

    if not match:
        errors.append(f"cannot parse kind in {path}")
        return []

    result = []

    for line in match.group(1).splitlines():
        line = line.strip()

        if not line.startswith("|"):
            continue

        value = line[1:].strip()

        if not value:
            continue

        name = value.split()[0]

        if re.fullmatch(r"[A-Z][A-Za-z0-9_]*", name):
            result.append(name)

    return result


all_files = list(files())

# ------------------------------------------------------------
# Diagnostic codes
# ------------------------------------------------------------

code_locations = defaultdict(list)

for path in all_files:
    for lineno, line in enumerate(read(path).splitlines(), 1):
        for code in CODE_RE.findall(line):
            code_locations[code].append(
                f"{path.relative_to(ROOT)}:{lineno}"
            )

canonical_codes = sorted(code_locations)

# Registry duplicate detection should be semantic rather than
# treating every use of a code as a duplicate.
registry = ROOT / "lib/diagnostics/diagnostic_registry.ml"

registry_codes = []

if registry.exists():
    registry_codes = CODE_RE.findall(read(registry))

seen = set()
duplicate_registry_codes = set()

for code in registry_codes:
    if code in seen:
        duplicate_registry_codes.add(code)
    seen.add(code)

for code in sorted(duplicate_registry_codes):
    errors.append(
        f"duplicate code in diagnostic registry: {code}"
    )

# malformed VF-looking identifiers in diagnostics
diag_dir = ROOT / "lib/diagnostics"

if diag_dir.exists():
    for path in diag_dir.rglob("*"):
        if path.suffix not in {".ml", ".mli"}:
            continue

        for token in ANY_VF_RE.findall(read(path)):
            if not re.fullmatch(r"(?:VF|VFW)[0-9]{4}", token):
                warnings.append(
                    f"non-canonical VF token: {token} "
                    f"({path.relative_to(ROOT)})"
                )

# ------------------------------------------------------------
# Constructor usage
# ------------------------------------------------------------

error_constructors = constructors(ERROR_MLI)
warning_constructors = constructors(WARNING_MLI)


def occurrence_count(name):
    pattern = re.compile(rf"\b{re.escape(name)}\b")
    count = 0

    for path in all_files:
        count += len(pattern.findall(read(path)))

    return count


constructor_report = []

for family, values in (
    ("ERROR", error_constructors),
    ("WARNING", warning_constructors),
):
    for name in values:
        count = occurrence_count(name)

        # mli declaration + implementation mapping usually means
        # two occurrences without a producer.
        if count <= 2:
            status = "POSSIBLY_NOT_EMITTED"
            warnings.append(
                f"{family} {name} may never be emitted"
            )
        else:
            status = "USED"

        constructor_report.append(
            (family, name, count, status)
        )

# ------------------------------------------------------------
# Pipeline presence
# ------------------------------------------------------------

required_modules = {
    "Diagnostic": ROOT / "lib/diagnostics/diagnostic.ml",
    "Error": ROOT / "lib/diagnostics/error.ml",
    "Warning": ROOT / "lib/diagnostics/warning.ml",
    "Reporter": ROOT / "lib/diagnostics/reporter.ml",
    "Parser diagnostics": ROOT / "lib/parser/parse.ml",
    "Analyzer": ROOT / "lib/semantic/analyzer.ml",
    "Validator": ROOT / "lib/semantic/validator.ml",
    "Resolver": ROOT / "lib/semantic/resolver.ml",
    "Loader": ROOT / "lib/config/loader.ml",
}

for name, path in required_modules.items():
    if not path.exists():
        errors.append(
            f"missing diagnostic pipeline component: {name}: "
            f"{path.relative_to(ROOT)}"
        )

# ------------------------------------------------------------
# check.ml integration
# ------------------------------------------------------------

check = ROOT / "bin/check.ml"

if check.exists():
    check_source = read(check)

    required_calls = [
        "Vfconf.Parse",
        "Vfconf.Validator",
        "Vfconf.Diagnostic",
    ]

    for call in required_calls:
        if call not in check_source:
            errors.append(
                f"vfconf-check is not connected to {call}"
            )
else:
    errors.append("bin/check.ml missing")

# ------------------------------------------------------------
# Detect duplicated parser diagnostic messages
# ------------------------------------------------------------

parse = ROOT / "lib/parser/parse.ml"

if parse.exists():
    source = read(parse)

    formatted_unexpected_token_patterns = [
        r'Unexpected_token\s*\(\s*Printf\.sprintf',
        r'Unexpected_token\s*\(\s*Format\.asprintf',
        r'Unexpected_token\s*\(\s*Error\.message',
        r'unexpected_token\s*\(\s*Printf\.sprintf',
        r'unexpected_token\s*\(\s*Format\.asprintf',
        r'unexpected_token\s*\(\s*Error\.message',
    ]

    for pattern in formatted_unexpected_token_patterns:
        if re.search(pattern, source, re.MULTILINE):
            errors.append(
                "parser diagnostic passes an already formatted "
                "message as Unexpected_token"
            )
            break

# ------------------------------------------------------------
# Report
# ------------------------------------------------------------

print("VFCONF FINAL DIAGNOSTIC AUDIT")
print("=" * 72)

print()
print("Canonical codes discovered:", len(canonical_codes))

for code in canonical_codes:
    print(f"  {code}")

print()
print("Error constructors:", len(error_constructors))
print("Warning constructors:", len(warning_constructors))

print()
print("CONSTRUCTOR AUDIT")
print("-" * 72)

for family, name, count, status in constructor_report:
    print(
        f"{family:8} "
        f"{status:23} "
        f"{name}"
    )

used_errors = sum(
    1 for family, _, _, status in constructor_report
    if family == "ERROR" and status == "USED"
)

used_warnings = sum(
    1 for family, _, _, status in constructor_report
    if family == "WARNING" and status == "USED"
)

print()
print(
    f"ERROR COVERAGE:   {used_errors}/{len(error_constructors)}"
)
print(
    f"WARNING COVERAGE: {used_warnings}/{len(warning_constructors)}"
)

print()
print("WARNINGS")
print("-" * 72)

if warnings:
    for warning in warnings:
        print(f"WARNING: {warning}")
else:
    print("none")

print()
print("ERRORS")
print("-" * 72)

if errors:
    for error in errors:
        print(f"ERROR: {error}")
else:
    print("none")

print()
print("=" * 72)

if errors:
    print(
        f"FINAL STATUS: FAILED "
        f"({len(errors)} errors, {len(warnings)} warnings)"
    )
    sys.exit(1)

print(
    f"FINAL STATUS: OK "
    f"({len(warnings)} warnings)"
)
