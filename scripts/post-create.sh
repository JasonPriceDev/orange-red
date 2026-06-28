#!/bin/bash
set -e

# Load environment variables from .devcontainer/.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.devcontainer/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Configure git user
if [ -n "$GIT_USERNAME" ]; then
    git config --global user.name "$GIT_USERNAME"
fi
if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL"
fi

# Install GitHub CLI if not present
if ! command -v gh >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y gh
        else
            apt-get update && apt-get install -y gh
        fi
    fi
fi

pip install --upgrade pip

if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

if [ -f requirements-dev.txt ]; then
    pip install -r requirements-dev.txt
fi

# Install GitHub Copilot CLI
if command -v npm &> /dev/null; then
    npm install -g @githubcopilot/cli
fi
