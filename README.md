# VFConf

## VFConf is a structured configuration language designed for strict, predictable, and reliable configuration files.

It provides a configuration format with a real language frontend, explicit syntax rules, structured diagnostics, precise source locations, and deterministic parsing.

## VFConf is intended for projects that need more structure and validation than a simple key/value configuration format while remaining focused on configuration rather than general-purpose programming.

- What is VFConf?

# VFConf is a language for describing application, tool, service, compiler, build-system, and project configuration.

A VFConf document is not treated as an arbitrary collection of text.

It is processed as a structured source file with:

* lexical rules;
* a defined grammar;
* typed syntax structures;
* source locations;
* validation rules;
* errors and warnings;
* stable diagnostic identifiers.

The objective is to make configuration files behave more like well-defined source files than loosely interpreted data.

Why VFConf?

Configuration formats are often simple when a project starts but become increasingly complex as the project grows.

A configuration system may eventually need:

* nested structures;
* reusable configuration;
* multiple files;
* validation;
* dependencies between settings;
* precise errors;
* tooling;
* compatibility rules;
* static analysis.

Adding these features to an initially simple format can result in ambiguous syntax, inconsistent validation, and poor error messages.

VFConf is designed with these requirements in mind from the beginning.

Strict by design

VFConf follows a strict parsing model.

Invalid syntax should not be silently accepted, automatically corrected, or interpreted differently depending on context.

A configuration is expected to have one deterministic interpretation.

The language therefore favors explicit constructs and well-defined grammar rules over permissive parsing.

Configuration as a language

VFConf treats configuration as a small domain-specific language.

A VFConf source follows a complete frontend pipeline:

VFConf source
      │
      ▼
Lexical analysis
      │
      ▼
    Parsing
      │
      ▼
      AST
      │
      ▼
  Validation
      │
      ▼
Configuration model

This architecture separates syntax from validation and allows each stage to report structured information about the source.

Structured configuration

VFConf is intended to represent structured configuration rather than only flat key/value pairs.

The language can model configuration belonging to different parts of a project while keeping their relationships explicit.

A configuration can therefore describe concepts such as:

project
application
compiler
runtime
server
environment
module
tool
build
target
package

These are examples of domains VFConf can represent rather than special restrictions on what VFConf may configure.

Multiple configuration files

Large configurations should not require one monolithic file.

VFConf is designed around the possibility of separating configuration into multiple source files and composing them through explicit language constructs such as includes.

This allows a project to organize configuration according to responsibility while keeping the resulting configuration deterministic.

Diagnostics

Diagnostics are a fundamental part of VFConf.

Instead of returning generic parsing failures, VFConf associates problems with structured diagnostics.

A diagnostic can identify:

* what happened;
* where it happened;
* its severity;
* its diagnostic category;
* the relevant source location.

VFConf diagnostics use stable identifiers in the VFxxxx namespace.

This provides a common diagnostic model for lexical analysis, parsing, validation, and future tooling.

Errors and warnings

VFConf distinguishes between different levels of diagnostic severity.

An error represents a condition that prevents the configuration from being considered valid.

A warning represents a condition that may be valid but deserves attention.

Both belong to the same diagnostic infrastructure so every component of VFConf reports problems consistently.

Source locations

VFConf preserves source information throughout the frontend.

Tokens, syntax structures, and diagnostics can remain associated with their original positions in a source file.

This makes it possible to identify the exact region responsible for a problem instead of reporting only that the configuration is invalid.

Source tracking is also an important foundation for editor integration and static-analysis tooling.

Deterministic parsing

VFConf aims for predictable behavior.

The same valid source should produce the same syntax structure and configuration interpretation.

The language avoids relying on heuristics to determine what a configuration probably means.

This is particularly important when VFConf is used for build systems, compilers, infrastructure, services, or other environments where configuration ambiguity can produce difficult-to-diagnose behavior.

Validation

Parsing and validation are separate concepts in VFConf.

A source file can contain syntactically correct constructs that are still invalid according to configuration rules.

VFConf therefore distinguishes between several classes of problems:

Source
  │
  ├── Lexical validity
  │
  ├── Syntax validity
  │
  ├── Structural validity
  │
  └── Semantic validity

This separation allows diagnostics to describe the actual class of problem instead of reducing every failure to a syntax error.

Tooling-oriented architecture

VFConf is designed so that its frontend can be reused by development tools.

The language architecture exposes the concepts necessary for future integrations:

* tokens;
* syntax structures;
* AST nodes;
* source spans;
* diagnostics;
* severity levels;
* diagnostic identifiers;
* validation results.

This foundation can support tooling such as editors, language servers, static analyzers, formatters, configuration inspectors, and IDE integrations.

Intended use cases

VFConf can be used wherever a project requires structured and validated configuration.

Typical use cases include:

* application configuration;
* compiler configuration;
* build configuration;
* development tools;
* project metadata;
* server configuration;
* runtime configuration;
* module configuration;
* package configuration;
* environment definitions;
* infrastructure tooling;
* custom developer tools.

VFConf is not tied to a particular operating system, application, or programming language.

What VFConf is not

VFConf is not intended to become a general-purpose programming language.

Its primary responsibility is configuration.

The language may provide constructs useful for organizing, validating, or composing configuration, but these features should remain consistent with that purpose.

VFConf also does not aim to replace every existing configuration format.

Simple formats remain appropriate when configuration consists of a few basic values.

VFConf targets cases where configuration has enough structure that grammar, validation, diagnostics, and tooling become useful.

Design principles

VFConf is developed around several core principles:

Strictness

Invalid input should be detected instead of silently interpreted.

Determinism

A configuration should have one predictable interpretation.

Explicitness

Important configuration behavior should be represented explicitly in the source.

Diagnostics

Errors should explain both the problem and its location.

Structure

Configuration should have a defined syntax tree rather than being interpreted as loosely structured text.

Validation

Syntactic correctness and configuration correctness should remain separate concepts.

Toolability

The language should expose enough structured information for editors and development tools.

Scalability

The configuration model should remain manageable as projects and configuration files grow.

Architecture

VFConf is organized as a language frontend with independent responsibilities:

                    VFConf
                      │
              ┌───────┴───────┐
              │               │
           Language         Diagnostics
              │               │
        ┌─────┼─────┐         │
        │     │     │         │
      Lexer Parser  AST       │
              │               │
              └───────┬───────┘
                      │
                  Validation
                      │
                      ▼
              Configuration Model

Keeping these components separate prevents parsing, validation, and diagnostic logic from becoming tightly coupled.

Project status

VFConf is currently in early development.

The 0.x series defines and stabilizes the language, grammar, configuration model, diagnostics, and tooling architecture.

Until VFConf reaches a stable release, parts of the syntax and internal representation may evolve as the language specification becomes more complete.
## Example

```vfconf

[comments] 
line = ["//"]
block = ["/*", "*/"]
nested_block = false
documentation = ["//"]
  
[strings]
double_quote = true
escape = "\\" 
multiline = false

[strings.raw]
enabled = true
start = "`"
end = "`"
escape_sequences = false
multiline = true
```
Current release

VFConf 0.1.0

The first release establishes the initial VFConf language frontend and the foundations required for future development.

The project will progressively expand the configuration model, validation capabilities, diagnostics, and tooling while preserving the core objective:

Make configuration strict, predictable, understandable, and toolable.
See [grammar/README.md](grammar/README.md), [CHANGELOG.md](CHANGELOG.md) and [docs/](docs/).
