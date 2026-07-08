# AI Development Workflow Guide

This guide defines how AI-assisted development is conducted on **orange-red** — a
web crawler that converts crawled site content into
[Open Knowledge Format (OKF)](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
bundles for use as LLM knowledge bases.

It is the single source of truth for *how* work moves from idea to merged code.
Read it before starting any feature. Every non-trivial change follows the phases
below in order: **Plan → Specification → UI Design → Test Plan → Implementation →
Verification**, with the supporting practices that surround them.

---

## 0. Project decisions (locked)

These decisions are settled and should not be re-litigated without an explicit
change request. New work assumes them as given.

| Topic | Decision |
|---|---|
| Crawler engine | **Scrapy** — depth limit, `DOWNLOAD_DELAY`, `AUTOTHROTTLE`, robots.txt, retries, and dedup come for free as configuration. |
| Concept `type` | **Heuristic classification** — e.g. `Documentation`, `Article`, `PDF`. One page → one concept, with `type` inferred from URL/content. |
| Authentication | **None** — public pages only for now. No credential handling in the crawler. |
| Crawl mode | **Incremental** — re-crawls update an existing bundle in place and append to `log.md`; they do not create a fresh bundle each run. |
| Graph visualization | **Deferred** — `viz.html` / Cytoscape graph is out of scope for the initial phases. |
| Backend | Python 3.14, PostgreSQL 15+, Docker (existing dev-container stack). |

---

## 1. Guiding principles

These principles apply at every phase. When a decision is ambiguous, resolve it
in favor of these.

1. **Laziness is efficiency, not carelessness.** The best code is code never
   written. Before building, climb the ladder: (a) does it need to exist?
   (b) does it already exist in this repo? (c) does the standard library do it?
   (d) does a platform feature cover it? (e) does an installed dependency solve
   it? (f) can it be one line? Only then write minimal new code.
2. **Reuse mature libraries over hand-rolling.** Crawling, boilerplate removal,
   PDF→markdown, and frontmatter I/O are solved problems. Do not reimplement
   them. See the library table in the project plan.
3. **The bundle on disk is the source of truth; Postgres is a derived index.**
   You must be able to rebuild every Postgres table by re-scanning the bundle,
   and re-generate the bundle from raw blobs. Never let them diverge silently.
4. **OKF conformance is non-negotiable.** Every non-reserved `.md` file the tool
   emits must parse as YAML frontmatter + markdown body and carry a non-empty
   `type`. This is verified by an automated conformance check (see §5).
5. **Fix root causes, not symptoms.** A bug report names a symptom. Grep every
   caller of the function you touch and fix the shared function once.
6. **Deletion over addition. Boring over clever. Fewest files possible.**
7. **Not lazy about:** understanding the problem before coding, input validation
   at trust boundaries (crawled data is untrusted input), error handling that
   prevents data loss, security, accessibility, and the calibration real systems
   need. Non-trivial logic leaves behind **one runnable check**.

---

## 2. Plan

**Goal:** agree on *what* and *why* before any code.

Every feature starts with a short plan captured in the PR description or a
linked issue. A plan answers:

- **Problem** — what user need or requirement does this serve? Reference the
  originating requirement (crawl depth, delay, doc-type conversion, report,
  viewer, dashboard, error reporting).
- **Scope & non-scope** — what is explicitly *not* in this change.
- **Ladder result** — which rung of the laziness ladder (§1.1) did you stop at,
  and why? If new code is being written, state what already-installed dependency
  or stdlib feature was considered and rejected.
- **Phase** — which project phase does this belong to (see the roadmap):
  Phase 0 foundations, Phase 1 crawl→raw, Phase 2 extract→OKF, Phase 3
  report+errors, Phase 4 viewer+admin. (Graph and RAG are deferred.)
- **Data touch points** — which Postgres tables and which bundle files are read
  or written.

**Exit criteria:** the plan is small enough to review in one sitting and names a
single, runnable outcome. If it doesn't, split it.

---

## 3. Specification

**Goal:** pin down the exact contract so implementation is mechanical.

A specification is required for anything that produces or consumes an external
contract: OKF output, the crawl config schema, Postgres schema/migrations, or an
HTTP endpoint. Capture it in `docs/standards-and-guides/` (a spec file per
subsystem) or inline in the PR for small changes.

A spec includes:

- **Inputs** — config keys (with types and defaults), CLI arguments, request
  shapes. Config is a single YAML file driving a run (`seeds`, `max_depth`,
  `delay_seconds`, `allowed_hosts`, `content_types`, `respect_robots`,
  `bundle_out`).
- **Outputs** — the exact shape produced. For OKF this means: required `type`
  field, recommended frontmatter (`title`, `description`, `resource`, `tags`,
  `timestamp`), body conventions (`# Schema`, `# Examples`, `# Citations`),
  bundle-absolute cross-links (`/path/to/concept.md`), reserved `index.md` /
  `log.md`, and root `okf_version: "0.1"`.
- **Heuristic rules** — for `type` classification, state the exact rules
  (e.g. `.pdf` URL → `PDF`; path contains `/docs/` or `/reference/` →
  `Documentation`; blog/news paths → `Article`; fallback → generic `Web Page`).
  Rules must be deterministic and testable.
- **Invariants** — e.g. "one crawled page maps to exactly one concept",
  "re-crawling an existing URL updates its concept and appends a `log.md`
  entry", "Postgres `concepts` rows always mirror on-disk frontmatter".
- **Error contract** — what counts as a failure, what gets recorded in
  `pages.error_*`, and how it surfaces in the report and dashboard.

**Exit criteria:** a reviewer can predict the output of any input without reading
the implementation.

---

## 4. UI Design

**Goal:** define the viewer and admin dashboard before wiring endpoints.

Applies to Phase 4 (FastAPI + Jinja2 server-rendered UI). For UI work, capture:

- **Site mirror view** — the public browser mirrors the crawled site's
  structure: the bundle directory hierarchy (derived from URL paths) is the
  navigation. Sketch the directory tree → page rendering, breadcrumb, and
  cross-link navigation (internal `[...](/path/to/concept.md)` links rewired to
  navigate within the viewer).
- **Admin dashboard** — screens/states for: run list (name, status, timing,
  pages OK/err counts), single-run drill-down, error view (filterable by
  `error_class` / HTTP status), concept browser, and full-text search
  (Postgres `tsvector`).
- **States** — always design empty, loading, error, and populated states. An
  admin dashboard with no runs must render sensibly.
- **Accessibility** — semantic HTML, keyboard navigation, and labeled controls
  are required, not optional (see §1.7).

Provide a low-fidelity sketch (ASCII, markdown table of routes → views, or a
wireframe image) in the PR. No pixel-perfect mockups required — clarity of
structure and states is what matters.

**Route → view table** is the minimum artifact, e.g.:

| Route | View | Empty state |
|---|---|---|
| `/` | bundle root index | "No bundles yet" |
| `/{path...}` | concept render | 404 concept |
| `/admin` | run list | "No runs yet" |
| `/admin/runs/{id}` | run detail + errors | — |
| `/admin/search?q=` | FTS results | "No matches" |

**Exit criteria:** every route has a defined view and every view has defined
states.

---

## 5. Test Plan

**Goal:** decide how you'll *prove* the change works before writing it.

The repo uses **pytest**. Non-trivial logic leaves behind **one runnable
check** — the smallest thing that fails if the logic breaks. No heavy frameworks,
no fixtures for trivial cases; an assert-based self-check is acceptable. Trivial
one-liners need no test.

State, per change, which of these apply:

- **OKF conformance test** — the tool's output bundle passes the conformance
  check: every non-reserved `.md` parses as frontmatter + body and has a
  non-empty `type`. This is the highest-value test in the project and must exist
  for any change to the OKF writer.
- **Heuristic classification tests** — table-driven: a set of `(url,
  content-type) → expected type` cases. Deterministic, fast, no network.
- **Extractor tests** — fixed HTML/PDF/DOCX input → expected markdown output.
  Use small checked-in fixtures; never hit the live network in tests.
- **Crawler tests** — depth limit, delay, allowed-hosts guard, and robots
  handling verified against a local fixture server or Scrapy's test utilities,
  not the internet.
- **Incremental-update test** — crawling the same URL twice updates the concept
  and appends exactly one `log.md` entry; it does not duplicate.
- **Report/error tests** — given synthetic `runs`/`pages` rows, the generated
  `report.md` contains the expected counts and error rows.
- **DB round-trip test** — rebuilding `concepts` from an on-disk bundle
  reproduces the same rows (invariant §1.3).

**Exit criteria:** every invariant from the spec (§3) has a corresponding check,
and tests run offline and deterministically.

---

## 6. Implementation

**Goal:** write the minimum code that satisfies the spec and passes the tests.

Rules:

- **Follow the ladder.** Reach for Scrapy config, stdlib, and installed
  dependencies before new code. Prefer editing/deleting over adding.
- **Package layout.** Application code lives under the `orange_red/` package.
  Keep subsystems separated: `crawler/`, `extract/` (content-type registry),
  `okf/` (writer + conformance), `db/` (SQLAlchemy models + migrations),
  `report/`, `web/` (FastAPI). Fewest files that keep concerns clear.
- **Extractors are a registry.** Adding a new content type = adding one
  registered extractor, not editing a giant switch. Each maps raw bytes →
  markdown + extracted metadata.
- **Untrusted input.** Crawled HTML/PDF is untrusted. Validate and sanitize at
  the extraction boundary; never assume well-formed content.
- **Type hints and docstrings** on all functions (enforced by mypy; PEP 8 via
  black + ruff).
- **Mark intentional shortcuts** with a `ponytail:` comment naming the known
  ceiling and the upgrade path (e.g. `ponytail: in-memory frontier, swap to
  Postgres table for resumable crawls`).
- **Migrations, not manual DDL.** Schema changes go through Alembic migrations
  so any environment can rebuild the database.

**Commit style:** Conventional Commits. Subject ≤ 50 chars; body only when the
"why" isn't obvious from the diff. One logical change per commit.

**Exit criteria:** code compiles, is formatted and linted, and the tests from §5
pass locally.

---

## 7. Verification

**Goal:** confirm the change actually works before it merges.

Run, in order, and do not proceed on failure:

```bash
ruff check .        # lint
black --check .     # format
mypy .              # type check
pytest              # tests, incl. OKF conformance
```

Beyond the automated gate:

- **Conformance gate.** The OKF conformance check must pass on any bundle the
  change can produce. A non-conformant bundle is a release blocker.
- **Manual smoke test** for crawler/extractor/UI changes: run a small real crawl
  against a low-risk public site (respecting robots and delay), then inspect the
  bundle, the generated `report.md`, and the dashboard.
- **Invariant re-check.** Verify the §3 invariants hold on the smoke-test output
  (page↔concept 1:1, Postgres mirrors disk, incremental update appends one log
  entry).
- **Error-path check.** Confirm a deliberately unreachable URL is recorded in
  `pages.error_*`, appears in the report's failures section, and is filterable
  in the dashboard.

**Never call a task done** if a command failed, a tool returned an error, tests
fail, or verification hasn't been performed. Provide a brief summary of what was
verified.

**Exit criteria:** all gates green, invariants confirmed, error path exercised.

---

## 8. Supporting practices

- **Documentation.** Update `README.md` usage sections and any affected spec in
  `docs/standards-and-guides/` in the *same* PR as the code. Docs that lag code
  are treated as a defect.
- **Configuration over code.** New crawl behavior should be a config key wired
  into Scrapy settings before it is custom code.
- **Observability.** Every run writes a `runs` row and per-page `pages` rows;
  the `report.md` is generated *from* those rows, not from ad-hoc logging. Keep
  the database the record of truth for run history.
- **Reproducibility.** A run is defined by its config file. Store the run's
  config (`config_json`) so any run can be explained and re-executed.
- **Reversibility.** Raw blobs are retained so extraction can be re-run without
  re-crawling when converters improve. Do not delete raw data as an optimization
  without an explicit decision.
- **Scope discipline.** Deferred items (graph `viz.html`, pgvector RAG) stay
  deferred. If a PR starts pulling them in, split it and flag the scope change.
- **Definition of Done.** Plan agreed → spec written (if a contract changed) →
  UI designed (if UI changed) → tests written and passing → implementation
  minimal and lint/type clean → verification gates green and invariants
  confirmed → docs updated.

---

## 9. Quick checklist (copy into each PR)

```
- [ ] Plan: problem, scope/non-scope, ladder result, phase, data touch points
- [ ] Spec: inputs, outputs, heuristics, invariants, error contract (if contract changed)
- [ ] UI: route→view table with empty/loading/error/populated states (if UI changed)
- [ ] Tests: one runnable check per invariant; offline & deterministic
- [ ] Impl: minimal, reuses libs/stdlib, registry for extractors, ponytail: notes on shortcuts
- [ ] Verify: ruff / black / mypy / pytest green; OKF conformance passes
- [ ] Verify: manual smoke crawl inspected; invariants + error path confirmed
- [ ] Docs updated in same PR
```
