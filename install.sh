#!/bin/bash
set -euo pipefail
# QA Scan — 1-command installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
#   bash install.sh [--dir PATH] [--project-dir PATH] [--non-interactive]
#
# What it does:
#   1. Auto-installs Bun (if missing)
#   2. Clones/updates qa-scan repo
#   3. Installs Playwright + Chromium
#   4. Interactive config wizard (or template copy)
#   5. Detects AI agents → installs adapters
#   6. Runs verification

INSTALL_DIR="${HOME}/.qa-scan"
PROJECT_DIR="."
INTERACTIVE=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --non-interactive) INTERACTIVE=false; shift ;;
    -h|--help)
      echo "Usage: $0 [--dir PATH] [--project-dir PATH] [--non-interactive]"
      echo ""
      echo "  --dir PATH           Install location (default: ~/.qa-scan)"
      echo "  --project-dir PATH   Project to configure QA for (default: .)"
      echo "  --non-interactive    Skip config wizard, use template"
      exit 0
      ;;
    *) shift ;;
  esac
done

echo ""
echo "╔══════════════════════════════════╗"
echo "║      QA Scan — Installer         ║"
echo "╚══════════════════════════════════╝"
echo ""

# ──────────────────────────────────
# 0. Auto-install Bun (if missing)
# ──────────────────────────────────
if ! command -v bun >/dev/null 2>&1; then
  echo "→ Bun not found. Installing..."
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="${HOME}/.bun"
  export PATH="${BUN_INSTALL}/bin:${PATH}"
  echo "  ✓ Bun installed: $(bun --version)"
  echo ""
fi

# ──────────────────────────────────
# 1. Clone or update repo
# ──────────────────────────────────
if [ -d "${INSTALL_DIR}/.git" ]; then
  echo "→ Updating existing installation..."
  cd "${INSTALL_DIR}" && git pull --quiet
else
  echo "→ Installing qa-scan to ${INSTALL_DIR}..."
  git clone --quiet https://github.com/cyberk-dev/qa-scan.git "${INSTALL_DIR}"
fi
cd "${INSTALL_DIR}"
echo "  ✓ Repo ready"

# ──────────────────────────────────
# 2. Install dependencies
# ──────────────────────────────────
echo "→ Installing dependencies..."
bun install --quiet 2>/dev/null || bun install
echo "→ Installing Chromium for Playwright..."
npx playwright install chromium
mkdir -p evidence
echo "  ✓ Dependencies installed"
echo ""

# ──────────────────────────────────
# 3. Config setup (interactive or template)
# ──────────────────────────────────
if [ ! -f config/qa.config.yaml ]; then
  if [ "${INTERACTIVE}" = true ]; then
    echo "╔══════════════════════════════════╗"
    echo "║    Project Configuration         ║"
    echo "╚══════════════════════════════════╝"
    echo "(Press Enter for defaults)"
    echo ""

    read -p "  Project path [$(cd "${PROJECT_DIR}" && pwd)]: " PROJECT_PATH
    PROJECT_PATH="${PROJECT_PATH:-$(cd "${PROJECT_DIR}" && pwd)}"

    read -p "  Dev server URL [http://localhost:3000]: " BASE_URL
    BASE_URL="${BASE_URL:-http://localhost:3000}"

    read -p "  Issue source — linear or github [linear]: " SOURCE
    SOURCE="${SOURCE:-linear}"

    PROJECT_KEY=""
    GITHUB_REPO=""
    if [ "${SOURCE}" = "linear" ]; then
      read -p "  Linear project key (e.g., SKIN): " PROJECT_KEY
    else
      read -p "  GitHub repo (e.g., org/repo): " GITHUB_REPO
    fi

    read -p "  Git branch to test [dev]: " BRANCH
    BRANCH="${BRANCH:-dev}"

    read -p "  Dev start command [npm run dev]: " DEV_CMD
    DEV_CMD="${DEV_CMD:-npm run dev}"

    cat > config/qa.config.yaml << CONFIGEOF
defaults:
  video: true
  trace: true
  screenshots: true
  evidence_dir: ./evidence
  selectors: accessibility-first
  self_healing_retries: 1

repos:
  my-project:
    path: ${PROJECT_PATH}
    base_url: ${BASE_URL}
    dev_command: ${DEV_CMD}
    source: ${SOURCE}
    ${PROJECT_KEY:+project_key: ${PROJECT_KEY}}
    ${GITHUB_REPO:+repo: ${GITHUB_REPO}}
    branch: ${BRANCH}
    gitnexus: false
    auth:
      strategy: skip

labels:
  pass: "qa-auto-passed"
  fail: "qa-auto-failed"
  partial: "qa-needs-manual"

auto_post:
  enabled: true
  format: summary
CONFIGEOF
    echo ""
    echo "  ✓ Config generated"
  else
    echo "→ Copying config template..."
    cp config/qa.config.example.yaml config/qa.config.yaml
    echo "  ⚠ Edit config/qa.config.yaml with your project settings"
  fi
  echo ""
fi

# ──────────────────────────────────
# 4. Detect AI agents → install adapters
# ──────────────────────────────────
echo "→ Detecting AI agents..."
ABS_PROJECT="$(cd "${PROJECT_DIR}" && pwd)"

AGENTS_INSTALLED=0

# Claude Code
if [ -d "${ABS_PROJECT}/.claude" ]; then
  echo "  ✓ Claude Code detected"
  mkdir -p "${ABS_PROJECT}/.claude/agents" "${ABS_PROJECT}/.claude/skills/qa-scan"
  for f in agents/qa-*.md; do
    [ -f "$f" ] && cp "$f" "${ABS_PROJECT}/.claude/agents/"
  done
  cp adapters/claude-skill.md "${ABS_PROJECT}/.claude/skills/qa-scan/SKILL.md"
  AGENTS_INSTALLED=$((AGENTS_INSTALLED + 1))
  echo "    → 7 agents + skill installed"
fi

# Gemini CLI
if [ -d "${ABS_PROJECT}/.gemini" ]; then
  echo "  ✓ Gemini CLI detected"
  cp adapters/gemini-adapter.md "${ABS_PROJECT}/.gemini/qa-scan.md"
  AGENTS_INSTALLED=$((AGENTS_INSTALLED + 1))
fi

# Antigravity
if [ -d "${ABS_PROJECT}/.antigravity" ]; then
  echo "  ✓ Antigravity detected"
  cp adapters/antigravity-adapter.md "${ABS_PROJECT}/.antigravity/qa-scan.md"
  AGENTS_INSTALLED=$((AGENTS_INSTALLED + 1))
fi

if [ $AGENTS_INSTALLED -eq 0 ]; then
  echo "  ⚠ No AI agent config found in ${ABS_PROJECT}"
  echo "    Create .claude/ or .gemini/ dir, then re-run install.sh"
fi
echo ""

# ──────────────────────────────────
# 5. Verify
# ──────────────────────────────────
bash scripts/verify.sh

echo ""
echo "╔══════════════════════════════════╗"
echo "║    ✓ QA Scan Ready!              ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "  Installed at: ${INSTALL_DIR}"
echo ""
echo "  Usage:"
echo "    /qa-scan SKIN-101              # Test single issue"
echo "    /qa-scan --all                 # Test all QA issues"
echo "    bash ${INSTALL_DIR}/scripts/qa-orchestrator.sh --watch 600"
echo ""
