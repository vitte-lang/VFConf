# VFConf Diagnostic Codes

VFConf diagnostic codes are stable public identifiers.

## Families

| Range | Family |
|---|---|
| VF0001–VF0099 | Lexical |
| VF0100–VF0199 | Syntax |
| VF0200–VF0299 | Semantic |
| VF0300–VF0399 | Reference |
| VF0400–VF0499 | Include / Loader |
| VF0500–VF0599 | Schema |
| VF0600–VF0699 | Evaluation |
| VF0700–VF0799 | Configuration |
| VF0800–VF0899 | Style / Formatting |
| VF0900–VF0999 | Compatibility / Deprecation |
| VF9000–VF9099 | I/O |
| VF9900–VF9999 | Internal |

A diagnostic code must:

1. be unique;
2. remain stable once published;
3. have one canonical meaning;
4. have one canonical severity policy;
5. preserve source spans whenever available;
6. never be silently reused for another error.

## Diagnostic model

A full diagnostic may contain:

- severity
- code
- category
- source component
- message
- primary span
- primary label
- secondary labels
- notes
- help
- related locations
- fixes
- fix applicability

## Fix applicability

- `Machine_applicable`
- `Maybe_incorrect`
- `Has_placeholders`
- `Unspecified`

Machine-applicable fixes must be safe without human interpretation.
