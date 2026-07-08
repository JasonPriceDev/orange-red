# AI Development Workflow Guide

This guide defines how AI-assisted development is conducted on **orange-red**.
It follows the Cavekit workflow: clarify the idea, write or amend `SPEC.md`,
set a visual direction for any UI, review the spec when risk is high, build
against the spec, check for drift, and backpropagate bugs into the spec so they
do not recur.

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
the repository root. It is the durable memory of the project: if the context
window is lost, reload the spec and keep going. Code is planned, built,
reviewed, and repaired against that file. There are no sub-agents, no
dashboards, and no orchestration — one thread, one spec, one diff.

**The loop — run these every time:**

| Skill | Slash command | Purpose |
|---|---|---|
| `spec` | `/ck:spec` | Create, amend, or backprop `SPEC.md`. The sole writer of spec content. |
| `build` | `/ck:build` | Plan then execute against the spec. Names which test proves each `§V`, and auto-backprops on failure. |
| `check` | `/ck:check` | Read-only drift report listing `§V`, `§I`, and `§T` violations. |

**Reach for these — only when the change earns the ceremony:**

| Skill | Slash command | Purpose |
|---|---|---|
| `grill` | `/ck:grill` | Interrogate a fuzzy idea into a sharp `§G`/`§C`, one question at a time, before spec. |
| `research` | `/ck:research` | Gather external facts into `§R` so the build is grounded, not hallucinated. Every finding cites a source. |
| `review` | `/ck:review` | Adversarial senior review of the spec before build. Refutes, hardens `§V`, ends in a go/no-go gate. |
| `deepen` | `/ck:deepen` | Spare-budget design pass — make one shallow module deep. Behavior held, tests green before and after. |
| `improve-codebase-architecture` | — | Scan the codebase for shallow modules and present deepening candidates as a visual report. The discovery front-end for `deepen`. |
| `frontend-design` | — | Distinctive, intentional visual direction when building or reshaping UI. Reach for it before UI implementation. |
| `web-design-guidelines` | — | Audit UI code against the Web Interface Guidelines. The verification back-end for UI, after implementation. |
| `tdd` | — | Red → green → refactor discipline. Applied inside `build` when writing the tests that prove each `§V`. |
| `agent-browser` | — | Browser automation for smoke tests, exploratory QA, and dogfooding. The engine behind manual UI verification. |

**Cross-cutting skills** — available at any phase:

| Skill | Purpose |
|---|---|
| `find-skills` | Discover and install a skill from the open ecosystem when a task needs a capability the repo does not yet have. |
| `handoff` | Compact the current session into a handoff document so a fresh agent can continue the work. |

**Utilities** used by the skills above, not run directly:

| Skill | Purpose |
|---|---|
| `caveman` | Output-compression encoding used inside spec and spec-adjacent writes. |
| `backprop` | Bug-to-spec protocol: turn a failure into a `§B` record and usually a new `§V` invariant. Invoked by `spec` and `build`. |

**Right-size the process.** A one-line, reversible fix is just `/ck:build` (or a
direct edit). The full chain is for genuinely uncertain or high-blast-radius
work — never for a typo.

Default sequence for non-trivial work:

1. Use `grill` if the request is ambiguous.
2. Use `research` if the spec depends on facts outside the repository.
3. Use `spec` to create or amend `SPEC.md`.
4. Use `frontend-design` if the change introduces or reshapes user-facing UI.
5. Use `review` before building high-risk changes.
6. Use `build` for one or more `§T` tasks.
7. Use `check` after the build and before shipping.
8. Let `build` invoke `backprop` whenever a failed verification reveals a
   missing invariant.

Skip steps only when the change is trivial, reversible, and does not touch a
contract, shared module, data model, public interface, or security boundary.

**Sectioned ownership.** Each skill owns specific `SPEC.md` sections and never
rewrites one it does not own. `spec` is the only skill that writes spec content;
`grill`, `research`, `review`, and `deepen` propose material and hand it to
`spec` to write.

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
| `§R` | Research: sourced facts the spec relies on, as a pipe table. Optional — include only when research was needed. |
| `§V` | Invariants: testable rules that must remain true. These drive tests and verification. |
| `§T` | Tasks: an ordered pipe table of work items with status and citations to the relevant `§V` and `§I` entries. |
| `§B` | Bugs: a pipe table of historical bug records and the invariant or fix that prevents recurrence. |

The section order is `§G`, `§C`, `§I`, `§R`, `§V`, `§T`, `§B`. See `FORMAT.md`
in the Cavekit repository for the exact caveman encoding and table shapes.

Task rows should be small enough to build and verify independently. A task is
not complete unless its cited invariants have a named verification check.

Use normal project language in surrounding documentation. `SPEC.md` itself uses
the compact Cavekit format; do not copy that style into user-facing docs.

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

During implementation, work in test-first vertical slices using the `tdd`
skill:

1. Move the task status from pending to in progress.
2. Confirm the seams to test — the public interfaces where behavior is observed.
3. Write one failing test that pins a `§V` invariant (red).
4. Make the smallest code change that makes it pass (green).
5. Run the named verification.
6. If verification passes, take the next slice or mark the task complete.
7. If verification fails, determine whether the cause is a code bug, a wrong
   spec, or a missing invariant. Use `backprop` when the spec needs to learn
   from the failure.

One seam, one test, one minimal implementation per cycle. Do not write all tests
up front, and do not test private internals. Refactoring happens after the loop,
not inside it — reach for `deepen` or `improve-codebase-architecture` for that.

Do not silently expand task scope. If the implementation reveals new behavior,
interfaces, or constraints, amend the spec first.

---

## 8. Testing and verification

The repository uses pytest for Python tests. Follow the `tdd` skill: tests
verify behavior through public interfaces (seams), never implementation details.
A good test reads like a specification and survives refactors. Avoid the
anti-patterns the skill names — implementation-coupled tests, tautological
assertions, and horizontal slicing. Non-trivial logic must leave behind at least
one runnable check that fails if the behavior breaks. Trivial one-line changes
do not need a new test.

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

Beyond the automated gate, for crawler, extractor, or UI changes:

- **Manual smoke test** with `agent-browser`: run a small real crawl against a
  low-risk public site (respecting robots and delay), then inspect the bundle,
  the generated `report.md`, and the dashboard. Use it for exploratory QA and
  dogfooding of the Phase 4 viewer and admin screens.
- **Invariant re-check**: confirm the project invariants hold on the smoke-test
  output — one page maps to one concept, Postgres mirrors disk, and an
  incremental re-crawl appends one log entry.
- **Error-path check**: confirm a deliberately unreachable URL is recorded,
  appears in the report's failures section, and is filterable in the dashboard.

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

## 11. Improving design with `deepen` and `improve-codebase-architecture`

Use these only when the build is green and there is time for deliberate design
improvement. They are not part of the urgent bug-fix path.

To find *what* to improve, run `improve-codebase-architecture`. It scans the
codebase for shallow modules — where the interface is nearly as complex as the
implementation — and presents deepening candidates as a self-contained HTML
report in the OS temp directory (nothing lands in the repo). Each candidate
shows the files, the problem, a proposed solution, and a before/after diagram.
Pick one candidate, then hand it to `deepen`.

`deepen` then chooses that one shallow module and proposes a smaller, clearer
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

## 13. UI work with `frontend-design` and `web-design-guidelines`

UI work still follows Cavekit: the routes, states, and interfaces belong in
`§I`, and any UI invariants belong in `§V`. The two UI skills bracket the build:
`frontend-design` sets the visual direction *before* implementation, and
`web-design-guidelines` audits the result *after* implementation. Between them,
`build` implements against the spec.

Use `frontend-design` to decide, before writing markup or CSS:

- A concrete subject, audience, and the single job of each screen.
- A compact token system: 4–6 named palette values, deliberate display and body
  typefaces, a layout concept, and one signature element the UI is remembered
  by.
- Interface copy written from the user's side of the screen: active voice,
  consistent action names, and empty/error states that give direction.

Avoid the templated AI defaults (cream-and-serif, near-black with one acid
accent, hairline-rule broadsheet) unless the brief genuinely calls for them.
Spend boldness in one place and keep the rest quiet.

For the Phase 4 FastAPI and Jinja2 UI, define:

- Site mirror view: bundle directory hierarchy, breadcrumbs, concept rendering,
  and internal cross-link navigation.
- Admin dashboard: run list, run detail, error filters, concept browser, and
  full-text search.
- States: empty, loading, error, and populated states for every route.
- Accessibility: semantic HTML, keyboard navigation, visible keyboard focus,
  reduced-motion support, and labeled controls.

Minimum UI artifact:

| Route | View | Empty state |
|---|---|---|
| `/` | Bundle root index | "No bundles yet" |
| `/{path...}` | Concept render | 404 concept |
| `/admin` | Run list | "No runs yet" |
| `/admin/runs/{id}` | Run detail and errors | No errors |
| `/admin/search?q=` | Full-text search results | "No matches" |

After the UI is built, run `web-design-guidelines` against the changed templates
and components. It fetches the current Web Interface Guidelines and reports
findings in a terse `file:line` format covering accessibility, interaction, and
UX. Treat its findings the same way as `check` findings: fix, or record a `§B`
and a hardening `§V` if the issue is a repeatable class.

---

## 14. Supporting skills: `find-skills` and `handoff`

Two skills apply across every phase rather than at one step:

- **`find-skills`** — when a task needs a capability the repository does not yet
  have, use `find-skills` to search the open skill ecosystem
  (`npx skills find <query>`) and install the best match with
  `npx skills add <package>`. Add durable, project-relevant skills through
  `scripts/post-create.sh` so a container rebuild restores them.
- **`handoff`** — when a session grows long or must pass to another agent, use
  `handoff` to write a compact handoff document to the OS temp directory. It
  references existing artifacts (spec, ADRs, commits, diffs) by path instead of
  duplicating them, suggests the skills the next session should use, and redacts
  secrets. Because `SPEC.md` is already the durable memory, the handoff only
  needs to capture the live working state.

---

## 15. Definition of done

A change is done only when all applicable items are true:

- The idea was clarified, or it was simple enough to skip grilling.
- `SPEC.md` was created or amended if behavior, interfaces, contracts, or
  invariants changed.
- Required research was sourced and reflected in `§R`.
- UI changes had a `frontend-design` direction before implementation and passed
  a `web-design-guidelines` audit after.
- High-risk specs were reviewed and any blocking findings were resolved.
- The selected `§T` tasks are complete.
- Tests were written test-first at agreed seams and cover the relevant `§V`
  invariants.
- `ruff`, `black --check`, `mypy`, and `pytest` pass where applicable.
- Crawler, extractor, or UI changes were smoke-tested with `agent-browser`.
- `check` reports no unresolved drift for the touched area.
- Bugs and failed verification paths were backpropagated into `§B` and `§V`
  when appropriate.
- Documentation was updated in the same change.

---

## 16. Pull request checklist

Copy this checklist into each non-trivial pull request and delete items that do
not apply.

```markdown
- [ ] Grill: ambiguous requirements clarified, or skipped as trivial
- [ ] Research: external facts sourced in §R, or not needed
- [ ] Spec: SPEC.md updated for changed behavior, interfaces, invariants, or tasks
- [ ] Design: frontend-design direction set for UI changes, or no UI change
- [ ] Review: high-risk spec reviewed, or risk was low enough to skip
- [ ] Build: selected §T tasks completed test-first in vertical slices (tdd)
- [ ] Tests: runnable checks cover touched §V invariants at agreed seams
- [ ] Verify: ruff / black --check / mypy / pytest pass where applicable
- [ ] Smoke: crawler/extractor/UI changes exercised with agent-browser
- [ ] UI audit: web-design-guidelines run on changed templates, or no UI change
- [ ] Check: no unresolved spec drift in touched areas
- [ ] Backprop: bugs or failed verification recorded in §B and hardened with §V when appropriate
- [ ] Docs: README or standards docs updated in the same PR
```
