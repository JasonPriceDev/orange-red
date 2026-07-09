# orange-red

Intranet scraper for configured hosts. It crawls HTML/PDF resources, writes an
ignored nested `orange-red-data/` OKF markdown bundle, versions that bundle in
its own git repo, rebuilds a PostgreSQL 18 + pgvector semantic index, and serves
query/chat through the `orange-red` CLI with source citations.

## Prerequisites

- Docker and Docker Compose
- VS Code with Dev Containers extension
- Python 3.14.x when running outside container
- PostgreSQL 18 with pgvector when running outside container
- OpenAI API key for `index`, `query`, and `chat`

## Dev container setup

1. Clone and open repository:
   ```bash
   git clone https://github.com/JasonPriceDev/orange-red.git
   cd orange-red
   code .
   ```

2. Create `.devcontainer/.env` from `.devcontainer/.env.example` and set at
   least:
   ```env
   OPENAI_API_KEY=your_openai_api_key_here
   DATABASE_URL=postgresql://postgres:postgres@db:5432/postgres
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=postgres
   POSTGRES_DB=postgres
   GIT_USERNAME="Your Name"
   GIT_EMAIL="your.email@example.com"
   ```

3. Reopen in container. The stack starts:
   - Python 3.14 devcontainer
   - `pgvector/pgvector:pg18` database
   - editable `orange-red` Python package from `pyproject.toml`
   - GitHub CLI and agent tooling

## Data repo

Crawler output lives in ignored nested clone `orange-red-data/`:

```text
orange-red-data/
├── index.md
├── log.md
└── <site-host>/
    ├── index.md
    ├── log.md
    └── <url-path>.md
```

`orange-red-data/` is its own git repository and OKF bundle root. It is not a
submodule. The parent repo ignores it via `.gitignore`.

## Configuration

Required env vars:

| Variable | Used by | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | `index`, `query`, `chat`, migrations | PostgreSQL connection string |
| `OPENAI_API_KEY` | `index`, `query`, `chat` | OpenAI embeddings/chat key |
| `ORANGE_RED_ALLOWED_HOSTS` | `crawl` | Comma-separated allowlist; start URL does not imply allowlist |
| `ORANGE_RED_BUNDLE_DIR` | all CLI commands | Bundle path, default `orange-red-data` |
| `ORANGE_RED_DEPTH_LIMIT` | `crawl` | Default `2` |
| `ORANGE_RED_DOWNLOAD_DELAY` | `crawl` | Default `1` second |
| `ORANGE_RED_AUTOTHROTTLE` | `crawl` | Default enabled |
| `ORANGE_RED_OBEY_ROBOTS` | `crawl` | Default enabled |
| `ORANGE_RED_REQUEST_TIMEOUT` | `crawl` | Default `30` seconds |
| `ORANGE_RED_RETRY_TIMES` | `crawl` | Default `2` |
| `ORANGE_RED_MAX_RESOURCE_BYTES` | `crawl` | Default `25 MB` |
| `ORANGE_RED_CHAT_THRESHOLD` | `chat` | Default cosine similarity threshold `0.70` |

OpenAI contract:

- Embeddings: `text-embedding-3-large`, 3072 dimensions,
  `https://api.openai.com/v1/embeddings`
- Chat: `gpt-5.4`, `https://api.openai.com/v1/chat/completions`

## CLI

```bash
orange-red crawl https://intranet.example/
orange-red index
orange-red query "vacation policy"
orange-red chat "What does the bundle say about vacation rollover?"
```

Current command scaffolding exists; feature tasks are tracked in `SPEC.md`.

## Development

Install locally:

```bash
python3.14 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e .
pip install -r requirements-dev.txt
```

Quality checks:

```bash
ruff check .
black --check .
mypy orange_red
pytest
```

Run migrations:

```bash
alembic upgrade head
```

## Design constraints

- Crawl only configured allowed hosts.
- HTML/PDF convert to OKF markdown concepts; Office formats are deferred.
- Concept frontmatter is serialized as YAML with required fields:
  `type`, `title`, `description`, `resource`, `tags`, `timestamp`.
- Untrusted metadata is YAML-escaped before writing frontmatter.
- Concept body is markdown-only; raw HTML is rejected.
- URL identity is canonical final response URL; fragments ignored, query string
  counts, concept paths use stable query hash when needed.
- Postgres rows are rebuildable from bundle on disk; bundle remains source of
  truth.
