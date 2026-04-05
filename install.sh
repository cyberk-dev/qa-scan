#!/bin/bash
# QA Scan — Interactive Install Wizard
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
#   bash install.sh --non-interactive
#   bash install.sh --dir ~/.qa-scan
#
# Options:
#   --non-interactive   Skip wizard, use example config
#   --dir PATH          Custom install location (default: .agents/qa-scan or repo root)
#   --project-dir PATH  Workspace root (default: current directory)

set -euo pipefail

# ── Defaults ──
NON_INTERACTIVE=false
INSTALL_DIR=""
WORKSPACE="${QA_WORKSPACE:-$(pwd)}"
SOURCE=""
PROJECT_KEY=""
GH_REPO=""
LINEAR_AUTH_METHOD=""
LINEAR_API_KEY=""
REPO_KEY=""
BASE_URL="http://localhost:3000"
DEV_COMMAND="bun run dev"
BRANCH="dev"
USE_GITNEXUS="Y"

# ── Colors ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Parse args ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive) NON_INTERACTIVE=true; shift ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --project-dir) WORKSPACE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--non-interactive] [--dir PATH] [--project-dir PATH]"
      exit 0 ;;
    *) shift ;;
  esac
done

# ── Detect if terminal is available for interactive prompts ──
if [ ! -e /dev/tty ] && [ ! -t 0 ]; then
  NON_INTERACTIVE=true
fi

# ── Utility functions ──
info()  { echo -e "${GREEN}→${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
header() { echo -e "\n${CYAN}── $* ──${NC}"; }

# Use global PROMPT_RESULT to avoid $() subshell capturing display output
PROMPT_RESULT=""

prompt_input() {
  local prompt="$1" default="$2"
  if [ "$NON_INTERACTIVE" = true ]; then PROMPT_RESULT="$default"; return; fi
  echo -n "  $prompt [$default]: " > /dev/tty
  read PROMPT_RESULT < /dev/tty
  PROMPT_RESULT="${PROMPT_RESULT:-$default}"
}

prompt_select() {
  local prompt="$1"; shift
  local options=("$@")
  if [ "$NON_INTERACTIVE" = true ]; then PROMPT_RESULT="1"; return; fi
  echo "" > /dev/tty
  local i
  for i in $(seq 0 $((${#options[@]} - 1))); do
    echo "  [$((i+1))] ${options[$i]}" > /dev/tty
  done
  echo -n "  $prompt: " > /dev/tty
  read PROMPT_RESULT < /dev/tty
  PROMPT_RESULT="${PROMPT_RESULT:-1}"
}

# ══════════════════════════════════════════════
# Step 1: Environment Detection
# ══════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════╗"
echo "║     QA Scan — Install Wizard    ║"
echo "╚══════════════════════════════════╝"
echo ""

# Determine if running from repo or remote
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
IS_REPO=false
[ -f "$SCRIPT_DIR/agents/qa-orchestrator.md" ] && IS_REPO=true

# Detect OS
OS="$(uname -s)"
info "OS: $OS"

# Check/install bun
if ! command -v bun &>/dev/null; then
  info "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi
info "Bun $(bun --version)"

# Check jq
if ! command -v jq &>/dev/null; then
  info "Installing jq (needed for MCP config)..."
  if [ "$OS" = "Darwin" ]; then
    brew install jq 2>/dev/null || warn "Install jq manually: brew install jq"
  else
    sudo apt-get install -y jq 2>/dev/null || warn "Install jq manually: apt install jq"
  fi
fi

# Detect AI agent directories
HAS_CLAUDE=false; [ -d "$WORKSPACE/.claude" ] && HAS_CLAUDE=true
HAS_GEMINI=false; [ -d "$WORKSPACE/.gemini" ] && HAS_GEMINI=true
HAS_ANTIGRAVITY=false; [ -d "$WORKSPACE/.antigravity" ] && HAS_ANTIGRAVITY=true

if [ "$HAS_CLAUDE" = true ] || [ "$HAS_GEMINI" = true ] || [ "$HAS_ANTIGRAVITY" = true ]; then
  info "Detected AI agents: $([ "$HAS_CLAUDE" = true ] && echo "Claude ")$([ "$HAS_GEMINI" = true ] && echo "Gemini ")$([ "$HAS_ANTIGRAVITY" = true ] && echo "Antigravity")"
else
  info "No AI agent dirs detected — will create for Claude + Gemini"
  HAS_CLAUDE=true
  HAS_GEMINI=true
fi

# ══════════════════════════════════════════════
# Step 2: Clone/Update Repo
# ══════════════════════════════════════════════
if [ "$IS_REPO" = true ]; then
  QA_DIR="$SCRIPT_DIR"
  info "Running from repo: $QA_DIR"
else
  QA_DIR="${INSTALL_DIR:-$WORKSPACE/.agents/qa-scan}"
  if [ -d "$QA_DIR/.git" ]; then
    info "Updating qa-scan..."
    git -C "$QA_DIR" pull --ff-only 2>/dev/null || warn "Git pull failed — using existing version"
  else
    info "Cloning qa-scan..."
    mkdir -p "$(dirname "$QA_DIR")"
    git clone https://github.com/cyberk-dev/qa-scan.git "$QA_DIR"
  fi
fi

# ══════════════════════════════════════════════
# Step 3: Issue Source Wizard
# ══════════════════════════════════════════════
if [ "$NON_INTERACTIVE" = false ]; then
  header "Step 1: Issue Source"
  echo "  QA Scan fetches issues to test from Linear or GitHub." > /dev/tty
  echo "  Choose where your team tracks bugs and features." > /dev/tty
  prompt_select "Where are your issues?" "Linear" "GitHub Issues"

  case "$PROMPT_RESULT" in
    1)
      SOURCE="linear"
      echo "" > /dev/tty
      echo "  Enter your Linear project key (visible in issue IDs, e.g., SKIN-101 → key is SKIN)." > /dev/tty
      prompt_input "Linear project key" "PROJ"
      PROJECT_KEY="$PROMPT_RESULT"

      header "Step 2: Linear Authentication"
      echo "  QA Scan needs access to read your Linear issues." > /dev/tty
      echo "  API Key: paste a key from linear.app/settings/api (simpler)." > /dev/tty
      echo "  OAuth: browser login on first use (no key needed)." > /dev/tty
      prompt_select "Auth method?" "API Key (paste key)" "OAuth (browser login on first use)"

      case "$PROMPT_RESULT" in
        1)
          LINEAR_AUTH_METHOD="api_key"
          echo "" > /dev/tty
          echo "  Create at: https://linear.app/settings/api → Personal API Keys → Create." > /dev/tty
          echo -n "  API Key: " > /dev/tty; read -s LINEAR_API_KEY < /dev/tty; echo "" > /dev/tty
          ;;
        2)
          LINEAR_AUTH_METHOD="oauth"
          echo "" > /dev/tty
          echo "  No action needed now. On first /qa-scan run, the Linear MCP" > /dev/tty
          echo "  server will open your browser for authorization automatically." > /dev/tty
          ;;
      esac
      ;;
    2)
      SOURCE="github"
      echo "" > /dev/tty
      echo "  Enter the GitHub repo where issues are tracked (e.g., cyberk-dev/my-app)." > /dev/tty
      echo "  Make sure 'gh' CLI is logged in: gh auth status" > /dev/tty
      prompt_input "GitHub repo (org/repo)" "$(basename "$WORKSPACE")"
      GH_REPO="$PROMPT_RESULT"
      ;;
  esac

  # ══════════════════════════════════════════════
  # Step 4: Project Configuration
  # ══════════════════════════════════════════════
  header "Step 3: Project Configuration"
  echo "  Configure the project QA Scan will test." > /dev/tty
  echo "" > /dev/tty

  echo "  Unique name for this project in qa.config.yaml." > /dev/tty
  prompt_input "Project name/key" "$(basename "$WORKSPACE")"
  REPO_KEY="$PROMPT_RESULT"

  echo "  URL where your dev server runs (Playwright connects here)." > /dev/tty
  prompt_input "Dev server URL" "http://localhost:3000"
  BASE_URL="$PROMPT_RESULT"

  echo "  Command to start your dev server (used for auto-start if server is down)." > /dev/tty
  prompt_input "Dev command" "bun run dev"
  DEV_COMMAND="$PROMPT_RESULT"

  echo "  Git branch to test against." > /dev/tty
  prompt_input "Main branch" "dev"
  BRANCH="$PROMPT_RESULT"

  echo "" > /dev/tty
  echo "  GitNexus provides semantic code analysis (find symbols, trace impact)." > /dev/tty
  echo "  Requires 'gitnexus' CLI installed. Skip if unsure." > /dev/tty
  echo -n "  Use GitNexus for code analysis? [Y/n]: " > /dev/tty; read USE_GITNEXUS < /dev/tty
  USE_GITNEXUS="${USE_GITNEXUS:-Y}"
fi

# ══════════════════════════════════════════════
# Step 5: Write Config
# ══════════════════════════════════════════════
cd "$QA_DIR"

if [ "$NON_INTERACTIVE" = true ]; then
  if [ ! -f config/qa.config.yaml ]; then
    cp config/qa.config.example.yaml config/qa.config.yaml 2>/dev/null || true
    warn "Non-interactive: edit config/qa.config.yaml manually"
  fi
else
  info "Writing config..."
  mkdir -p config
  cat > config/qa.config.yaml << YAML
# QA Scan Configuration — generated by install wizard
defaults:
  video: true
  trace: true
  screenshots: true
  evidence_dir: ./evidence
  selectors: accessibility-first
  self_healing_retries: 1

repos:
  ${REPO_KEY}:
    path: ${WORKSPACE}
    base_url: ${BASE_URL}
    dev_command: ${DEV_COMMAND}
    source: ${SOURCE}
$([ "$SOURCE" = "linear" ] && echo "    project_key: ${PROJECT_KEY}")
$([ "$SOURCE" = "github" ] && echo "    repo: ${GH_REPO}")
    branch: ${BRANCH}
    gitnexus: $([[ "${USE_GITNEXUS}" =~ ^[Yy] ]] && echo "true" || echo "false")
    auth:
      strategy: skip

labels:
  pass: "qa-auto-passed"
  fail: "qa-auto-failed"
  partial: "qa-needs-manual"

auto_post:
  enabled: false
  format: summary

orchestrator:
  poll_interval: 600
  delay_between_issues: 30
  max_issues_per_run: 10
YAML
fi

# ══════════════════════════════════════════════
# Step 5b: MCP Auto-Config
# ══════════════════════════════════════════════
configure_mcp() {
  local config_file="$1"
  local mcp_key="$2"
  local mcp_value="$3"
  local tmp_file="/tmp/qa-scan-mcp-$$.json"

  if ! command -v jq &>/dev/null; then
    warn "jq not available — skip MCP config for $config_file"
    return
  fi

  mkdir -p "$(dirname "$config_file")" 2>/dev/null || true

  if [ -f "$config_file" ] && [ -s "$config_file" ]; then
    # Merge into existing config
    jq --arg key "$mcp_key" --argjson val "$mcp_value" \
      'if .mcpServers then .mcpServers[$key] = $val else . + {mcpServers: {($key): $val}} end' \
      "$config_file" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$config_file"
  else
    # Create new — write to /tmp first, then move
    jq -n --arg key "$mcp_key" --argjson val "$mcp_value" \
      '{mcpServers: {($key): $val}}' > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$config_file"
  fi
}

if [ "$NON_INTERACTIVE" = false ]; then
  header "MCP Configuration"

  # Linear MCP
  if [ "$SOURCE" = "linear" ]; then
    if [ "$LINEAR_AUTH_METHOD" = "api_key" ] && [ -n "$LINEAR_API_KEY" ]; then
      MCP_LINEAR=$(jq -n --arg key "$LINEAR_API_KEY" \
        '{command:"npx",args:["-y","@linear/mcp-server"],env:{LINEAR_API_KEY:$key}}')
    else
      MCP_LINEAR='{"command":"npx","args":["-y","@linear/mcp-server","--oauth"]}'
    fi

    if [ "$HAS_CLAUDE" = true ]; then
      configure_mcp "$WORKSPACE/.claude/mcp.json" "linear" "$MCP_LINEAR"
      info "Linear MCP → .claude/mcp.json"
    fi
    if [ "$HAS_GEMINI" = true ]; then
      configure_mcp "$WORKSPACE/.gemini/settings.json" "linear" "$MCP_LINEAR"
      info "Linear MCP → .gemini/settings.json"
    fi
  fi

  # GitNexus MCP
  if [[ "${USE_GITNEXUS}" =~ ^[Yy] ]] && command -v gitnexus &>/dev/null; then
    MCP_GITNEXUS='{"command":"gitnexus","args":["mcp"]}'
    if [ "$HAS_CLAUDE" = true ]; then
      configure_mcp "$WORKSPACE/.claude/mcp.json" "gitnexus" "$MCP_GITNEXUS"
      info "GitNexus MCP → .claude/mcp.json"
    fi
    if [ "$HAS_GEMINI" = true ]; then
      configure_mcp "$WORKSPACE/.gemini/settings.json" "gitnexus" "$MCP_GITNEXUS"
      info "GitNexus MCP → .gemini/settings.json"
    fi
  fi
fi

# ══════════════════════════════════════════════
# Step 6: Install Dependencies
# ══════════════════════════════════════════════
header "Dependencies"
info "Installing Playwright..."
bun install 2>/dev/null
npx playwright install chromium 2>/dev/null

# Evidence files
mkdir -p evidence/logs
[ -f evidence/hotspot-memory.json ] || echo "[]" > evidence/hotspot-memory.json
[ -f evidence/qa-tracker.json ] || echo "[]" > evidence/qa-tracker.json
[ -f evidence/flaky-memory.json ] || echo "[]" > evidence/flaky-memory.json

# GitNexus initial index
if [[ "${USE_GITNEXUS}" =~ ^[Yy] ]] && command -v gitnexus &>/dev/null; then
  info "Indexing codebase with GitNexus..."
  gitnexus analyze --incremental "$WORKSPACE" 2>/dev/null || warn "GitNexus indexing skipped"
fi

# ══════════════════════════════════════════════
# Step 7: Install Agents
# ══════════════════════════════════════════════
header "Agents"

# Claude Code
if [ "$HAS_CLAUDE" = true ]; then
  mkdir -p "$WORKSPACE/.claude/agents" "$WORKSPACE/.claude/skills/qa-scan"
  for f in agents/qa-*.md; do [ -f "$f" ] && cp "$f" "$WORKSPACE/.claude/agents/"; done
  cp adapters/claude-skill.md "$WORKSPACE/.claude/skills/qa-scan/SKILL.md" 2>/dev/null || true
  info "Claude agents installed"
fi

# Gemini CLI
if [ "$HAS_GEMINI" = true ]; then
  mkdir -p "$WORKSPACE/.gemini/agents"
  for f in agents/qa-*.md; do [ -f "$f" ] && cp "$f" "$WORKSPACE/.gemini/agents/"; done
  info "Gemini agents installed"
fi

# Antigravity
if [ "$HAS_ANTIGRAVITY" = true ]; then
  mkdir -p "$WORKSPACE/.antigravity"
  cp adapters/antigravity-adapter.md "$WORKSPACE/.antigravity/qa-scan.md" 2>/dev/null || true
  info "Antigravity adapter installed"
fi

# ══════════════════════════════════════════════
# Step 8: Verify + Usage
# ══════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════╗"
echo "║        Setup Complete!          ║"
echo "╚══════════════════════════════════╝"
echo ""

REPO_KEY="${REPO_KEY:-project}"

if [ "$HAS_CLAUDE" = true ]; then
  echo "  Claude Code:  /qa-scan ${REPO_KEY^^}-001"
fi
if [ "$HAS_GEMINI" = true ]; then
  echo "  Gemini CLI:   @qa-orchestrator scan ${REPO_KEY^^}-001"
fi
echo "  Any agent:    Follow .agents/qa-scan/workflow.md"
echo ""
echo "  Config:       $QA_DIR/config/qa.config.yaml"
echo "  Verify:       bash $QA_DIR/scripts/verify.sh"
echo ""
