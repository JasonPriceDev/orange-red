#!/bin/bash
set -e

# Load environment variables from .devcontainer/.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

# Install caveman-code CLI (provides the `caveman-code` / `caveman` binaries)
if ! command -v caveman-code >/dev/null 2>&1; then
    npm install -g --prefix "$NPM_PREFIX" @juliusbrussee/caveman-code
fi

# Install cavemem CLI (cross-agent persistent memory). MCP registration lives
# in .vscode/mcp.json; Copilot session-capture hooks are written to
# ~/.copilot/hooks/cavemem.json (idempotent: only created if the hooks dir is
# empty). The published npm release has no --ide copilot installer yet, so we
# write the hooks file by hand — same format as the main-branch installer.
if ! command -v cavemem >/dev/null 2>&1; then
    npm install -g --prefix "$NPM_PREFIX" cavemem
    npm approve-scripts cavemem --yes 2>/dev/null || true
fi

if [ ! -f "$HOME/.copilot/hooks/cavemem.json" ]; then
    mkdir -p "$HOME/.copilot/hooks"
    cat > "$HOME/.copilot/hooks/cavemem.json" <<'CAVEMEM_HOOKS'
{
  "hooks": {
    "SessionStart": [
      { "type": "command", "command": "cavemem hook run session-start --ide copilot" }
    ],
    "UserPromptSubmit": [
      { "type": "command", "command": "cavemem hook run user-prompt-submit --ide copilot" }
    ],
    "PostToolUse": [
      { "type": "command", "command": "cavemem hook run post-tool-use --ide copilot" }
    ],
    "Stop": [
      { "type": "command", "command": "cavemem hook run stop --ide copilot" }
    ]
  }
}
CAVEMEM_HOOKS
fi

# Register cavemem IDE tracking so `cavemem status` doesn't show
# "ides: none".  Uses --ide codex (closest to Copilot's event model —
# no SessionEnd, same as Codex) since --ide copilot isn't shipped yet.
# ponytail: idempotent guard via cavemem status grep; re-runs only if
# no IDE is registered.
if cavemem status 2>/dev/null | grep -q 'ides:\s*none'; then
    cavemem install --ide codex
fi

# Install @xenova/transformers for cavemem's local embedding provider.
# cavemem ships with a bundled worker that loads it at runtime; without it
# semantic search silently degrades.  Idempotent: npm install -g is a
# no-op if already present.
npm install -g --prefix "$NPM_PREFIX" @xenova/transformers
npm approve-scripts @xenova/transformers --yes 2>/dev/null || true

# Install the caveman skill family (caveman, cavecrew, caveman-commit, etc.)
# via its official installer, pinned to a release tag.
#
# Re-run when upstream has a newer release. We stamp the installed release tag
# into a marker file and compare against the latest release (GitHub API) on
# every rebuild.
# ponytail: if the API is unreachable (offline / rate-limited) we fall back to a
# plain existence check so a rebuild never hard-fails on a network blip - the
# ceiling is that an offline rebuild won't pick up an update until it's online.
CAVEMAN_RELEASE="v1.9.1"

install_caveman_skills() {
    curl -fsSL "https://raw.githubusercontent.com/JuliusBrussee/caveman/${CAVEMAN_RELEASE}/install.sh" | bash
    # The installer also drops a stray singular `agent/` mirror - remove it so
    # only the standard `.agents/` tree remains.
    rm -rf "$WORKSPACE_ROOT/agent"
}

CAVEMAN_STAMP="$WORKSPACE_ROOT/.agents/skills/.caveman-installed-epoch"
# Latest release tag name (empty on any failure).
CAVEMAN_REMOTE_TAG="$(curl -fsSL "https://api.github.com/repos/JuliusBrussee/caveman/releases/latest" 2>/dev/null \
    | jq -r '.tag_name // empty' 2>/dev/null)"

if [ -n "$CAVEMAN_REMOTE_TAG" ]; then
    # Release-aware path: (re)install if never stamped or the tag changed.
    CAVEMAN_LOCAL_TAG="$(cat "$CAVEMAN_STAMP" 2>/dev/null || true)"
    if [ "$CAVEMAN_REMOTE_TAG" != "$CAVEMAN_LOCAL_TAG" ]; then
        CAVEMAN_RELEASE="$CAVEMAN_REMOTE_TAG" install_caveman_skills
        echo "$CAVEMAN_REMOTE_TAG" > "$CAVEMAN_STAMP"
    fi
elif [ ! -d "$WORKSPACE_ROOT/.agents/skills/caveman" ]; then
    # Offline fallback: install only if the skills are missing entirely.
    install_caveman_skills
fi

# Install third-party agent skills. `skills add` is idempotent - it re-copies
# into .agents/skills/ so this is safe to run on every rebuild.
if [ ! -d "$WORKSPACE_ROOT/.agents/skills/frontend-design" ]; then
    npx --yes skills add https://github.com/anthropics/skills --skill frontend-design
fi

# Add Copilot CLI BYOK provider switching functions to bashrc
if ! grep -q 'copilot-deepseek()' "$HOME/.bashrc" 2>/dev/null; then
    cat <<'BASHRC_EOF' >> "$HOME/.bashrc"

# Copilot CLI BYOK provider switchers
# Auto-load .env keys if not already in environment
__copilot_load_env() {
    local env_file="$WORKSPACE_ROOT/.devcontainer/.env"
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

copilot-openai() {
    __copilot_load_env
    export COPILOT_PROVIDER_BASE_URL="https://api.openai.com/v1"
    export COPILOT_PROVIDER_API_KEY="$OPENAI_API_KEY"
    export COPILOT_PROVIDER_TYPE="openai"
    export COPILOT_MODEL="${1:-gpt-4o}"
    export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=200000
    export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=65536
    echo "Copilot CLI → OpenAI ($COPILOT_MODEL)"
}
BASHRC_EOF
fi
