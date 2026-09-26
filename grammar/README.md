# VFConf language specification

`vfconf.ebnf` is the canonical syntactic grammar. `lexical.ebnf` and
`literals.ebnf` expand the lexical and literal rules used by the lexer.

## `#`: comments and colors

The two forms are deliberately separated:

```vfconf
# This is a comment because whitespace follows the hash.
foreground = #d4d4d4
short = #fff
alpha = #112233cc
```

A hash comment must be a bare `#` or have horizontal whitespace immediately
after `#`. A compact `#...` token is reserved for a hexadecimal color and must
contain exactly 3, 4, 6, or 8 hexadecimal digits. Therefore `#comment` and
`#12` are lexical errors. `// comment` and `/* comment */` remain available
when a comment without the hash-space convention is preferable.

This rule removes dependence on lexer longest-match behaviour. A color may be
followed by a comment using `//`:

```vfconf
accent = #ff8800 // orange
```

## Numbers

Decimal integers and floats accept an optional leading `+` or `-` and `_`
separators. Floats support decimal points and scientific notation:

```vfconf
workers = 4
offset = -12
ratio = +0.25
threshold = 1e-6
mask = 0xff
permissions = 0o755
bits = 0b1010
```

Signs are part of decimal literals. Non-decimal integers do not accept a sign.
Whitespace is not allowed between a sign, number, and unit.

## Units

Duration units are `ns`, `us`, `ms`, `s`, `min`, and `h`. Size units are `B`,
`KB`, `MB`, `GB`, `KiB`, `MiB`, and `GiB`. Unit spelling and case are exact:

```vfconf
timeout = 250ms
retention = 2h
memory = 256MiB
```

`m` is not a duration unit; minutes use `min`. Decimal SI units and binary IEC
units remain distinct.

## Assignment operators

- `=` sets a value and may replace one during direct evaluation.
- `:=` defines a value only when the key is absent.
- `+=` appends arrays/strings or adds numeric values.
- `-=` removes array elements or subtracts numeric values.

`+=` and `-=` require an existing compatible value. Mixed integer/float
arithmetic produces a float and an implicit-conversion warning.

## Section scope

A section header applies to following non-section statements until the next
section header, the end of the current conditional block, or end of file.
Section paths compose with assignment paths:

```vfconf
[server.http]
port = 8080       // server.http.port
tls.enabled = true // server.http.tls.enabled
```

Assignments inside a conditional inherit the surrounding section. Section
headers are top-level constructs and are not permitted inside conditional
blocks.

## Conditions

Conditions begin with `when` and optionally have an `else` branch. They accept
boolean literals, references, comparisons, `!`, `&&`, `||`, and parentheses.
Precedence from strongest to weakest is `!`, comparisons, `&&`, then `||`.

```vfconf
when $server.enabled && ($environment != "test") {
  workers += 2
} else {
  debug = true
}
```

References use `$` and can address a definition or configuration path.
Undefined references are errors. Literal conditions are accepted but produce
an always-true/always-false warning; an always-false branch is unreachable.
