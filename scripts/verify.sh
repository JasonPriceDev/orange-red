#!/bin/bash
# verify.sh — smoke-test every tool, service, and extension in the devcontainer.
# Exits 0 on all-pass, 1 if any check fails.
# No set -e: we count failures explicitly, never abort early.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

check() {
    local label="$1"
    shift
    if "$@" &>/dev/null; then
        echo -e "  ${GREEN}PASS${NC}  $label"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $label"
        ((FAIL++))
    fi
}

warn() {
    local label="$1"
    shift
    if "$@" &>/dev/null; then
        echo -e "  ${GREEN}PASS${NC}  $label"
        ((PASS++))
    else
        echo -e "  ${YELLOW}WARN${NC}  $label (non-critical)"
        ((WARN++))
    fi
}

echo ""
echo "══════════════════════════════════════════════"
echo "  Devcontainer Verification"
echo "══════════════════════════════════════════════"

# ── System tools ──────────────────────────────────────────────
echo ""
echo "── System tools (apt) ──"
check "curl"            command -v curl
check "jq"              command -v jq
check "htop"            command -v htop
check "tree"            command -v tree
check "wget"            command -v wget
check "less"            command -v less
check "netstat"         command -v netstat
check "nslookup"        command -v nslookup
check "psql client"     command -v psql
check "micro editor"    command -v micro
check "chromium"        test -x /usr/bin/chromium

# ── Core runtimes ─────────────────────────────────────────────
echo ""
echo "── Core runtimes ──"
check "python3.14"      python3 -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 14) else 1)'
check "pip3"            pip3 --version
check "node"            node --version
check "npm"             npm --version
check "git"             git --version
check "docker CLI"      docker --version
check "docker daemon"   docker info

# ── GitHub ecosystem ──────────────────────────────────────────
echo ""
echo "── GitHub ecosystem ──"
check "gh CLI"          gh --version
warn  "gh auth status"  gh auth status

# ── npm global packages ───────────────────────────────────────
echo ""
echo "── npm global packages ──"
check "copilot CLI"     command -v copilot
check "chrome-devtools-mcp" command -v chrome-devtools-mcp || true
check "cavemem"         command -v cavemem
check "caveman-code"    command -v caveman-code

# ── Python packages ───────────────────────────────────────────
echo ""
echo "── Python packages ──"
check "orange_red"      python3 -c "import orange_red"
check "psycopg3"        python3 -c "import psycopg"
check "sqlalchemy"      python3 -c "import sqlalchemy"
check "alembic"         python3 -c "import alembic"
check "pgvector"        python3 -c "import pgvector"
check "scrapy"          python3 -c "import scrapy"
check "openai"          python3 -c "import openai"
check "yaml"            python3 -c "import yaml"
check "ipython"         python3 -c "import IPython"
check "pytest"          python3 -c "import pytest"
check "ipdb"            python3 -c "import ipdb"
check "ruff"            python3 -c "import ruff" 2>/dev/null || ruff --version
check "black"           python3 -c "import black"
check "mypy"            python3 -c "import mypy"
check "httpie"          command -v http

# ── cavemem cross-agent memory ────────────────────────────────
echo ""
echo "── cavemem ──"
check "cavemem binary"  command -v cavemem
check "cavemem config"  test -f ~/.cavemem/settings.json
check "cavemem db"      test -f ~/.cavemem/data.db
warn  "cavemem worker"  bash -c 'curl -s --max-time 2 http://127.0.0.1:37777/health >/dev/null 2>&1 || cavemem status 2>/dev/null | grep -q "worker:.*running"'

# cavemem hooks for Copilot
check "hook file"       test -f ~/.copilot/hooks/cavemem.json
check "hook SessionStart"  grep -q 'session-start' ~/.copilot/hooks/cavemem.json 2>/dev/null
check "hook UserPromptSubmit" grep -q 'user-prompt-submit' ~/.copilot/hooks/cavemem.json 2>/dev/null
check "hook PostToolUse"  grep -q 'post-tool-use' ~/.copilot/hooks/cavemem.json 2>/dev/null
check "hook Stop"       grep -q '"Stop"' ~/.copilot/hooks/cavemem.json 2>/dev/null

# cavemem MCP registration
check "MCP config"      test -f /workspace/.vscode/mcp.json
check "MCP cavemem entry" grep -q 'cavemem' /workspace/.vscode/mcp.json 2>/dev/null

# cavemem IDE tracking
check "IDE registered"  bash -c 'cavemem status 2>/dev/null | grep -qv "ides:.*none"'
check "backfill complete" bash -c 'cavemem status 2>/dev/null | grep -q "100%"'

warn  "semantic search" bash -c 'cavemem search "cavemem" 2>/dev/null; test $? -eq 0'

# ── caveman skills ────────────────────────────────────────────
echo ""
echo "── Agent skills ──"
check "caveman"         test -f /workspace/.agents/skills/caveman/SKILL.md
check "caveman-commit"  test -f /workspace/.agents/skills/caveman-commit/SKILL.md
check "caveman-review"  test -f /workspace/.agents/skills/caveman-review/SKILL.md
check "caveman-compress" test -f /workspace/.agents/skills/caveman-compress/SKILL.md
check "caveman-help"    test -f /workspace/.agents/skills/caveman-help/SKILL.md
check "caveman-stats"   test -f /workspace/.agents/skills/caveman-stats/SKILL.md
check "cavecrew"        test -f /workspace/.agents/skills/cavecrew/SKILL.md
check "frontend-design" test -f /workspace/.agents/skills/frontend-design/SKILL.md
check "gh-cli"          test -f /workspace/.github/skills/gh-cli/SKILL.md

# ── Docker services ───────────────────────────────────────────
echo ""
echo "── Docker services ──"
warn  "pgvector postgres container" bash -c 'timeout 5 docker ps --format "{{.Image}} {{.Names}}" 2>/dev/null | grep -qiE "pgvector|postgres"'

# ── VS Code extensions (check installed on disk) ──────────────
echo ""
echo "── VS Code extensions ──"
EXT_DIR=""
for d in ~/.vscode-server/extensions ~/.vscode-remote/extensions; do
    test -d "$d" && EXT_DIR="$d" && break
done
ext_installed() { test -n "$EXT_DIR" && ls "$EXT_DIR" 2>/dev/null | grep -qi "$1"; }
# Copilot + Copilot Chat are built-in (ship with VS Code server, not in
# user extensions dir).  Verify via their globalStorage presence instead.
copilot_loaded() { test -d ~/.vscode-server/data/User/globalStorage/github.copilot* 2>/dev/null || ext_installed 'github.copilot'; }
copilot_chat_loaded() { test -d ~/.vscode-server/data/User/globalStorage/github.copilot-chat* 2>/dev/null || ext_installed 'github.copilot-chat'; }

check "ms-python.python"              ext_installed 'ms-python.python'
check "ms-python.vscode-pylance"      ext_installed 'ms-python.vscode-pylance'
check "ms-python.debugpy"             ext_installed 'ms-python.debugpy'
check "ms-azuretools.vscode-docker"   ext_installed 'ms-azuretools.vscode-docker'
check "GitHub.copilot (built-in)"     copilot_loaded
check "GitHub.copilot-chat (built-in)" copilot_chat_loaded
check "github.vscode-github-actions"  ext_installed 'github.vscode-github-actions'
check "Vizards.deepseek-v4"           ext_installed 'vizards.deepseek'
check "selfagency.z-models"           ext_installed 'selfagency.z-models'

# ── Copilot BYOK helpers ──────────────────────────────────────
echo ""
echo "── Copilot BYOK helpers ──"
check "copilot-openrouter in bashrc"  grep -q 'copilot-openrouter' ~/.bashrc 2>/dev/null || \
      grep -q 'copilot-openrouter' /workspace/scripts/post-create.sh 2>/dev/null
check "copilot-deepseek in bashrc"   grep -q 'copilot-deepseek' ~/.bashrc 2>/dev/null || \
      grep -q 'copilot-deepseek' /workspace/scripts/post-create.sh 2>/dev/null
check "copilot-default in bashrc"    grep -q 'copilot-default' ~/.bashrc 2>/dev/null || \
      grep -q 'copilot-default' /workspace/scripts/post-create.sh 2>/dev/null

# ── Configuration files ───────────────────────────────────────
echo ""
echo "── Config files ──"
check "copilot-instructions.md"  test -f /workspace/.github/copilot-instructions.md
check "devcontainer.json"        test -f /workspace/.devcontainer/devcontainer.json
check "docker-compose.yml"       test -f /workspace/.devcontainer/docker-compose.yml
check "Dockerfile"               test -f /workspace/.devcontainer/Dockerfile
check ".env exists"              test -f /workspace/.devcontainer/.env

# ── Environment variables ─────────────────────────────────────
echo ""
echo "── Environment ──"
check "PUPPETEER_EXECUTABLE_PATH" test -n "$PUPPETEER_EXECUTABLE_PATH"
warn  "DEEP_SEEK_API_KEY set"     test -n "$DEEP_SEEK_API_KEY"
warn  "OPENROUTER_API_KEY set"    test -n "$OPENROUTER_API_KEY"

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
TOTAL=$((PASS + FAIL + WARN))
echo "  Total: $TOTAL  |  ${GREEN}Pass: $PASS${NC}  |  ${RED}Fail: $FAIL${NC}  |  ${YELLOW}Warn: $WARN${NC}"
echo "══════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
