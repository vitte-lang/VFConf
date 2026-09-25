#!/usr/bin/env python3

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent

ERROR_FILE = ROOT / "lib/diagnostics/error.ml"
WARNING_FILE = ROOT / "lib/diagnostics/warning.ml"

SCAN_DIRS = [
    ROOT / "lib",
    ROOT / "bin",
    ROOT / "tests",
]

EXCLUDED = {
    ERROR_FILE.resolve(),
    (ROOT / "lib/diagnostics/error.mli").resolve(),
    WARNING_FILE.resolve(),
    (ROOT / "lib/diagnostics/warning.mli").resolve(),
}


def read(path):
    return path.read_text(errors="replace")


def source_files():
    result = []

    for directory in SCAN_DIRS:
        if not directory.exists():
            continue

        for extension in ("*.ml", "*.mli", "*.mly", "*.mll"):
            for path in directory.rglob(extension):
                if path.resolve() not in EXCLUDED:
                    result.append(path)

    return sorted(set(result))


def extract_error_mapping():
    source = read(ERROR_FILE)

    match = re.search(
        r"let\s+code_of_kind\s*=\s*function(.*?)(?=\n\(\*\s*-+\s*\*\)\n\(\*\s*Messages)",
        source,
        re.S,
    )

    if not match:
        raise RuntimeError("cannot extract Error.code_of_kind")

    mapping = []

    for constructor, code in re.findall(
        r"\|\s*([A-Z][A-Za-z0-9_]*)"
        r"(?:\s+_[^\n]*)?\s*->\s*"
        r'"(VF[0-9]{4})"',
        match.group(1),
    ):
        mapping.append((code, constructor))

    return mapping


def extract_warning_mapping():
    source = read(WARNING_FILE)

    match = re.search(
        r"let\s+code_of_kind\s*=\s*function(.*?)(?=\n\(\*\s*-+\s*\*\)\n\(\*\s*Messages)",
        source,
        re.S,
    )

    if not match:
        raise RuntimeError("cannot extract Warning.code_of_kind")

    mapping = []

    for constructor, code in re.findall(
        r"\|\s*([A-Z][A-Za-z0-9_]*)"
        r"(?:\s+_[^\n]*)?\s*->\s*"
        r'"(VFW[0-9]{4})"',
        match.group(1),
    ):
        mapping.append((code, constructor))

    return mapping


def snake_case(name):
    return re.sub(
        r"(?<!^)(?=[A-Z])",
        "_",
        name,
    ).lower()


FILES = source_files()


def producer_locations(module, constructor):
    helper = snake_case(constructor)

    patterns = [
        re.compile(
            rf"\b{re.escape(module)}\.{re.escape(constructor)}\b"
        ),
        re.compile(
            rf"\b{re.escape(module)}\.{re.escape(helper)}\b"
        ),
    ]

    locations = []

    for path in FILES:
        lines = read(path).splitlines()

        for lineno, line in enumerate(lines, 1):
            if any(pattern.search(line) for pattern in patterns):
                locations.append(
                    f"{path.relative_to(ROOT)}:{lineno}"
                )

    return locations


errors = extract_error_mapping()
warnings = extract_warning_mapping()

diagnostics = (
    [("ERROR", "Error", code, constructor)
     for code, constructor in errors]
    +
    [("WARNING", "Warning", code, constructor)
     for code, constructor in warnings]
)

results = []

for family, module, code, constructor in diagnostics:
    locations = producer_locations(module, constructor)

    results.append(
        (
            family,
            code,
            constructor,
            locations,
        )
    )


print("VFCONF DIAGNOSTIC PRODUCER AUDIT")
print("=" * 88)
print()

for family, code, constructor, locations in results:
    status = "PRODUCER" if locations else "NO_PRODUCER"

    print(
        f"{code:8} "
        f"{family:8} "
        f"{status:12} "
        f"{constructor}"
    )

    for location in locations:
        print(f"         -> {location}")


error_total = sum(
    1 for family, _, _, _ in results
    if family == "ERROR"
)

warning_total = sum(
    1 for family, _, _, _ in results
    if family == "WARNING"
)

error_produced = sum(
    1 for family, _, _, locations in results
    if family == "ERROR" and locations
)

warning_produced = sum(
    1 for family, _, _, locations in results
    if family == "WARNING" and locations
)

missing = [
    (family, code, constructor)
    for family, code, constructor, locations in results
    if not locations
]

print()
print("=" * 88)
print(
    f"ERROR PRODUCERS:   {error_produced}/{error_total}"
)
print(
    f"WARNING PRODUCERS: {warning_produced}/{warning_total}"
)
print(
    f"TOTAL PRODUCERS:   "
    f"{error_produced + warning_produced}/"
    f"{error_total + warning_total}"
)

print()
print("MISSING PRODUCERS")
print("-" * 88)

if not missing:
    print("none")
else:
    for family, code, constructor in missing:
        print(
            f"{code:8} {family:8} {constructor}"
        )

print()
print("=" * 88)

if missing:
    print(
        f"FINAL STATUS: INCOMPLETE "
        f"({len(missing)} diagnostics without producer)"
    )
    sys.exit(1)

print("FINAL STATUS: OK")
