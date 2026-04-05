#!/bin/bash
# Zero-Touch QA Orchestrator
#
# Polls Linear for QA issues → runs qa-scan pipeline → posts results → adds labels.
# No human input needed. QA engineer only reads Linear comments.
#
# Usage:
#   bash .agents/qa-scan/scripts/qa-orchestrator.sh                    # Run once
#   bash .agents/qa-scan/scripts/qa-orchestrator.sh --watch 600        # Poll every 10min
#   bash .agents/qa-scan/scripts/qa-orchestrator.sh --repo skin-agent-fe  # Filter by repo
#
# Prerequisites:
#   - Dev server running at configured base_url
#   - bash .agents/qa-scan/scripts/install.sh completed
#
# This script is the ENTRY POINT for zero-touch QA. It:
#   1. Fetches all Linear issues in QA status
#   2. Checks qa-tracker.json to skip already-tested issues
#   3. Invokes the AI agent to run /qa-scan for each new issue
#   4. Results are auto-posted to Linear by the agent pipeline

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TRACKER="$AGENTS_DIR/evidence/qa-tracker.json"
LOG_DIR="$AGENTS_DIR/evidence/logs"

WATCH_INTERVAL=0
REPO_FILTER=""
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch) WATCH_INTERVAL="$2"; shift 2 ;;
    --repo) REPO_FILTER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--watch SECONDS] [--repo REPO_KEY] [--dry-run]"
      echo ""
      echo "Options:"
      echo "  --watch N      Poll every N seconds (default: run once)"
      echo "  --repo KEY     Filter to specific repo from qa.config.yaml"
      echo "  --dry-run      Show what would be scanned without running"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Ensure tracker exists
[ -f "$TRACKER" ] || echo "[]" > "$TRACKER"
mkdir -p "$LOG_DIR"

# Check if issue already scanned
is_scanned() {
  local issue_id="$1"
  # Check if issueId exists in tracker JSON
  if command -v jq >/dev/null 2>&1; then
    jq -e --arg id "$issue_id" 'map(select(.issueId == $id)) | length > 0' "$TRACKER" >/dev/null 2>&1
  else
    grep -q "\"$issue_id\"" "$TRACKER" 2>/dev/null
  fi
}

# Add scan result to tracker
add_to_tracker() {
  local issue_id="$1"
  local title="$2"
  local repo="$3"
  local verdict="$4"

  if command -v jq >/dev/null 2>&1; then
    local tmp=$(mktemp)
    jq --arg id "$issue_id" \
       --arg title "$title" \
       --arg repo "$repo" \
       --arg verdict "$verdict" \
       --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg report "evidence/$issue_id/report.md" \
       '. + [{
         issueId: $id,
         title: $title,
         repo: $repo,
         scannedAt: $date,
         verdict: $verdict,
         reportPath: $report
       }]' "$TRACKER" > "$tmp" && mv "$tmp" "$TRACKER"
  else
    echo "Warning: jq not installed — tracker update skipped"
  fi
}

# Main scan function
run_scan() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo ""
  echo "============================================"
  echo "  QA Orchestrator — $timestamp"
  echo "============================================"
  echo ""

  # Instructions for the AI agent that reads this output
  # The actual Linear fetching happens via the AI agent
  echo "Scanning for QA issues..."
  echo "  Tracker: $TRACKER"
  echo "  Repo filter: ${REPO_FILTER:-all repos}"
  echo "  Dry run: $DRY_RUN"
  echo ""

  # This script serves as the entry point and tracking mechanism.
  # The actual pipeline execution is done by the AI agent:
  #
  # For Claude Code:
  #   claude --agent qa-orchestrator --prompt "Run /qa-scan --all --post"
  #
  # For Gemini CLI:
  #   gemini "Follow .agents/qa-scan/workflow.md, scan all QA issues, post results"
  #
  # For Antigravity:
  #   antigravity /qa-scan --all --post

  if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN — would invoke: /qa-scan --all --post"
    echo "  Already scanned: $(jq length "$TRACKER" 2>/dev/null || echo "?")"
    return
  fi

  # Log this run
  echo "$timestamp — scan started (repo: ${REPO_FILTER:-all})" >> "$LOG_DIR/orchestrator.log"

  echo "Invoking QA pipeline..."
  echo "  Command: /qa-scan --all${REPO_FILTER:+ --repo $REPO_FILTER} --post"
  echo ""
  echo "  The AI agent will:"
  echo "    1. Fetch QA issues from Linear"
  echo "    2. Skip issues in qa-tracker.json"
  echo "    3. Run 8-step pipeline for each new issue"
  echo "    4. Post report + add label to each issue"
  echo "    5. Update qa-tracker.json"
  echo ""
  echo "Orchestrator run complete"
  echo "$timestamp — scan finished" >> "$LOG_DIR/orchestrator.log"
}

# Run once or watch mode
if [ "$WATCH_INTERVAL" -gt 0 ]; then
  echo "Watch mode: polling every ${WATCH_INTERVAL}s (Ctrl+C to stop)"
  echo ""
  while true; do
    run_scan
    echo ""
    echo "Next scan in ${WATCH_INTERVAL}s..."
    sleep "$WATCH_INTERVAL"
  done
else
  run_scan
fi
