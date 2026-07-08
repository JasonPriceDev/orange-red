# orange-red

A Python project with PostgreSQL backend, Docker support, and comprehensive development tooling.

## Project Description

orange-red is a Python application that provides [describe your project's purpose here]. It includes a PostgreSQL database backend and is designed to be developed and deployed using Docker containers.

## Prerequisites

- Docker and Docker Compose
- VS Code with Dev Containers extension (for local development)
- Python 3.14+ (if running outside the container)
- PostgreSQL 15+ (if running outside the container)

## Setup & Installation

### Using Dev Container (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/JasonPriceDev/orange-red.git
   cd orange-red
   ```

2. Open in VS Code with Dev Containers:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
   - Select "Dev Containers: Open Folder in Container"
   - VS Code will automatically build the container and install dependencies

3. The container will automatically:
   - Configure your git user from `.devcontainer/.env`
   - Install Python dependencies from `requirements.txt` and `requirements-dev.txt`
   - Set up GitHub CLI and SSH access to your repositories
   - Start the PostgreSQL database

### Local Setup (Without Container)

1. Clone the repository and create a virtual environment:
   ```bash
   git clone https://github.com/JasonPriceDev/orange-red.git
   cd orange-red
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   pip install -r requirements-dev.txt
   ```

3. Set up PostgreSQL and configure the database connection in your environment.

## Configuration

Create a `.devcontainer/.env` file with the following variables (example provided):
```env
DEEP_SEEK_API_KEY=your_api_key_here
OPENROUTER_API_KEY=your_api_key_here
GIT_USERNAME=Your Name
GIT_EMAIL=your.email@example.com
```

Database connection is configured via `DATABASE_URL` in the dev container and points to PostgreSQL at `postgresql://postgres:postgres@db:5432/postgres`.

## Copilot CLI & BYOK Models

The dev container is pre-configured to support **Bring Your Own Key (BYOK)** models in GitHub Copilot CLI. This allows you to use custom LLM providers (like OpenRouter or DeepSeek's direct API) instead of the default GitHub-hosted models.

### Switcher Functions

Three helper functions are added to your shell environment (`~/.bashrc`) to easily switch providers:

1. **OpenRouter (Default: DeepSeek V4 Pro)**
   ```bash
   copilot-openrouter
   ```
   Sets up Copilot CLI to use OpenRouter (`https://openrouter.ai/api/v1`) with the `deepseek/deepseek-v4-pro` model.
   - To override the model: `copilot-openrouter anthropic/claude-3.5-sonnet`

2. **DeepSeek Direct (Default: DeepSeek V4 Pro)**
   ```bash
   copilot-deepseek
   ```
   Sets up Copilot CLI to use DeepSeek's direct API (`https://api.deepseek.com/v1`) with the `deepseek-v4-pro` model.
   - To override the model: `copilot-deepseek deepseek-v4-flash`

3. **Default GitHub Copilot**
   ```bash
   copilot-default
   ```
   Unsets all BYOK environment variables and restores Copilot CLI to default GitHub-hosted models.

### Token Limits & Catalog Warnings

Because custom models like `deepseek-v4-pro` are not in Copilot CLI's built-in model catalog, the switcher functions automatically configure explicit token limits to prevent catalog warnings and ensure optimal performance:
- `COPILOT_PROVIDER_MAX_PROMPT_TOKENS=200000`
- `COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=65536`

## Agent Skills

Agent skills (`SKILL.md` bundles that give Copilot/agents domain knowledge) live in **two directories**, split by origin:

| Directory | Contents | How to add |
| --- | --- | --- |
| `.agents/skills/` | Third-party skills installed via a CLI — the `caveman*`/`cavecrew` family and `frontend-design` | See installers below |
| `.github/skills/` | Repo-native, hand-authored skills (e.g. `gh-cli`) | Author `SKILL.md` by hand |

VS Code Copilot discovers skills from **both** locations automatically. `.agents/skills/` is the standard output path for CLI installers, so it is the source of truth for everything installed that way — don't move those copies into `.github/`, a dev-container rebuild just re-creates them under `.agents/`.

Installers run from `scripts/post-create.sh` on every container rebuild:

- **caveman family** — `curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash`
- **other skills** — `npx skills add <repo-url> --skill <name>`

The caveman installer re-runs **only when the upstream repo has new commits**: `post-create.sh` records the repo's last-commit epoch in `.agents/skills/.caveman-installed-epoch` and compares it against the tip of `main` (via the GitHub API) on each rebuild. If the API is unreachable it falls back to a plain "install if missing" check.

> The caveman installer also drops a stray singular `agent/` mirror; `post-create.sh` removes it so only the standard `.agents/` tree remains.

## Cross-agent memory (cavemem)

[`cavemem`](https://github.com/JuliusBrussee/cavemem) gives coding agents persistent, compressed memory across sessions (local SQLite, no cloud). It's installed globally (`npm install -g cavemem`, idempotent guard in `scripts/post-create.sh`) and wired for **both query and capture**:

- **Query (MCP)** — registered in `.vscode/mcp.json` so Copilot gets `search`, `timeline`, `get_observations` tools.
- **Capture (hooks)** — `~/.copilot/hooks/cavemem.json` fires on `SessionStart`, `UserPromptSubmit`, `PostToolUse`, and `Stop` events. Copilot has no `SessionEnd`, so that event is absent (same as Codex). The published npm release lacks a `--ide copilot` installer, so `post-create.sh` writes this file by hand in the same format the main-branch installer produces.

Data lives at `~/.cavemem` (outside the repo, nothing to gitignore). Useful commands: `cavemem status`, `cavemem search "<query>"`, `cavemem viewer`.

> Once npm publishes a release with `--ide copilot`, the manual hooks-writing step can be dropped from `post-create.sh` in favor of `cavemem install --ide copilot`.

## Development

### Available Tools

- **Python**: 3.14
- **Testing**: pytest
- **Linting**: ruff, black, mypy
- **REPL**: ipython, ipdb
- **API Client**: httpie
- **Version Control**: git, GitHub CLI (gh)

### Running Tests

```bash
pytest
```

### Code Quality

Format code with black:
```bash
black .
```

Lint with ruff:
```bash
ruff check .
```

Type check with mypy:
```bash
mypy .
```

### Interactive Development

Use ipython for interactive exploration:
```bash
ipython
```

Debug with ipdb by adding breakpoints in your code:
```python
import ipdb; ipdb.set_trace()
```

## Usage Examples

[Add your usage examples here]

Example:
```python
# Import and use your main module
from orange_red import main

result = main()
print(result)
```

## Database

PostgreSQL is automatically started in the dev container on port 5432. Connection details:
- Host: `db` (in container) or `localhost` (from host)
- User: `postgres`
- Password: `postgres`
- Database: `postgres`

To connect from the host:
```bash
psql postgresql://postgres:postgres@localhost:5432/postgres
```

## GitHub Integration

The dev container is configured with:
- SSH key sharing from your host machine
- GitHub CLI (gh) for repository operations
- GitHub Copilot and Copilot Chat for AI assistance

Run `gh auth status` to verify authentication.

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes and commit: `git commit -am "Add your feature"`
3. Push to your fork or branch: `git push origin feature/your-feature`
4. Create a Pull Request with a clear description of the changes

### Code Standards

- Follow PEP 8 style guidelines (enforced by black and ruff)
- Write type hints for all functions
- Include docstrings for modules, classes, and functions
- Add tests for new functionality
- Ensure all tests pass before submitting PR

## Troubleshooting

### SSH Key Issues in Container

If you encounter "Permission denied (publickey)" errors:
1. Ensure your SSH key is added to the SSH agent on your host: `ssh-add ~/.ssh/id_rsa`
2. Rebuild the dev container to reload SSH configuration
3. Verify with `ssh -T git@github.com` inside the container

### Database Connection Issues

If the database fails to connect:
1. Check that the `db` service is running: `docker ps | grep db`
2. Verify DATABASE_URL is set correctly
3. Restart the container and database

### Dev Container Rebuild

To rebuild the container after configuration changes:
1. Press `Ctrl+Shift+P` in VS Code
2. Select "Dev Containers: Rebuild Container"

## License

See [LICENSE](LICENSE) for details.

## Contact

For questions or issues, please open a GitHub Issue or contact the maintainers.