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

# ── Detect if stdin is a pipe (curl | bash) → read from /dev/tty ──
if [ ! -t 0 ]; then
  # stdin is piped (curl | bash) — redirect reads from terminal
  if [ -t 2 ] || [ -e /dev/tty ]; then
    exec 3</dev/tty  # open fd 3 from terminal
    TTY_FD=3
  else
    # No terminal available — fall back to non-interactive
    NON_INTERACTIVE=true
    TTY_FD=0
  fi
else
  TTY_FD=0  # stdin is terminal, use normally
fi

# ── Utility functions ──
info()  { echo -e "${GREEN}→${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
header() { echo -e "\n${CYAN}── $* ──${NC}"; }

prompt_input() {
  local prompt="$1" default="$2" result
  if [ "$NON_INTERACTIVE" = true ]; then echo "$default"; return; fi
  echo -n "  $prompt [$default]: "
  read result <&$TTY_FD
  echo "${result:-$default}"
}

prompt_select() {
  local prompt="$1"; shift
  local options=("$@")
  if [ "$NON_INTERACTIVE" = true ]; then echo "1"; return; fi
  echo ""
  for i in "${!options[@]}"; do
    echo "  [$((i+1))] ${options[$i]}"
  done
  echo -n "  $prompt: "
  local choice
  read choice <&$TTY_FD
  echo "${choice:-1}"
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
  header "Issue Source"
  SOURCE_CHOICE=$(prompt_select "Where are your issues? " "Linear" "GitHub Issues")

  case "$SOURCE_CHOICE" in
    1)
      SOURCE="linear"
      PROJECT_KEY=$(prompt_input "Linear project key (e.g., SKIN)" "PROJ")

      header "Linear Authentication"
      AUTH_CHOICE=$(prompt_select "Auth method? " "API Key (paste key)" "OAuth (opens browser)")

      case "$AUTH_CHOICE" in
        1)
          LINEAR_AUTH_METHOD="api_key"
          echo -n "  API Key: "; read -s LINEAR_API_KEY <&$TTY_FD; echo ""
          ;;
        2)
          LINEAR_AUTH_METHOD="oauth"
          ;;
      esac
      ;;
    2)
      SOURCE="github"
      GH_REPO=$(prompt_input "GitHub repo (e.g., org/repo)" "$(basename "$WORKSPACE")")
      ;;
  esac

  # ══════════════════════════════════════════════
  # Step 4: Project Configuration
  # ══════════════════════════════════════════════
  header "Project Configuration"
  REPO_KEY=$(prompt_input "Project name/key" "$(basename "$WORKSPACE")")
  BASE_URL=$(prompt_input "Dev server URL" "http://localhost:3000")
  DEV_COMMAND=$(prompt_input "Dev command" "bun run dev")
  BRANCH=$(prompt_input "Main branch" "dev")

  echo -n "  Use GitNexus for code analysis? [Y/n]: "; read USE_GITNEXUS <&$TTY_FD
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

  if ! command -v jq &>/dev/null; then
    warn "jq not available — skip MCP config for $config_file"
    return
  fi

  mkdir -p "$(dirname "$config_file")"

  if [ -f "$config_file" ] && [ -s "$config_file" ]; then
    # File exists and is non-empty — merge into existing config
    # Ensure mcpServers key exists before merging
    local tmp_file="${config_file}.tmp"
    jq --arg key "$mcp_key" --argjson val "$mcp_value" \
      'if .mcpServers then .mcpServers[$key] = $val else . + {mcpServers: {($key): $val}} end' \
      "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
  else
    # File doesn't exist or is empty — create new
    jq -n --arg key "$mcp_key" --argjson val "$mcp_value" \
      '{mcpServers: {($key): $val}}' > "$config_file"
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
