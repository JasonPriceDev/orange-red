# AI Development Workflow Guide

This guide defines how AI-assisted development is conducted on **orange-red**.
It follows the Cavekit workflow: clarify the idea, write or amend `SPEC.md`,
review the spec when risk is high, build against the spec, check for drift, and
backpropagate bugs into the spec so they do not recur.

This document is intentionally written in normal English. Cavekit skills may use
compressed output internally, but project documentation should remain clear and
readable.

---

## 0. Project decisions

These decisions are settled unless a later spec change explicitly revises them.

| Topic | Decision |
|---|---|
| Crawler engine | **Scrapy** for depth limits, delays, autothrottle, robots.txt, retries, and deduplication. |
| Concept `type` | **Heuristic classification**, such as `Documentation`, `Article`, or `PDF`. One page maps to one concept. |
| Authentication | **None** for the initial crawler. Public pages only. |
| Crawl mode | **Incremental**. Re-crawls update existing bundle files and append to `log.md`; they do not create a fresh bundle by default. |
| Graph visualization | **Deferred**. `viz.html` and Cytoscape are out of scope for the initial phases. |
| Backend | Python 3.14, PostgreSQL 15+, Docker, and the existing dev-container stack. |

---

## 1. Cavekit workflow overview

Cavekit is a specification-driven workflow. The central artifact is `SPEC.md` at
the repository root. Code is planned, built, reviewed, and repaired against that
file.

Use the Cavekit skills this way:

| Situation | Skill | Purpose |
|---|---|---|
| The idea is vague or has multiple possible interpretations. | `grill` | Ask targeted questions before a spec exists. |
| The spec depends on external library, API, or best-practice facts. | `research` | Produce sourced findings for `§R`. |
| A new feature or contract needs to be specified. | `spec` | Create or amend `SPEC.md`. This is the only skill that should write spec content. |
| The change has high blast radius. | `review` | Try to refute the spec before implementation starts. |
| The spec is ready to implement. | `build` | Implement `§T` tasks, verify them, and update task status. |
| Code may have drifted from the spec. | `check` | Read-only drift report for `§V`, `§I`, and `§T`. |
| A bug, failed test, or incident reveals a missing rule. | `backprop` | Add a `§B` bug record and usually a new `§V` invariant. |
| The code is green and there is time to improve design. | `deepen` | Propose interface-shrinking refactors without changing behavior. |

Default sequence for non-trivial work:

1. Use `grill` if the request is ambiguous.
2. Use `research` if the spec depends on facts outside the repository.
3. Use `spec` to create or amend `SPEC.md`.
4. Use `review` before building high-risk changes.
5. Use `build` for one or more `§T` tasks.
6. Use `check` after the build and before shipping.
7. Use `backprop` whenever a bug or failed verification reveals a missing invariant.

Skip steps only when the change is trivial, reversible, and does not touch a
contract, shared module, data model, public interface, or security boundary.

---

## 2. `SPEC.md` structure

`SPEC.md` is the source of truth for what the system should do. Keep it concise,
testable, and current.

Required sections:

| Section | Meaning |
|---|---|
| `§G` | Goal: one clear statement of the intended outcome. |
| `§C` | Constraints: non-negotiable requirements, exclusions, and known unknowns. |
| `§I` | Interfaces: external surfaces such as CLI commands, files, config keys, APIs, schemas, and environment variables. |
| `§R` | Research: sourced facts that the spec relies on. Include only when research was needed. |
| `§V` | Invariants: testable rules that must remain true. These drive tests and verification. |
| `§T` | Tasks: ordered implementation work items with status and citations to relevant `§V` and `§I` entries. |
| `§B` | Bugs: historical bug records and the invariant or fix that prevents recurrence. |

Task rows should be small enough to build and verify independently. A task is
not complete unless its cited invariants have a named verification check.

Use normal project language in surrounding documentation. If `SPEC.md` itself
uses a compact Cavekit format, do not copy that style into user-facing docs.

---

## 3. Clarifying work with `grill`

Use `grill` before writing a spec when the idea is incomplete, ambiguous, or
likely to hide assumptions.

Good candidates for grilling:

- A one-sentence feature request with unclear boundaries.
- A request that could imply multiple product behaviors.
- A change where the definition of done is not observable.
- A request that mentions a technology choice but not why it is required.

The goal of grilling is not to interrogate every detail. Stop once `§G` can be
written in one clear line and the important constraints are known or explicitly
marked as unknown.

---

## 4. Researching external facts with `research`

Use `research` when a specification decision depends on current external facts:
library behavior, API contracts, standards, security guidance, or best practice.

Research output must be sourced. Prefer official documentation, standards,
repository docs, release notes, or primary sources. If a claim cannot be
verified, mark it as uncertain rather than writing it as fact.

Research should answer scoped questions, not produce a broad essay. A useful
research entry is short, cites a source, and directly informs a `§C`, `§I`, or
`§V` decision.

---

## 5. Writing or amending the spec with `spec`

Use `spec` for every change to `SPEC.md`. Other skills may propose content, but
`spec` is the only writer.

A good spec has these properties:

- The goal has one interpretation.
- Every external surface is listed in `§I`.
- Every important behavior is protected by a testable invariant in `§V`.
- Every task in `§T` cites the interfaces or invariants it affects.
- Unknowns are explicitly marked instead of silently guessed.

For orange-red, pay special attention to these project invariants:

- One crawled page maps to exactly one concept file.
- Every non-reserved Markdown concept file parses as YAML frontmatter plus body
  and has a non-empty `type`.
- Re-crawling an existing URL updates its concept and appends to `log.md`; it
  does not duplicate the concept.
- Postgres rows are a rebuildable index of the bundle on disk, not a competing
  source of truth.
- Crawled content is untrusted input and must be validated or sanitized at the
  extraction boundary.

---

## 6. Reviewing the spec with `review`

Use `review` before implementation when a wrong build would be expensive to
undo. Examples include changes to shared modules, public interfaces, persisted
data, migrations, security boundaries, crawl output format, OKF conformance, or
the incremental update model.

The review should try to refute the spec, not approve it by default. Findings
must cite evidence from the codebase, tests, docs, or research sources.

Review outcomes:

- **BLOCK**: the spec would likely ship a defect. Fix the spec before building.
- **HARDEN**: add or sharpen a `§V` invariant so the implementation cannot miss
  an important behavior.
- **NOTE**: useful information that does not block implementation.

Do not use a heavy review pass for trivial, reversible changes. Right-size the
process to the risk.

---

## 7. Building with `build`

Use `build` only after the relevant `§T` task exists in `SPEC.md`.

Before editing code, the build plan should identify:

- The selected `§T` task or tasks.
- The `§V` invariants that must remain true.
- The `§I` interfaces that must be preserved.
- The files likely to be edited.
- The exact verification command or commands that prove the change.

During implementation:

1. Move the task status from pending to in progress.
2. Make the smallest code change that satisfies the spec.
3. Run the named verification.
4. If verification passes, mark the task complete.
5. If verification fails, determine whether the cause is a code bug, a wrong
   spec, or a missing invariant. Use `backprop` when the spec needs to learn
   from the failure.

Do not silently expand task scope. If the implementation reveals new behavior,
interfaces, or constraints, amend the spec first.

---

## 8. Testing and verification

The repository uses pytest for Python tests. Non-trivial logic must leave behind
one runnable check: the smallest test or assertion that fails if the behavior
breaks. Trivial one-line changes do not need a new test.

Use these checks where relevant:

- **OKF conformance test**: every non-reserved Markdown concept file parses as
  frontmatter plus body and has a non-empty `type`.
- **Heuristic classification tests**: table-driven URL and content-type cases.
- **Extractor tests**: fixed HTML, PDF, or document input to expected Markdown
  output. Do not hit the live network in tests.
- **Crawler tests**: depth limit, delay, allowed-hosts guard, robots handling,
  and retries against local fixtures or Scrapy utilities.
- **Incremental-update test**: crawling the same URL twice updates the concept
  and appends one log entry without duplicating the concept.
- **Report/error tests**: synthetic run and page rows produce the expected report
  counts and error sections.
- **Database rebuild test**: rebuilding indexes from an on-disk bundle reproduces
  the expected rows.

Standard verification commands:

```bash
ruff check .
black --check .
mypy .
pytest
```

Run the smallest relevant command while iterating, then run the full gate before
shipping. Never call a task done if verification failed or was skipped.

---

## 9. Checking drift with `check`

Use `check` after implementation and before shipping. It compares `SPEC.md` to
the current code without writing anything.

Check these areas:

- `§V`: each invariant should hold in code and tests.
- `§I`: documented interfaces should match implemented interfaces.
- `§T`: completed tasks should have evidence in code and tests.

Treat drift as a real defect. If code is wrong, fix the code. If the spec is
outdated, amend the spec. If the drift reveals a bug class, use `backprop`.

---

## 10. Backpropagating bugs with `backprop`

Backpropagation is the key difference between a normal fix and a durable fix.
When a bug, failed test, or incident occurs, do not only patch the code. Record
what the spec failed to protect.

Backpropagation should:

1. Trace the failure to a root cause.
2. Add a `§B` record for the bug or failure.
3. Add or update a `§V` invariant when that would catch the class of bug in the
   future.
4. Add a failing test for the new invariant before fixing code when practical.
5. Fix the code and run the relevant verification.

Every bug gets a `§B` entry. A new invariant is not always required, but it
should be the default when the failure represents a repeatable class of bug.

---

## 11. Improving design with `deepen`

Use `deepen` only when the build is green and there is time for deliberate
design improvement. It is not part of the urgent bug-fix path.

A good deepening pass chooses one shallow module and proposes a smaller, clearer
interface without changing behavior. It should reduce change amplification, hide
an implementation decision, or make an error state impossible by design.

Rules for deepening:

- Tests must be green before and after.
- Behavior must remain the same.
- Change one module per pass.
- Propose any `§I`, `§V`, or `§T` changes through `spec`.
- Do not add abstractions for single-use code.

---

## 12. Implementation principles

These rules apply to all code changes, regardless of which Cavekit skill is in
use.

1. Prefer deletion over addition and boring code over clever code.
2. Reuse existing code before writing new code.
3. Use the standard library or installed dependencies before adding a new
   dependency.
4. Keep subsystems separated: crawler, extraction, OKF writing and conformance,
   database indexing, reporting, and web UI.
5. Treat crawled content as untrusted input.
6. Use Alembic migrations for schema changes; do not rely on manual DDL.
7. Mark intentional shortcuts with a `ponytail:` comment that names the known
   ceiling and the upgrade path.
8. Keep commits focused. Use Conventional Commits with a short imperative
   subject and a body only when the reason is not obvious.

---

## 13. UI work

UI work still follows Cavekit. Specify the routes, states, and interfaces before
building.

For the Phase 4 FastAPI and Jinja2 UI, define:

- Site mirror view: bundle directory hierarchy, breadcrumbs, concept rendering,
  and internal cross-link navigation.
- Admin dashboard: run list, run detail, error filters, concept browser, and
  full-text search.
- States: empty, loading, error, and populated states for every route.
- Accessibility: semantic HTML, keyboard navigation, and labeled controls.

Minimum UI artifact:

| Route | View | Empty state |
|---|---|---|
| `/` | Bundle root index | "No bundles yet" |
| `/{path...}` | Concept render | 404 concept |
| `/admin` | Run list | "No runs yet" |
| `/admin/runs/{id}` | Run detail and errors | No errors |
| `/admin/search?q=` | Full-text search results | "No matches" |

---

## 14. Definition of done

A change is done only when all applicable items are true:

- The idea was clarified, or it was simple enough to skip grilling.
- `SPEC.md` was created or amended if behavior, interfaces, contracts, or
  invariants changed.
- Required research was sourced and reflected in `§R`.
- High-risk specs were reviewed and any blocking findings were resolved.
- The selected `§T` tasks are complete.
- Tests or assertions cover the relevant `§V` invariants.
- `ruff`, `black --check`, `mypy`, and `pytest` pass where applicable.
- `check` reports no unresolved drift for the touched area.
- Bugs and failed verification paths were backpropagated into `§B` and `§V`
  when appropriate.
- Documentation was updated in the same change.

---

## 15. Pull request checklist

Copy this checklist into each non-trivial pull request and delete items that do
not apply.

```markdown
- [ ] Grill: ambiguous requirements clarified, or skipped as trivial
- [ ] Research: external facts sourced in §R, or not needed
- [ ] Spec: SPEC.md updated for changed behavior, interfaces, invariants, or tasks
- [ ] Review: high-risk spec reviewed, or risk was low enough to skip
- [ ] Build: selected §T tasks completed with focused code changes
- [ ] Tests: runnable checks cover touched §V invariants
- [ ] Verify: ruff / black --check / mypy / pytest pass where applicable
- [ ] Check: no unresolved spec drift in touched areas
- [ ] Backprop: bugs or failed verification recorded in §B and hardened with §V when appropriate
- [ ] Docs: README or standards docs updated in the same PR
```
