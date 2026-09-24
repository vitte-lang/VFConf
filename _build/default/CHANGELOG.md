# VFConf Changelog

All notable changes to **VFConf — Vitte Foundation Configuration Language** are documented in this file.

The format follows the principles of Keep a Changelog and semantic versioning.

---

## [Unreleased]

### Added

- Initial VFConf compiler and tooling architecture.
- OCaml implementation using `ocamllex` and Menhir.
- Source position and span tracking.
- Structured diagnostics with errors, warnings, labels, notes, and fixes.
- Semantic analysis and symbol environments.
- Reference resolution.
- Schema validation infrastructure.
- Configuration loading and merging.
- Conditional configuration evaluation.
- Canonical formatter and printer.
- Filesystem, path, and string utility modules.
- Support for `.vf.conf` configuration files.
- MIME type `text/x-vfconf`.
- Language identifier `vfconf`.

### Language

- Sections using `[section.name]`.
- Assignments:
  - `=`
  - `:=`
  - `+=`
  - `-=`
- Includes with `include`.
- Definitions with `define`.
- Conditional blocks with `when` and `else`.
- References using `$identifier.path`.
- Logical operators:
  - `&&`
  - `||`
  - `!`
- Comparison operators:
  - `==`
  - `!=`
  - `<`
  - `<=`
  - `>`
  - `>=`
- Arrays.
- Objects.
- Strings.
- Signed integers.
- Floating-point numbers.
- Booleans:
  - `true`
  - `false`
  - `on`
  - `off`
- Null values:
  - `null`
  - `none`
- Color literals.
- `rgb(...)` and `rgba(...)` colors.
- Duration literals:
  - `ns`
  - `us`
  - `ms`
  - `s`
  - `min`
  - `h`
- Size literals:
  - `B`
  - `KB`
  - `MB`
  - `GB`
  - `KiB`
  - `MiB`
  - `GiB`
- Line and block comments.
- Semicolon and newline statement termination.

### Tooling

- `vfconf`
- `vfconf-check`
- `vfconf-dump`
- `vfconf-fmt`

### Schemas

Added canonical schemas for:

- `syntax.schema.vf.conf`
- `theme.schema.vf.conf`
- `editor.schema.vf.conf`
- `language.schema.vf.conf`
- `keymap.schema.vf.conf`

### Configuration

Initial configuration definitions for:

- syntax
- editor
- terminal
- keymaps
- formatter
- diagnostics
- LSP
- build
- runtime

### Language Definitions

Initial infrastructure for language-specific `.vf.conf` definitions, including:

- Vitte
- VFConf
- C
- C++
- Rust
- OCaml
- Zig
- Go
- Python
- JavaScript
- TypeScript
- Java
- C#
- Swift
- Kotlin
- PHP
- Ruby
- Lua
- Bash
- Assembly

### Themes

Initial theme infrastructure for:

- Default
- Dark
- Light
- High Contrast

---

## [0.1.0] - 2026-09-24

### Added

- Created the VFConf project.
- Defined `.vf.conf` as the canonical file extension.
- Defined `vfconf` as the canonical language identifier.
- Defined `text/x-vfconf` as the MIME type.
- Added the initial EBNF grammar.
- Added lexical and literal grammar specifications.
- Added AST infrastructure.
- Added lexer infrastructure.
- Added Menhir parser infrastructure.
- Added source position and span representation.
- Added diagnostic infrastructure.
- Added semantic analysis infrastructure.
- Added configuration loading.
- Added include resolution.
- Added configuration merging.
- Added value and condition evaluation.
- Added schema infrastructure.
- Added formatter infrastructure.
- Added utility modules.
- Added initial Dune build configuration.

