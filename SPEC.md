# SPEC.md — orange-red

Intranet scraper. Crawl configured hosts, convert HTML/PDF into Open Knowledge
Format (OKF) markdown bundle, version ignored nested data repo in git, index
with Postgres pgvector for search and CLI chat.

## §G

Scrape configured intranet hosts into ignored nested `orange-red-data` OKF git
repo, index with OpenAI embeddings in PG18 pgvector, query and chat by CLI with
citations.

## §C

- Crawler engine: Scrapy. Depth limits, delays, autothrottle, robots.txt,
  retries, dedup.
- Allowed hosts required via config. `orange-red crawl <url>` does not infer
  allowed hosts from start URL.
- Crawl defaults: depth 2, download delay 1s, autothrottle on, timeout 30s,
  retries 2.
- Robots.txt obeyance on by default. Env override may disable for approved
  intranet policy.
- Max fetched resource size 25 MB by default, env configurable. Oversize
  resource skipped + recorded as run error.
- Output format: OKF v0.1. Bundle = directory tree of markdown, YAML
  frontmatter + body.
- YAML frontmatter is only structured metadata surface. Every concept document
  has at least `type`, `title`, `description`, `resource`, `tags`, `timestamp`.
- Frontmatter `timestamp` uses ISO 8601 datetime with microsecond precision.
- One crawled page maps to exactly one OKF concept file.
- URL identity: normalized absolute final response URL, query string counts,
  fragment ignored.
- Redirect identity: final response URL is concept identity + `resource`.
  Original requested URL stored in run metadata when different.
- Concept `type`: controlled heuristic set `Documentation`, `Article`,
  `Reference`, `PDF`, `Other`. One page one concept.
- Every concept `resource` frontmatter field = original fetched resource URL
  after redirect canonicalization.
- Document conversion v1: HTML and PDF convert to OKF markdown concepts.
  Microsoft Office (docx/xlsx/pptx) deferred.
- Same-host PDF links discovered during crawl are crawlable concepts under same
  `<site-host>` subtree as source site. No separate document structure. No
  image, CSS, or general asset mirroring v1.
- Empty extraction writes no concept; record run error.
- Crawled content is untrusted input. Validate/sanitize at extraction boundary.
  Concept bodies are markdown-only, no raw HTML.
- Link rewriting: links to crawled concepts become bundle-relative paths;
  uncrawled/external links stay absolute.
- Bundle git target: ignored nested clone `orange-red-data/`, remote
  `https://github.com/JasonPriceDev/orange-red-data`, not submodule.
- `orange-red-data/` is own git repo and OKF bundle root. Parent `orange-red`
  ignores it. Workspace file lists `orange-red` + `orange-red-data` roots.
- Crawl mode: incremental. Re-crawl updates existing concept + appends root and
  host `log.md` entries; no duplicate concept.
- Every crawl creates git commit, even no content changes. Crawler pushes after
  commit.
- Push failure leaves local commit intact and exits nonzero.
- Partial crawl commits successful concepts + run/error records, exits nonzero
  when any required fetch/conversion failed.
- Postgres = pgvector store. Rows are rebuildable index of bundle on disk, not
  competing source of truth.
- Index rebuild transactional. Failure leaves previous complete index intact.
- Missing/empty index makes `query`/`chat` exit nonzero with run-index message.
- Backend: Python 3.14, PostgreSQL 18 via `pgvector/pgvector:pg18`, Docker,
  existing dev-container stack.
- Schema changes via Alembic migrations, not manual DDL.
- Database stack: SQLAlchemy 2 Core, Alembic, `pgvector` Python package,
  psycopg3.
- pgvector: enable in Postgres. `CREATE EXTENSION vector` via Alembic
  migration. Use cosine distance.
- Embedding model: OpenAI `text-embedding-3-large` via `OPENAI_API_KEY`,
  `https://api.openai.com/v1/embeddings`, dimension 3072 pinned stable.
- Chunking: heading-aware, max 1000 tokens, 150-token overlap, deterministic
  order.
- Chat model: OpenAI `gpt-5.4` via `OPENAI_API_KEY`,
  `https://api.openai.com/v1/chat/completions`.
- Key validation per command: `crawl` needs no model key; `index`, `query`,
  and `chat` need `OPENAI_API_KEY`.
- Chat surface: CLI only for now. No web chat UI initial.
- Query output default: top 10 concepts with path, title, resource URL,
  similarity score, snippet.
- Chat output: answer + concept citations with bundle path and source URL.
- Chat evidence rule: if no retrieved chunk meets configurable threshold
  (default cosine similarity 0.70), say bundle lacks enough information; do not
  fabricate citations.
- Auth: none for crawl now. Auth/VPN intranet access = future requirement, not
  initial scope. Initial crawl targets pages reachable unauthenticated.
- Graph viz deferred. No `viz.html`/Cytoscape initial.

## §I

- Python package: `orange_red`.
- Console script: `orange-red`, defined by `pyproject.toml` + setuptools.
- `orange-red-data/` — ignored nested git clone; OKF bundle root; remote
  `https://github.com/JasonPriceDev/orange-red-data`.
- `.gitignore` — ignores `orange-red-data/`.
- `.code-workspace` — lists `orange-red` + `orange-red-data` roots.
- Concept `.md` — YAML frontmatter with required `type`, `title`,
  `description`, `resource`, `tags`, `timestamp` + markdown-only body.
- `orange-red-data/index.md` — reserved root listing, no frontmatter except
  optional `okf_version: "0.1"`.
- `orange-red-data/log.md` — reserved bundle-wide update history, newest first.
- `orange-red-data/<site-host>/index.md` — reserved host listing.
- `orange-red-data/<site-host>/log.md` — reserved host update history, newest
  first.
- Bundle-relative links: `/path/to/concept.md` from bundle root.
- CLI `orange-red crawl <url>` — run incremental crawl, write bundle, commit,
  push.
- CLI `orange-red index` — transactional rebuild of pgvector index from bundle
  on disk.
- CLI `orange-red query "<text>"` — semantic search over indexed concepts,
  default top 10.
- CLI `orange-red chat "<question>"` — retrieve, answer with citations via
  OpenAI.
- Config: `settings.py` + env.
- Env: `DATABASE_URL`, `OPENAI_API_KEY`,
  `ORANGE_RED_ALLOWED_HOSTS`, `ORANGE_RED_BUNDLE_DIR`,
  `ORANGE_RED_DEPTH_LIMIT`, `ORANGE_RED_DOWNLOAD_DELAY`,
  `ORANGE_RED_AUTOTHROTTLE`, `ORANGE_RED_OBEY_ROBOTS`,
  `ORANGE_RED_REQUEST_TIMEOUT`, `ORANGE_RED_RETRY_TIMES`,
  `ORANGE_RED_MAX_RESOURCE_BYTES`, `ORANGE_RED_CHAT_THRESHOLD`.
- Embedding: OpenAI `text-embedding-3-large`, `OPENAI_API_KEY`,
  `https://api.openai.com/v1/embeddings`, output dimension 3072.
- Chat: OpenAI `gpt-5.4`, `OPENAI_API_KEY`,
  `https://api.openai.com/v1/chat/completions`.
- Postgres table `concept`: id, path, type, resource_url, title, timestamp,
  content_hash.
- Postgres table `chunk`: concept_id, ord, text, embedding vector(3072).
- Postgres table `run`: id, kind (`crawl`/`index`), started_at, finished_at,
  status, start_url, bundle_ref, git_commit_sha.
- Postgres table `error`: id, run_id, url, path, stage, message.
- Alembic migrations under `migrations/`.

`orange-red-data` repo layout (OKF bundle root = repo root):

```
orange-red-data/            # git repo = bundle root, ships as OKF bundle
├── index.md                # root listing; frontmatter okf_version: "0.1" only
├── log.md                  # bundle-wide update history, newest first
├── <site-host>/            # one subtree per crawled intranet host
│   ├── index.md            # listing for that host
│   ├── log.md              # per-host update history
│   └── <url-path>.md       # one HTML/PDF concept per resource; mirrors canonical URL
│       ...                 # type=Documentation|Article|Reference|PDF|Other
```

Layout rules:
- Repo root = bundle root (satisfies R8: ship bundle as git repo).
- Concept file path mirrors canonical URL path under `<site-host>` subtree. Query
  string kept in identity; filename adds stable query hash when needed to avoid
  collision.
- PDFs on site live under same `<site-host>` subtree, not `documents/`.
- Every concept sets `resource` = canonical final response URL (V4).
- `index.md`/`log.md` generated, never concept docs (V3).
- Reserved for data repo only. Code repo does not contain bundle files.

## §R

| id | fact | source |
|---|---|---|
| R1 | OKF concept = one UTF-8 markdown file: YAML frontmatter block (`---`...`---`) + markdown body. | knowledge-catalog/okf/SPEC.md §4 |
| R2 | OKF frontmatter carries structured fields `type`, `title`, `description`, `resource`, `tags`, `timestamp`; orange-red requires all six on every concept. Unknown keys preserved, not rejected. | okf/SPEC.md §4.1 |
| R3 | `resource` = URI uniquely identifying underlying asset. Use for source URL link. | okf/SPEC.md §4.1 |
| R4 | Reserved filenames `index.md` (directory listing, §6) and `log.md` (update history, §7) MUST NOT be concept docs. | okf/SPEC.md §3.1 |
| R5 | `log.md`: newest first, ISO 8601 timestamps with microsecond precision, `**Update**`/`**Creation**` bold-word convention. | okf/SPEC.md §7 |
| R6 | Links: bundle-relative `/tables/x.md` (recommended) or relative `./x.md`. Consumers MUST tolerate broken links. | okf/SPEC.md §5 |
| R7 | Conformance: every non-reserved `.md` has parseable frontmatter + non-empty `type`; reserved files follow §6/§7. Consumers permissive on everything else. | okf/SPEC.md §9 |
| R8 | Bundle SHOULD ship as git repo (history, attribution, diffs). | okf/SPEC.md §3 |
| R9 | Citations under `# Citations` heading, numbered, links may be URLs or bundle-relative. | okf/SPEC.md §8 |
| R10 | pgvector adds `vector` column type + ANN index; official `pgvector/pgvector:pg18` image ships extension. Enable per-DB with `CREATE EXTENSION vector`. | github.com/pgvector/pgvector README |
| R11 | OpenAI embeddings API accepts `POST https://api.openai.com/v1/embeddings` with `OPENAI_API_KEY`. | platform.openai.com/docs/api-reference/embeddings |
| R12 | OpenAI `text-embedding-3-large` produces 3072-dimensional embeddings. | platform.openai.com/docs/guides/embeddings |


## §V

```
V1  | one crawled page maps to exactly one OKF concept file
V2  | every non-reserved .md in orange-red-data/ parses as YAML frontmatter + body, required frontmatter fields present and non-empty
V3  | index.md and log.md are never concept docs (reserved, follow §6/§7 shape)
V4  | every concept describing fetched resource sets resource = canonical final response URL
V5  | re-crawl of same canonical URL updates its concept + appends root and host log entries with microsecond timestamp, no duplicate concept
V6  | Postgres rows are fully rebuildable from bundle on disk (index only, no unique truth)
V7  | crawler honors robots.txt setting, depth limit, delay, allowed-hosts guard, timeout, retries, max resource size
V8  | crawled content sanitized/validated at extraction boundary before write; concept body markdown-only
V9  | HTML and PDF each convert to conformant OKF concept; Office formats out of v1
V10 | bundle-relative and external links in a concept do not break OKF conformance (broken links tolerated)
V11 | schema changes ship as Alembic migrations, applied idempotently
V12 | query returns top 10 concepts ranked by cosine similarity with path, title, resource URL, score, snippet
V13 | chat returns answer with concept citations or insufficient-information response when retrieval threshold not met
V14 | index rebuild is transactional; failed rebuild leaves previous complete index intact
V15 | every crawl creates local data-repo commit; push failure leaves commit intact and exits nonzero
V16 | partial crawl commits successful concepts + run/error records and exits nonzero on failures
V17 | runtime deps match stack: pyproject imports Scrapy, SQLAlchemy 2, Alembic, pgvector, psycopg3, OpenAI client, HTML/PDF/markdown/token libs; psycopg2 absent unless justified
V18 | devcontainer image + pyproject require Python 3.14; verification fails outside 3.14.x runtime
V19 | devcontainer compose exports every env var required by CLI commands, including OPENAI_API_KEY
V20 | canonical URL to concept path is deterministic + collision-free across trailing slash/index variants, percent-encoding, unsafe filename chars, and query strings
V21 | crawl classifies each skipped/failed URL as ignored, skipped, or required-failed; only required-failed exits nonzero; every nonzero crawl records stage/url/message
V22 | untrusted metadata serialized into YAML frontmatter is escaped/quoted so frontmatter stays parseable and cannot inject extra documents or keys
V23 | DB enforces unique concept.path, unique chunk(concept_id, ord), FK links, and atomic chunk replacement so no mixed old/new index is queryable
```

## §T

```
id  | status | task | cites
T1  | x | scaffold `orange_red` package + `pyproject.toml` console script | I.cli
T2  | x | OKF writer: frontmatter+body serializer, required YAML fields + microsecond timestamp | V2,I.okf
T3  | . | OKF conformance validator for required frontmatter fields and reserved docs | V2,V3
T4  | . | heuristic type classifier with controlled type set | V1,I.okf
T5  | . | HTML extractor to sanitized markdown-only OKF concept | V8,V9
T6  | . | PDF extractor to sanitized markdown-only OKF concept under site-host path | V8,V9,I.okf
T7  | . | defer Office conversion outside v1 and exclude from converter dispatch | V9
T8  | . | Scrapy spider config: allowed hosts, robots setting, depth, delay, timeout, retries, max size, dedup | V7,I.config
T9  | . | URL canonicalization + page-to-concept path mapping with query hash | V1,V4,I.okf
T10 | . | incremental update: rewrite concept + append root and host log entries, no dup | V5,I.okf
T11 | . | ignored nested `orange-red-data/` clone workflow, workspace file, git commit + push behavior | V15,I.okf
T12 | . | swap dev DB to `pgvector/pgvector:pg18`, add pgvector extension + Python client | V11,V12,I.embedding
T13 | . | Alembic migrations: concept, chunk, run, error tables | V11,I.tables
T14 | . | heading-aware chunking + OpenAI embedding + cosine pgvector upsert | V6,V12,I.embedding
T15 | . | transactional index rebuild command from bundle on disk | V6,V14,I.cli
T16 | . | semantic query command over pgvector with top 10 metadata + snippet output | V12,I.cli
T17 | . | chat command: retrieve, threshold, OpenAI answer, concept citations | V13,I.cli
T18 | . | per-command env validation for model keys and crawler config | V7,V13,I.config
T19 | . | crawl run/error recording and partial failure exit behavior | V16,I.tables
T20 | . | declare runtime deps in pyproject; remove psycopg2 baseline drift | V17,I.stack
T21 | . | pin devcontainer Python image and pyproject requires-python to 3.14 | V18,I.package
T22 | . | wire OPENAI_API_KEY through compose/devcontainer/docs | V19,I.config
T23 | . | canonical path mapper with stable query hash + collision tests | V20,I.okf
T24 | . | crawl outcome taxonomy ignored/skipped/required-failed + error persistence | V21,I.tables
T25 | . | YAML frontmatter serializer escapes untrusted metadata before write | V22,I.okf
T26 | . | Alembic constraints for unique paths, chunk ord, FKs, atomic rebuild guard | V23,I.tables
T27 | . | update README setup/config/usage to match CLI, data repo, OpenAI, pgvector | I.cli,I.config
```

## §B

```
id | date | cause | fix
```
