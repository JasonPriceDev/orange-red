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

# Set up a user-writable npm global prefix
NPM_PREFIX="$HOME/.npm-global"
mkdir -p "$NPM_PREFIX/bin"
npm config set prefix "$NPM_PREFIX"
if ! grep -q 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# Add user npm global bin directory\nexport PATH="$HOME/.npm-global/bin:$PATH"\n' >> "$HOME/.bashrc"
fi
export PATH="$NPM_PREFIX/bin:$PATH"

# Install Chrome DevTools MCP server
if ! command -v chrome-devtools-mcp >/dev/null 2>&1; then
    npm install -g --prefix "$NPM_PREFIX" chrome-devtools-mcp
fi

# Install GitHub Copilot CLI (the "copilot" binary that `gh copilot` wraps -
# not the old, now-deprecated gh-copilot extension)
if ! command -v copilot >/dev/null 2>&1; then
    npm install -g --prefix "$NPM_PREFIX" @github/copilot
fi

# Add Copilot CLI BYOK provider switching functions to bashrc
if ! grep -q 'copilot-deepseek()' "$HOME/.bashrc" 2>/dev/null; then
    cat <<'BASHRC_EOF' >> "$HOME/.bashrc"

# Copilot CLI BYOK provider switchers
# Auto-load .env keys if not already in environment
__copilot_load_env() {
    local env_file="/workspace/.devcontainer/.env"
    if [ -f "$env_file" ]; then
        set -a; source "$env_file"; set +a
    fi
}

copilot-default() {
    unset COPILOT_PROVIDER_BASE_URL COPILOT_PROVIDER_API_KEY COPILOT_PROVIDER_TYPE
    unset COPILOT_MODEL COPILOT_PROVIDER_MODEL_ID COPILOT_PROVIDER_WIRE_MODEL
    unset COPILOT_PROVIDER_MAX_PROMPT_TOKENS COPILOT_PROVIDER_MAX_OUTPUT_TOKENS
    echo "Copilot CLI → default (GitHub Copilot models)"
}

copilot-deepseek() {
    __copilot_load_env
    export COPILOT_PROVIDER_BASE_URL="https://api.deepseek.com/v1"
    export COPILOT_PROVIDER_API_KEY="$DEEP_SEEK_API_KEY"
    export COPILOT_PROVIDER_TYPE="openai"
    export COPILOT_MODEL="${1:-deepseek-v4-pro}"
    export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=200000
    export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=65536
    echo "Copilot CLI → DeepSeek ($COPILOT_MODEL)"
}

copilot-openrouter() {
    __copilot_load_env
    export COPILOT_PROVIDER_BASE_URL="https://openrouter.ai/api/v1"
    export COPILOT_PROVIDER_API_KEY="$OPENROUTER_API_KEY"
    export COPILOT_PROVIDER_TYPE="openai"
    export COPILOT_MODEL="${1:-deepseek/deepseek-v4-pro}"
    export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=200000
    export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=65536
    echo "Copilot CLI → OpenRouter ($COPILOT_MODEL)"
}
BASHRC_EOF
fi
