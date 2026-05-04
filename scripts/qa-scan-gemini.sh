#!/usr/bin/env bash
# qa-scan-gemini.sh — Bash orchestrator for the Gemini CLI runtime.
#
# Why this script exists:
#   Gemini CLI does not have a Task() tool to spawn isolated sub-agent contexts.
#   The .gemini/commands/qa-scan.toml file inlines the orchestrator prompt into
#   ONE session, which causes context bloat past the 1M-token mark when 8
#   sub-agent prompts + their outputs share a single conversation. Result:
#   timeout / cancel near step 5-6.
#
#   This script ports the proven research-pipeline pattern (`run-cell-v3.sh`)
#   to qa-scan: each step is a fresh `gemini -p "<prompt>"` subprocess, getting
#   a clean context window. State passes between steps via JSON files on disk
#   under {results_dir}/{repo_key}/{issue_id}/state/. Orchestrator state stays
#   in this script's bash variables, not in any LLM context.
#
# Usage:
#   bash scripts/qa-scan-gemini.sh <issue-id> [--repo <repo-key>] [--no-post]
#   bash scripts/qa-scan-gemini.sh SKI-101 --repo test-app
#
# Requires:
#   - gemini CLI (>= 0.40)
#   - yq or python3 to read qa.config.yaml
#   - jq to parse status block JSON in agent outputs
#
# Output markers (stdout, parseable):
#   STEP_BEGIN    step=<n> name=<name>
#   STEP_COMPLETE step=<n> name=<name> status=<DONE|...> output=<path>
#   STEP_FAILED   step=<n> name=<name> reason=<text>
#   PIPELINE_DONE verdict=<PASS|FAIL|PARTIAL|ABORTED> report=<path>

set -euo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────

ISSUE_ID=""
REPO_KEY=""
POST_RESULTS="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO_KEY="$2"; shift 2 ;;
    --no-post)     POST_RESULTS="false"; shift ;;
    --post)        POST_RESULTS="true"; shift ;;
    --help|-h)     sed -n '1,30p' "$0"; exit 0 ;;
    -*)            echo "Unknown flag: $1" >&2; exit 1 ;;
    *)             ISSUE_ID="$1"; shift ;;
  esac
done

if [[ -z "$ISSUE_ID" ]]; then
  echo "Usage: bash scripts/qa-scan-gemini.sh <issue-id> [--repo <repo-key>]" >&2
  exit 1
fi

# ── config loading ────────────────────────────────────────────────────────────

CONFIG_FILE=".agents/qa-scan/config/qa.config.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found. Run from a workspace where qa-scan is installed." >&2
  exit 1
fi

# Resolve repo_key from issue prefix if --repo not given
if [[ -z "$REPO_KEY" ]]; then
  ISSUE_PREFIX="${ISSUE_ID%%-*}"
  REPO_KEY="$(python3 -c "
import sys, yaml
cfg = yaml.safe_load(open('$CONFIG_FILE'))
for k, v in cfg.get('repos', {}).items():
    if v.get('project_key') == '$ISSUE_PREFIX':
        print(k); break
" 2>/dev/null)"
  if [[ -z "$REPO_KEY" ]]; then
    echo "ERROR: cannot resolve repo for issue prefix '$ISSUE_PREFIX'. Pass --repo <key> explicitly." >&2
    exit 1
  fi
fi

# Read repo config fields
read_cfg() {
  python3 -c "
import yaml
cfg = yaml.safe_load(open('$CONFIG_FILE'))
v = cfg['repos']['$REPO_KEY'].get('$1', '')
print(v)" 2>/dev/null
}

REPO_PATH="$(read_cfg path)"
RESULTS_DIR_BASE="$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['defaults']['results_dir'])")"
RESULTS_DIR="$RESULTS_DIR_BASE/$REPO_KEY/$ISSUE_ID"
STATE_DIR="$RESULTS_DIR/state"
EVIDENCE_DIR="$RESULTS_DIR/evidence"

mkdir -p "$STATE_DIR" "$EVIDENCE_DIR"

# ── helpers ───────────────────────────────────────────────────────────────────

GEMINI_AGENT_DIR=".gemini/agents"

log()   { printf '%s\n' "$*" >&2; }
mark()  { printf '%s\n' "$*"; }

# Run one sub-agent in an isolated gemini subprocess.
# Args: $1=agent_name (e.g. qa-context-extractor), $2=output_state_file, $3=extra_input_block
run_step() {
  local AGENT="$1"
  local OUTFILE="$2"
  local INPUT_BLOCK="$3"
  local AGENT_FILE="$GEMINI_AGENT_DIR/$AGENT.md"

  if [[ ! -f "$AGENT_FILE" ]]; then
    mark "STEP_FAILED step=? name=$AGENT reason=agent_file_missing path=$AGENT_FILE"
    return 1
  fi

  local PROMPT
  PROMPT="$(cat <<EOF
You are the **$AGENT** sub-agent. Execute per the spec below in a single, focused pass.

# Inputs
$INPUT_BLOCK

# Output
Write your structured JSON output to: $OUTFILE
Return ONLY the status block per references/status-protocol.md AFTER writing the file.

# Agent Specification (read carefully and follow exactly)
$(cat "$AGENT_FILE")
EOF
)"

  # Run gemini in non-interactive mode with yolo (auto-approve tool calls).
  # Capture both stdout (status block + agent narration) and exit code.
  local LOGFILE="$STATE_DIR/.$AGENT.log"
  if ! gemini -y -p "$PROMPT" > "$LOGFILE" 2>&1; then
    mark "STEP_FAILED step=? name=$AGENT reason=gemini_nonzero_exit log=$LOGFILE"
    return 1
  fi

  # Verify the output file was written.
  if [[ ! -f "$OUTFILE" ]]; then
    mark "STEP_FAILED step=? name=$AGENT reason=output_file_not_written expected=$OUTFILE"
    return 1
  fi

  # Best-effort parse status block (look for **Status:** line)
  local STATUS
  STATUS="$(grep -E '^\*\*Status:\*\*' "$LOGFILE" | head -1 | sed -E 's/.*Status:\*\* *//; s/ .*//' || echo UNKNOWN)"
  mark "STEP_COMPLETE step=? name=$AGENT status=$STATUS output=$OUTFILE"
  return 0
}

# ── pipeline ──────────────────────────────────────────────────────────────────

mark "PIPELINE_BEGIN issue=$ISSUE_ID repo=$REPO_KEY results_dir=$RESULTS_DIR"

# Step 0: Project Context Extraction
mark "STEP_BEGIN step=0 name=qa-context-extractor"
run_step "qa-context-extractor" "$STATE_DIR/step-0-context.json" "$(cat <<EOF
- repo_path: $REPO_PATH
- repo_key: $REPO_KEY
- results_dir: $RESULTS_DIR
- output_file: $STATE_DIR/step-0-context.json
EOF
)" || { mark "PIPELINE_DONE verdict=ABORTED reason=step-0_failed"; exit 1; }

# Step 0a: Env Bootstrap
mark "STEP_BEGIN step=0a name=qa-env-bootstrap"
run_step "qa-env-bootstrap" "$STATE_DIR/step-0a-env.json" "$(cat <<EOF
- repo_path: $REPO_PATH
- repo_key: $REPO_KEY
- results_dir: $RESULTS_DIR
- project_context: $STATE_DIR/step-0-context.json
- output_file: $STATE_DIR/step-0a-env.json
- manifest_path: $REPO_PATH/.qa-scan.yaml (if exists)
EOF
)" || { mark "PIPELINE_DONE verdict=ABORTED reason=step-0a_failed"; exit 1; }

# Step 1: Issue Analyzer
mark "STEP_BEGIN step=1 name=qa-issue-analyzer"
run_step "qa-issue-analyzer" "$STATE_DIR/step-1-issue.json" "$(cat <<EOF
- issue_id: $ISSUE_ID
- repo_key: $REPO_KEY
- results_dir: $RESULTS_DIR
- project_context: $STATE_DIR/step-0-context.json
- output_file: $STATE_DIR/step-1-issue.json
EOF
)" || { mark "PIPELINE_DONE verdict=ABORTED reason=step-1_failed"; exit 1; }

# Step 2: Code Scout
mark "STEP_BEGIN step=2 name=qa-code-scout"
run_step "qa-code-scout" "$STATE_DIR/step-2-scout.json" "$(cat <<EOF
- repo_path: $REPO_PATH
- results_dir: $RESULTS_DIR
- issue_state: $STATE_DIR/step-1-issue.json
- project_context: $STATE_DIR/step-0-context.json
- output_file: $STATE_DIR/step-2-scout.json
EOF
)" || { mark "PIPELINE_DONE verdict=ABORTED reason=step-2_failed"; exit 1; }

# Step 3: Test Generator
mark "STEP_BEGIN step=3 name=qa-test-generator"
run_step "qa-test-generator" "$STATE_DIR/step-3-test.json" "$(cat <<EOF
- issue_id: $ISSUE_ID
- results_dir: $RESULTS_DIR
- issue_state: $STATE_DIR/step-1-issue.json
- scout_state: $STATE_DIR/step-2-scout.json
- env_state: $STATE_DIR/step-0a-env.json
- project_context: $STATE_DIR/step-0-context.json
- test_file_target: $EVIDENCE_DIR/test.spec.ts
- output_file: $STATE_DIR/step-3-test.json
EOF
)" || { mark "PIPELINE_DONE verdict=ABORTED reason=step-3_failed"; exit 1; }

# Step 4: Test Runner
mark "STEP_BEGIN step=4 name=qa-test-runner"
run_step "qa-test-runner" "$STATE_DIR/step-4-run.json" "$(cat <<EOF
- results_dir: $RESULTS_DIR
- test_file: $EVIDENCE_DIR/test.spec.ts
- env_state: $STATE_DIR/step-0a-env.json
- playwright_config: scripts/playwright.config.ts
- output_file: $STATE_DIR/step-4-run.json
EOF
)" || { mark "PIPELINE_DONE verdict=ABORTED reason=step-4_failed"; exit 1; }

# Step 5: Coverage Verifier
mark "STEP_BEGIN step=5 name=qa-coverage-verifier"
run_step "qa-coverage-verifier" "$STATE_DIR/step-5-coverage.json" "$(cat <<EOF
- results_dir: $RESULTS_DIR
- scout_state: $STATE_DIR/step-2-scout.json
- run_state: $STATE_DIR/step-4-run.json
- test_file: $EVIDENCE_DIR/test.spec.ts
- output_file: $STATE_DIR/step-5-coverage.json
EOF
)" || { mark "PIPELINE_DONE verdict=PARTIAL reason=step-5_failed"; exit 0; }

# Step 6: Report Synthesizer
mark "STEP_BEGIN step=6 name=qa-report-synthesizer"
run_step "qa-report-synthesizer" "$RESULTS_DIR/report.md" "$(cat <<EOF
- results_dir: $RESULTS_DIR
- issue_state: $STATE_DIR/step-1-issue.json
- scout_state: $STATE_DIR/step-2-scout.json
- run_state: $STATE_DIR/step-4-run.json
- coverage_state: $STATE_DIR/step-5-coverage.json
- output_file: $RESULTS_DIR/report.md
EOF
)" || { mark "PIPELINE_DONE verdict=PARTIAL reason=step-6_failed"; exit 0; }

# Extract verdict from report (best-effort)
VERDICT="$(grep -E '^\*\*VERDICT:\*\*|^VERDICT:' "$RESULTS_DIR/report.md" | head -1 | sed -E 's/.*VERDICT:\*?\*? *//' || echo UNKNOWN)"

mark "PIPELINE_DONE verdict=$VERDICT report=$RESULTS_DIR/report.md"
exit 0
