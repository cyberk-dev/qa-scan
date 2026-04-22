#!/bin/bash
# QA Scan — Uninstall / Clean
#
# Usage:
#   bash uninstall.sh              # Remove agents + adapters (keep config + evidence)
#   bash uninstall.sh --all        # Remove everything including repo clone
#
# Safe by default: keeps config and evidence (test results, videos, reports)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}→${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }

WORKSPACE="${QA_WORKSPACE:-$(pwd)}"
QA_DIR="$WORKSPACE/.agents/qa-scan"
REMOVE_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) REMOVE_ALL=true; shift ;;
    --project-dir) WORKSPACE="$2"; QA_DIR="$WORKSPACE/.agents/qa-scan"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--all] [--project-dir PATH]"
      echo "  --all          Remove everything (repo, config, evidence)"
      echo "  --project-dir  Workspace root (default: current directory)"
      exit 0 ;;
    *) shift ;;
  esac
done

echo ""
echo -e "${RED}╔══════════════════════════════════╗${NC}"
echo -e "${RED}║     QA Scan — Uninstall         ║${NC}"
echo -e "${RED}╚══════════════════════════════════╝${NC}"
echo ""

# Remove Claude agents
if ls "$WORKSPACE/.claude/agents"/qa-*.md &>/dev/null; then
  rm -f "$WORKSPACE/.claude/agents"/qa-*.md
  info "Removed Claude agents"
fi

# Remove Claude SKILL.md
if [ -d "$WORKSPACE/.claude/skills/qa-scan" ]; then
  rm -rf "$WORKSPACE/.claude/skills/qa-scan"
  info "Removed Claude skill adapter"
fi

# v4: Remove Claude rules
if [ -d "$WORKSPACE/.claude/rules/qa-scan" ]; then
  rm -rf "$WORKSPACE/.claude/rules/qa-scan"
  info "Removed Claude rules"
fi

# Remove Gemini agents
if ls "$WORKSPACE/.gemini/agents"/qa-*.md &>/dev/null; then
  rm -f "$WORKSPACE/.gemini/agents"/qa-*.md
  info "Removed Gemini agents"
fi

# v4: Remove Gemini rules
if [ -d "$WORKSPACE/.gemini/rules/qa-scan" ]; then
  rm -rf "$WORKSPACE/.gemini/rules/qa-scan"
  info "Removed Gemini rules"
fi

# Remove Antigravity adapter
if [ -f "$WORKSPACE/.antigravity/qa-scan.md" ]; then
  rm -f "$WORKSPACE/.antigravity/qa-scan.md"
  info "Removed Antigravity adapter"
fi

# Remove MCP entries (if jq available)
remove_mcp_entries() {
  local config_file="$1"
  if [ -f "$config_file" ] && command -v jq &>/dev/null; then
    local has_linear=$(jq -r '.mcpServers.linear // empty' "$config_file" 2>/dev/null)
    local has_gitnexus=$(jq -r '.mcpServers.gitnexus // empty' "$config_file" 2>/dev/null)
    if [ -n "$has_linear" ] || [ -n "$has_gitnexus" ]; then
      jq 'del(.mcpServers.linear, .mcpServers.gitnexus)' "$config_file" > "${config_file}.tmp" \
        && mv "${config_file}.tmp" "$config_file"
      info "Removed MCP entries from $(basename "$config_file")"
    fi
  fi
}

remove_mcp_entries "$WORKSPACE/.claude/mcp.json"
remove_mcp_entries "$WORKSPACE/.gemini/settings.json"

if [ "$REMOVE_ALL" = true ]; then
  # Remove entire qa-scan repo clone
  if [ -d "$QA_DIR" ]; then
    rm -rf "$QA_DIR"
    info "Removed $QA_DIR"
  fi
  echo ""
  echo "✓ QA Scan fully removed (repo + agents + MCP config)"
else
  echo ""
  echo "✓ QA Scan agents + adapters removed"
  echo ""
  echo "  Kept: $QA_DIR (config, evidence, test results)"
  echo "  To remove everything: bash uninstall.sh --all"
fi
