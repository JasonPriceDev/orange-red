# FORMAT.md — SPEC.md encoding rules

`SPEC.md` is the durable project memory. It uses a compact, caveman-encoded
format. This file pins the exact shape so every `spec` write is consistent.

## Sections and order

Fixed order. Omit `§R` when no research ran. All others always present.

| Section | Meaning |
|---|---|
| `§G` | Goal — one line, caveman. |
| `§C` | Constraints — non-negotiables, exclusions, known unknowns (`?`). |
| `§I` | Interfaces — CLI, files, config keys, env vars, schemas, APIs. |
| `§R` | Research — sourced facts, pipe table. Optional. |
| `§V` | Invariants — testable rules. Numbered `V1`, `V2`, … |
| `§T` | Tasks — ordered pipe table. |
| `§B` | Bugs — pipe table, header row always present. |

## Caveman encoding

- Drop articles (a/an/the), filler, pleasantries, hedging. Fragments OK.
- Preserve verbatim: identifiers, file paths, code, CLI commands, config keys,
  env vars, API names, error strings, URLs.
- No decorative tables or emoji. No causal arrows (`→`). No invented
  abbreviations — full words tokenize the same and read clearer.
- Standard tech acronyms fine (DB, API, HTTP, URL, PDF).

## Numbering

- Monotonic. Never reuse `V<N>`, `T<N>`, `B<N>` after retirement.
- Retired invariants stay in the table marked `RETIRED` — id is not recycled.

## `§V` shape

One numbered line per invariant. Testable, single rule.

```
V1 | one page maps to exactly one concept file
V2 | every non-reserved .md parses as frontmatter + body, type non-empty
```

## `§T` pipe table

```
id | status | task | cites
T1 | . | scaffold crawler | V3,I.cli
```

- `status`: `.` pending, `~` in progress, `x` done.
- `cites`: comma list of `§V`/`§I` deps (e.g. `V2,I.okf`). Empty allowed.
- Rows small enough to build and verify independently.

## `§B` pipe table

Header row always present even when empty.

```
id | date | cause | fix
B1 | 2026-07-08 | extractor crashed on empty PDF | V9
```

- `date`: ISO 8601 `YYYY-MM-DD`.
- `fix`: `§V` id that prevents recurrence, or short prose when no invariant.

## Ownership

`spec` is the sole writer. `grill`/`research`/`review`/`deepen` propose material
into the section they own; they never write `SPEC.md` directly.
