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
GIT_USERNAME=Your Name
GIT_EMAIL=your.email@example.com
```

Database connection is configured via `DATABASE_URL` in the dev container and points to PostgreSQL at `postgresql://postgres:postgres@db:5432/postgres`.

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