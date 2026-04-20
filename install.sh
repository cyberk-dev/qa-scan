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

# ── CI/CD Detection ──
IS_CI=false
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ] || \
   [ -n "${CIRCLECI:-}" ] || [ -n "${JENKINS_URL:-}" ] || [ -n "${TF_BUILD:-}" ] || \
   [ -n "${BITBUCKET_BUILD_NUMBER:-}" ] || [ -n "${TRAVIS:-}" ] || [ -n "${BUILDKITE:-}" ]; then
  IS_CI=true
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

# ── macOS Bootstrap ──
bootstrap_macos() {
  if [ "$IS_CI" = true ] || [ "$NON_INTERACTIVE" = true ]; then
    info "Non-interactive mode — skipping macOS GUI bootstrap"
    if ! xcode-select -p &>/dev/null; then
      warn "Xcode CLT required but not found. Install manually: xcode-select --install"
      warn "Then re-run this script."
      exit 1
    fi
    return 0
  fi

  if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
    warn "No TTY available for interactive prompts."
    warn "Run with --non-interactive or install Xcode CLT manually first."
    exit 1
  fi

  if ! xcode-select -p &>/dev/null; then
    warn "Xcode Command Line Tools not found"
    echo "  Installing CLT (this may open a dialog)..."
    xcode-select --install 2>/dev/null || true

    echo "  Waiting for CLT installation to complete..."
    echo "  (This may take several minutes. Press Ctrl+C to abort.)"
    local attempts=0
    local max_attempts=360
    while ! xcode-select -p &>/dev/null; do
      sleep 5
      attempts=$((attempts + 1))
      if [ "$attempts" -ge "$max_attempts" ]; then
        warn "CLT installation timed out after 30 minutes."
        exit 1
      fi
    done
  fi
  info "Xcode CLT: $(xcode-select -p)"

  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  if command -v brew &>/dev/null; then
    info "Homebrew $(brew --version | head -1)"
  else
    warn "Homebrew installation may require terminal restart"
  fi
}

# ── Linux Bootstrap ──
bootstrap_linux() {
  if ! command -v apt-get &>/dev/null; then
    warn "apt-get not found. This script supports Debian/Ubuntu-based systems."
    warn "For other distros, install manually: git, jq, gh, bun"
    return 1
  fi

  if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo &>/dev/null; then
      warn "sudo not found and not running as root. Cannot install packages."
      warn "Run as root or install sudo first."
      return 1
    fi
    if [ "$NON_INTERACTIVE" = true ] || [ "$IS_CI" = true ]; then
      if ! sudo -n true 2>/dev/null; then
        warn "Non-interactive mode requires passwordless sudo."
        warn "Add user to sudoers with NOPASSWD or run as root."
        return 1
      fi
    fi
  fi

  info "Updating apt package lists..."
  sudo apt-get update -qq || warn "apt update failed — continuing anyway"

  info "Linux bootstrap ready (apt available)"
}

# ── Core Tools Installation ──
INSTALL_FAILURES=""

install_tool() {
  local tool="$1"
  local brew_pkg="${2:-$tool}"
  local apt_pkg="${3:-$tool}"

  if command -v "$tool" &>/dev/null; then
    return 0
  fi

  info "Installing $tool..."

  if [ "$OS" = "Darwin" ]; then
    if command -v brew &>/dev/null; then
      if ! brew install "$brew_pkg" 2>>/tmp/qa-scan-install.log; then
        warn "Failed to install $tool via brew (see /tmp/qa-scan-install.log)"
        INSTALL_FAILURES="$INSTALL_FAILURES $tool"
        return 1
      fi
    else
      warn "Cannot install $tool — Homebrew not available"
      INSTALL_FAILURES="$INSTALL_FAILURES $tool"
      return 1
    fi
  else
    if [ "$tool" = "gh" ] && ! apt-cache show gh &>/dev/null 2>&1; then
      info "Adding GitHub CLI apt repository..."
      if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
          sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
          sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt-get update -qq 2>/dev/null
      else
        warn "Failed to add GitHub CLI apt repository"
      fi
    fi

    if command -v apt-get &>/dev/null; then
      if ! sudo apt-get install -y "$apt_pkg" 2>>/tmp/qa-scan-install.log; then
        warn "Failed to install $tool via apt (see /tmp/qa-scan-install.log)"
        INSTALL_FAILURES="$INSTALL_FAILURES $tool"
        return 1
      fi
    else
      warn "Cannot install $tool — apt not available"
      INSTALL_FAILURES="$INSTALL_FAILURES $tool"
      return 1
    fi
  fi
}

install_core_tools() {
  install_tool "git" "git" "git"
  if command -v git &>/dev/null; then
    info "Git $(git --version | cut -d' ' -f3)"
  else
    warn "Git is required but could not be installed."
    warn "Install git manually and re-run this script."
    exit 1
  fi

  install_tool "jq" "jq" "jq"
  if command -v jq &>/dev/null; then
    info "jq $(jq --version)"
  else
    warn "jq not found — MCP config may fail"
  fi

  install_tool "gh" "gh" "gh"
  if command -v gh &>/dev/null; then
    info "gh $(gh --version | head -1 | cut -d' ' -f3)"
  else
    warn "gh CLI not found — GitHub issues won't work"
    warn "Install manually: https://cli.github.com/"
  fi

  if [ -n "$INSTALL_FAILURES" ]; then
    warn "Failed to install:$INSTALL_FAILURES"
  fi
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
if [ "$IS_CI" = true ]; then
  info "CI environment detected — running non-interactive"
fi

# Bootstrap based on OS
if [ "$OS" = "Darwin" ]; then
  bootstrap_macos
elif [ "$OS" = "Linux" ]; then
  bootstrap_linux
fi

# Install core tools (git, jq, gh)
install_core_tools

# Check/install bun
if ! command -v bun &>/dev/null; then
  info "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi
info "Bun $(bun --version)"

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

      echo "" > /dev/tty
      echo "  Linear uses OAuth — on first /qa-scan run, your browser will" > /dev/tty
      echo "  open for authorization automatically. No API key needed." > /dev/tty
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

  # Remove broken symlinks
  if [ -L "$config_file" ] && [ ! -e "$config_file" ]; then
    rm -f "$config_file"
  fi

  if [ -f "$config_file" ] && [ -s "$config_file" ]; then
    # Merge into existing config
    jq --arg key "$mcp_key" --argjson val "$mcp_value" \
      'if .mcpServers then .mcpServers[$key] = $val else . + {mcpServers: {($key): $val}} end' \
      "$config_file" > "$tmp_file" 2>/dev/null && cp "$tmp_file" "$config_file" && rm -f "$tmp_file"
  else
    # Create new — write to /tmp first, then copy
    jq -n --arg key "$mcp_key" --argjson val "$mcp_value" \
      '{mcpServers: {($key): $val}}' > "$tmp_file" 2>/dev/null && cp "$tmp_file" "$config_file" && rm -f "$tmp_file"
  fi
}

if [ "$NON_INTERACTIVE" = false ]; then
  header "MCP Configuration"

  # Project-level MCP config: .mcp.json (Claude Code reads this)
  PROJECT_MCP="$WORKSPACE/.mcp.json"

  # Linear MCP (uses mcp-remote with OAuth 2.1)
  if [ "$SOURCE" = "linear" ]; then
    MCP_LINEAR='{"command":"npx","args":["-y","mcp-remote","https://mcp.linear.app/mcp"]}'

    if [ "$HAS_CLAUDE" = true ]; then
      configure_mcp "$PROJECT_MCP" "linear" "$MCP_LINEAR"
      info "Linear MCP → .mcp.json"
    fi
    if [ "$HAS_GEMINI" = true ]; then
      configure_mcp "$WORKSPACE/.gemini/settings.json" "linear" "$MCP_LINEAR"
      info "Linear MCP → .gemini/settings.json"
    fi
  fi

  # GitNexus MCP
  if [[ "${USE_GITNEXUS}" =~ ^[Yy] ]] && command -v gitnexus &>/dev/null; then
    MCP_GITNEXUS='{"type":"stdio","command":"npx","args":["-y","gitnexus","mcp"],"env":{}}'
    if [ "$HAS_CLAUDE" = true ]; then
      configure_mcp "$PROJECT_MCP" "gitnexus" "$MCP_GITNEXUS"
      info "GitNexus MCP → .mcp.json"
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
info "Installing npm dependencies..."
if ! bun install 2>>/tmp/qa-scan-install.log; then
  warn "bun install failed (see /tmp/qa-scan-install.log)"
fi

info "Installing Playwright browser..."
if ! npx playwright install chromium 2>>/tmp/qa-scan-install.log; then
  warn "Playwright browser install failed"
  warn "Run manually: npx playwright install chromium"
fi

# Evidence files
mkdir -p evidence/logs
[ -f evidence/hotspot-memory.json ] || echo "[]" > evidence/hotspot-memory.json
[ -f evidence/qa-tracker.json ] || echo "[]" > evidence/qa-tracker.json
[ -f evidence/flaky-memory.json ] || echo "[]" > evidence/flaky-memory.json

# GitNexus auto-install and initial index
if [[ "${USE_GITNEXUS}" =~ ^[Yy] ]]; then
  if ! command -v gitnexus &>/dev/null; then
    info "Installing GitNexus CLI..."

    install_gitnexus_global() {
      local pkg_mgr="$1"
      local prefix
      if [ "$pkg_mgr" = "bun" ]; then
        prefix="${BUN_INSTALL:-$HOME/.bun}"
      else
        prefix="$(npm config get prefix 2>/dev/null)"
      fi

      if [ -n "$prefix" ] && [ -w "$prefix" ] 2>/dev/null; then
        "$pkg_mgr" install -g gitnexus 2>>/tmp/qa-scan-install.log
      else
        info "Global dir not writable — will use npx gitnexus instead"
        return 1
      fi
    }

    if command -v bun &>/dev/null; then
      install_gitnexus_global "bun" || {
        if command -v npm &>/dev/null; then
          install_gitnexus_global "npm"
        fi
      }
    elif command -v npm &>/dev/null; then
      install_gitnexus_global "npm"
    else
      warn "Cannot install GitNexus — npm/bun not available"
    fi
  fi

  if command -v gitnexus &>/dev/null; then
    info "GitNexus $(gitnexus --version 2>/dev/null || echo 'installed')"
    info "Indexing codebase with GitNexus..."
    gitnexus analyze --incremental "$WORKSPACE" 2>/dev/null || warn "GitNexus indexing skipped"
  else
    warn "GitNexus not available — code analysis disabled"
    warn "Install manually: npm install -g gitnexus"
  fi
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

# Gemini CLI — convert frontmatter to Gemini format
convert_agent_for_gemini() {
  local src="$1" dest="$2"
  # Convert Claude Code agent format → Gemini CLI format:
  # - tools: comma string → YAML array
  # - maxTurns → max_turns
  # - timeout (seconds) → timeout_mins (minutes)
  # - Remove background (not supported)
  # - Remove model (Gemini uses its own)
  awk '
    /^background:/ { next }
    /^model:/ { next }
    /^maxTurns:/ {
      val = $2
      print "max_turns: " val
      next
    }
    /^timeout:/ {
      val = int($2 / 60)
      if (val < 1) val = 1
      print "timeout_mins: " val
      next
    }
    /^tools:/ {
      sub(/^tools: */, "")
      # If Agent tool present → orchestrator, give all tools
      if (index($0, "Agent") > 0) {
        print "tools:\n  - \"*\""
        next
      }
      n = split($0, tools, /, */)
      print "tools:"
      for (i = 1; i <= n; i++) {
        t = tools[i]
        if (t == "Read") t = "read_file"
        else if (t == "Write") t = "write_file"
        else if (t == "Bash") t = "run_shell_command"
        else if (t == "Grep") t = "grep_search"
        else if (t == "Glob") t = "glob"
        else if (t == "WebFetch") t = "web_fetch"
        else if (t == "SendMessage") continue
        print "  - " t
      }
      next
    }
    { print }
  ' "$src" > "$dest"
}

if [ "$HAS_GEMINI" = true ]; then
  mkdir -p "$WORKSPACE/.gemini/agents"
  for f in agents/qa-*.md; do
    [ -f "$f" ] || continue
    convert_agent_for_gemini "$f" "$WORKSPACE/.gemini/agents/$(basename "$f")"
  done
  # Cleanup old command format (TOML → deprecated)
  rm -rf "$WORKSPACE/.gemini/commands/qa" 2>/dev/null || true
  # Gemini prompt template: /scan
  mkdir -p "$WORKSPACE/.gemini/prompts"
  cp adapters/gemini-prompt/scan.md "$WORKSPACE/.gemini/prompts/scan.md" 2>/dev/null || true
  # Gemini skill: auto-activate on QA requests
  mkdir -p "$WORKSPACE/.gemini/skills/qa-scan"
  cp adapters/gemini-skill/SKILL.md "$WORKSPACE/.gemini/skills/qa-scan/SKILL.md" 2>/dev/null || true
  info "Gemini agents + /scan prompt + skill installed"
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
  echo "  Claude Code:  /qa-scan $(echo "$REPO_KEY" | tr '[:lower:]' '[:upper:]')-001"
fi
if [ "$HAS_GEMINI" = true ]; then
  echo "  Gemini CLI:   /scan $(echo "$REPO_KEY" | tr '[:lower:]' '[:upper:]')-001"
fi
echo "  Any agent:    Follow .agents/qa-scan/workflow.md"
echo ""
echo "  Config:       $QA_DIR/config/qa.config.yaml"
echo "  Verify:       bash $QA_DIR/scripts/verify.sh"
echo ""
