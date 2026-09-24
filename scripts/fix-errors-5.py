from pathlib import Path
import re

ROOT = Path("/Users/vincent/Documents/ucl-lang/vfconf")


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def write(path, data):
    (ROOT / path).write_text(data, encoding="utf-8")


# ============================================================
# 1. ast.ml
# Record ambiguity in dump_statement.
# ============================================================

path = "lib/ast/ast.ml"
s = read(path)

s, n = re.subn(
    r'let rec dump_statement formatter depth located_statement =',
    'let rec dump_statement formatter depth '
    '(located_statement : statement located) =',
    s
)

write(path, s)
print(f"[ast] dump_statement annotations: {n}")


# ============================================================
# 2. field.ml
# API:
# Error.to_diagnostic_with_notes : ?notes:string list -> ...
#
# Rewrite both positional note lists as ~notes:[...].
# ============================================================

path = "lib/schema/field.ml"
s = read(path)

# Only inside diagnostic_of_validation_error.
start = s.index("let diagnostic_of_validation_error")
end = s.index(
    "(* ---------------------------------------------------------- *)",
    start + 10
)

before = s[:start]
block = s[start:end]
after = s[end:]

# Transform:
#   Error.to_diagnostic_with_notes
#     (Error.make ...)
#     [ ... ]
#
# to:
#   Error.to_diagnostic_with_notes
#     ~notes:[ ... ]
#     (Error.make ...)
#
pattern = re.compile(
    r'''Error\.to_diagnostic_with_notes
(?P<indent>\s+)
(?P<error>\(Error\.make.*?\)\))
\s+
(?P<notes>\[
.*?
\s*\])''',
    re.DOTALL
)

def notes_replacement(m):
    indent = m.group("indent")
    error = m.group("error")
    notes = m.group("notes")

    return (
        "Error.to_diagnostic_with_notes"
        + indent
        + "~notes:"
        + notes
        + indent
        + error
    )

block, n = pattern.subn(notes_replacement, block)

write(path, before + block + after)
print(f"[field] labelled notes conversions: {n}")


# ============================================================
# 3. reporter.ml
#
# pp reporter : formatter -> unit
# Therefore Format.asprintf must use %t, not %a.
# ============================================================

path = "lib/diagnostics/reporter.ml"
s = read(path)

start = s.index("let to_string reporter =")
end = s.index("\nlet ", start + 5)

replacement = '''let to_string reporter =
  Format.asprintf
    "%t"
    (pp reporter)
'''

s = s[:start] + replacement + s[end:]

# print reporter must not call pp with ().
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

write(path, s)
print("[reporter] to_string uses %t")


# ============================================================
# 4. analyzer.ml
#
# state ambiguity: state.symbols inferred from another record.
# Annotate semantic state functions.
# ============================================================

path = "lib/semantic/analyzer.ml"
s = read(path)

replacements = {
    "let add_diagnostic diagnostic state =":
        "let add_diagnostic diagnostic (state : state) =",

    "let add_error ?span kind state =":
        "let add_error ?span kind (state : state) =",

    "let duplicate_key path span state =":
        "let duplicate_key path span (state : state) =",

    "let duplicate_definition name span state =":
        "let duplicate_definition name span (state : state) =",

    "let undefined_reference path span state =":
        "let undefined_reference path span (state : state) =",

    "let add_configuration_symbol path value span state =":
        "let add_configuration_symbol path value span (state : state) =",
}

for old, new in replacements.items():
    s = s.replace(old, new)

write(path, s)
print("[analyzer] state annotations applied")


# ============================================================
# 5. resolver.ml
# Replace the nonexistent Error.Reference_cycle constructor.
# ============================================================

path = "lib/semantic/resolver.ml"
s = read(path)

s, n = re.subn(
    r'Error\.Reference_cycle',
    'Error.Invalid_reference',
    s
)

write(path, s)
print(f"[resolver] Reference_cycle replacements: {n}")


# ============================================================
# 6. parse.ml
# Node.span ?filename start_pos end_pos
# ============================================================

path = "lib/parser/parse.ml"
s = read(path)

s, n1 = re.subn(
    r'~start_pos:\s*\n\s*(\([^\n]+\))',
    r'\1',
    s
)

s, n2 = re.subn(
    r'~end_pos:\s*\n\s*(\([^\n]+\))',
    r'\1',
    s
)

write(path, s)
print(f"[parse] start_pos labels removed: {n1}")
print(f"[parse] end_pos labels removed: {n2}")


# ============================================================
# Final checks
# ============================================================

print()
print("Remaining Error.Reference_cycle:",
      read("lib/semantic/resolver.ml").count("Error.Reference_cycle"))

print("Remaining ~start_pos:",
      read("lib/parser/parse.ml").count("~start_pos:"))

print("Remaining ~end_pos:",
      read("lib/parser/parse.ml").count("~end_pos:"))
