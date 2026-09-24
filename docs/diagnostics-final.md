# VFConf Final Diagnostic Architecture

The canonical diagnostic pipeline is:

Source
→ Lexer
→ Parser
→ Loader
→ Analyzer
→ Resolver
→ Validator
→ Schema
→ Evaluator
→ Diagnostic
→ Reporter
→ CLI / machine consumers

## Requirements

A canonical diagnostic may provide:

- severity
- stable diagnostic code
- canonical English message
- exact source span
- primary label
- secondary labels
- notes
- help
- related source locations
- zero or more fixes
- fix applicability
- originating component
- diagnostic category

## Rules

Diagnostic codes are public stable identifiers.

A published code must never be silently reused for another meaning.

Source positions must be preserved whenever the frontend has the
corresponding Lexing.position or Node.span.

CLI programs must not duplicate canonical Error, Warning or Diagnostic
message construction.

Machine-applicable fixes must be safe to perform without human
interpretation.

Compiler warnings and Menhir conflicts must not be suppressed merely
to make the diagnostics gate pass.

## Final verification

Run:

    ./scripts/check-diagnostics.sh

A release should not be considered diagnostics-clean unless this gate
passes.
