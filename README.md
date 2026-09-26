# VFConf

VFConf is a typed configuration language and OCaml library with sections, references, conditions, includes, schemas, diagnostics and deterministic formatting.

## Installation

Requires OCaml 5.1+ and Dune 3.

```sh
opam install . --deps-only
dune build @all
opam install .
```

## Quick start

```vfconf
# A comment (a space after # is intentional)
[server]
host = "127.0.0.1"
port = 8080
timeout = 250ms
accent = #ff8800
when $server.port >= 1024 { workers = 4 }
```

```sh
vfconf-check config.vf.conf
vfconf-fmt --write config.vf.conf
cat config.vf.conf | vfconf-fmt -
```

## Language

Values include strings, booleans, signed integers, floats, colors (`#rrggbb`), sizes (`4MiB`), durations (`250ms`), arrays and objects. Arithmetic, comparison and logical operators are supported. Sections are hierarchical until the next section declaration; references use `$name` or `$section.name`.

`#` starts a comment only when followed by whitespace or end-of-line; compact forms such as `#aabbcc` are colors. `//` and nested `/* ... */` comments are also accepted. See [grammar/README.md](grammar/README.md) for the complete syntax and precedence.

Includes (`include "file.vf.conf"`) are canonicalised and confined to a security root; symlinks are rejected by default, repeated includes are reported and cycles show their full path trace. Configure `security_root`, `allow_symlinks` and `maximum_include_depth` in the library. Schemas support types, required fields, defaults, deprecations and additional-field policy.

## Diagnostics and CLI

Diagnostics have stable codes, severity and source spans; all 31 error and 30 warning constructors are audited.

```sh
vfconf-check --json file.vf.conf
vfconf-check --editor file.vf.conf
vfconf-check --quiet file.vf.conf
vfconf-check --color=auto file.vf.conf   # auto, always, never
```

`-` reads standard input. Exit status is zero on success. `vfconf-fmt --check` verifies canonical output; formatting is idempotent and preserves comments verbatim.

## OCaml API

Use the result-based `Vfconf.Api` façade (`parse`, `check`, `format`, `load`). Results contain `Diagnostic.t list`; library functions never call `exit`. Lower-level lexer, parser, evaluator, loader and schema modules remain available.

## Development and releases

```sh
dune build @all
dune runtest
scripts/test.sh --no-format
python3 scripts/audit-diagnostic-producers.py
```

CI runs property tests, short fuzzing, formatting checks, diagnostic audits and builds on Linux, macOS and Windows with multiple OCaml versions. Release archives contain manifests and SHA-256 checksums and exclude AppleDouble `._*` files. macOS signing/notarisation is opt-in with `--sign-identity`, `--notarize` and `--notary-profile`.

See [grammar/README.md](grammar/README.md), [CHANGELOG.md](CHANGELOG.md) and [docs/](docs/).
