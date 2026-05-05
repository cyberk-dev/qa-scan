#!/usr/bin/env bash
# qa-scan-gemini.sh — Bash orchestrator for the Gemini CLI runtime (v4.4+).
#
# Architecture:
#   - Manifest-driven: pipeline steps defined in references/qa-pipeline.yaml
#   - Disk-based state: each step writes JSON under
#     {results_dir}/{repo_key}/{issue_id}/state/
#   - Each `gemini -p` is a fresh subprocess (clean context window)
#   - NEEDS_CONTEXT escalation: sub-agent emits question payload + exits;
#     orchestrator surfaces options to user, gets answer, re-spawns step
#     with answer in input block (max 3 retries per step)
#
# Usage:
#   bash scripts/qa-scan-gemini.sh <issue-id> [--repo <repo-key>] [--no-post]
#   bash scripts/qa-scan-gemini.sh SKI-101 --repo test-app
#
# Env:
#   QA_SCAN_NONINTERACTIVE=1   Auto-abort on BLOCKED/NEEDS_CONTEXT (CI mode)
#   QA_SCAN_MAX_RETRIES=3      Per-step NEEDS_CONTEXT retry limit
#
# Requires:
#   - gemini CLI (>= 0.40)
#   - python3 (yaml parsing)
#   - jq    (status payload extraction)
#
# Stdout markers (parseable by callers):
#   PIPELINE_BEGIN      issue=<id> repo=<key> results_dir=<path>
#   STEP_BEGIN          step=<n> name=<agent>
#   STEP_COMPLETE       step=<n> name=<agent> status=<DONE|DONE_WITH_CONCERNS> output=<path>
#   STEP_RETRY          step=<n> name=<agent> attempt=<i> reason=<text>
#   NEEDS_USER_INPUT    step=<n> name=<agent> template=<T1..T7|none> question_file=<path>
#   STEP_FAILED         step=<n> name=<agent> reason=<text>
#   PIPELINE_DONE       verdict=<PASS|FAIL|PARTIAL|ABORTED> report=<path>

set -euo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────

ISSUE_ID=""
REPO_KEY=""
POST_RESULTS="true"
ALL_MODE="false"
ALL_STATUS_FILTER="QA Ready"
ALL_LABEL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)        REPO_KEY="$2"; shift 2 ;;
    --no-post)     POST_RESULTS="false"; shift ;;
    --post)        POST_RESULTS="true"; shift ;;
    --all)         ALL_MODE="true"; shift ;;
    --status)      ALL_STATUS_FILTER="$2"; shift 2 ;;
    --label)       ALL_LABEL_FILTER="$2"; shift 2 ;;
    --help|-h)     sed -n '1,30p' "$0"; exit 0 ;;
    -*)            echo "Unknown flag: $1" >&2; exit 1 ;;
    *)             ISSUE_ID="$1"; shift ;;
  esac
done

if [[ "$ALL_MODE" == "false" && -z "$ISSUE_ID" ]]; then
  echo "Usage: bash scripts/qa-scan-gemini.sh <issue-id-or-url> [--repo <repo-key>]" >&2
  echo "       bash scripts/qa-scan-gemini.sh --all [--repo <repo-key>] [--status \"QA Ready\"] [--label qa-ready]" >&2
  exit 1
fi

# ── --all mode: fetch issue list from Linear, loop pipeline ──────────────────
if [[ "$ALL_MODE" == "true" ]]; then
  SCRIPT_DIR_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LIST_SCRIPT="$SCRIPT_DIR_SELF/qa-scan-list-issues.sh"
  if [[ ! -x "$LIST_SCRIPT" ]]; then
    echo "ERROR: $LIST_SCRIPT not found or not executable" >&2
    exit 1
  fi

  LIST_ARGS=()
  [[ -n "$REPO_KEY" ]] && LIST_ARGS+=("--repo" "$REPO_KEY")
  [[ -n "$ALL_STATUS_FILTER" ]] && LIST_ARGS+=("--status" "$ALL_STATUS_FILTER")
  [[ -n "$ALL_LABEL_FILTER" ]] && LIST_ARGS+=("--label" "$ALL_LABEL_FILTER")

  echo "[batch] fetching issue list from Linear..." >&2
  ISSUES_JSON=$(bash "$LIST_SCRIPT" "${LIST_ARGS[@]}" 2>&1 1>/tmp/qa-scan-issues.json && cat /tmp/qa-scan-issues.json)
  if [[ -z "$ISSUES_JSON" ]] || [[ "$ISSUES_JSON" == "[]" ]]; then
    echo "[batch] no issues found matching filter status='$ALL_STATUS_FILTER' label='$ALL_LABEL_FILTER'" >&2
    echo "PIPELINE_DONE verdict=ABORTED reason=no_issues_in_filter"
    exit 0
  fi

  COUNT=$(echo "$ISSUES_JSON" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")
  echo "[batch] $COUNT issue(s) to scan" >&2

  TIMESTAMP=$(date +%y%m%d-%H%M%S)
  RESULTS_DIR_BASE=$(python3 -c "
import yaml
cfg = yaml.safe_load(open('$CONFIG_FILE' if '$CONFIG_FILE' else '.agents/qa-scan/config/qa.config.yaml'))
print(cfg.get('defaults', {}).get('results_dir', './evidence'))
" 2>/dev/null || echo "./evidence")
  BATCH_DIR="${RESULTS_DIR_BASE}/_batch-${TIMESTAMP}"
  mkdir -p "$BATCH_DIR"
  BATCH_SUMMARY="$BATCH_DIR/summary.json"
  echo "[]" > "$BATCH_SUMMARY"

  echo "BATCH_BEGIN total=$COUNT batch_dir=$BATCH_DIR"

  IDX=0
  PASS=0; FAIL=0; PARTIAL=0; ABORTED=0
  echo "$ISSUES_JSON" | python3 -c "
import sys, json
for issue in json.loads(sys.stdin.read()):
    print(f\"{issue.get('id','')}\t{issue.get('title','')}\t{issue.get('url','')}\")
" | while IFS=$'\t' read -r ISS_ID ISS_TITLE ISS_URL; do
    IDX=$((IDX + 1))
    [[ -z "$ISS_ID" ]] && continue
    echo "" >&2
    echo "[batch] ─── ($IDX/$COUNT) $ISS_ID — $ISS_TITLE ───" >&2
    SUB_ARGS=("$ISS_ID")
    [[ -n "$REPO_KEY" ]] && SUB_ARGS+=("--repo" "$REPO_KEY")
    [[ "$POST_RESULTS" == "false" ]] && SUB_ARGS+=("--no-post")

    SUB_LOG="$BATCH_DIR/${ISS_ID}.log"
    if bash "${BASH_SOURCE[0]:-$0}" "${SUB_ARGS[@]}" > "$SUB_LOG" 2>&1; then
      VERDICT=$(grep -oE 'PIPELINE_DONE verdict=[A-Z]+' "$SUB_LOG" | tail -1 | sed 's/PIPELINE_DONE verdict=//')
      [[ -z "$VERDICT" ]] && VERDICT="UNKNOWN"
    else
      VERDICT="FAIL"
    fi
    echo "[batch] $ISS_ID → $VERDICT" >&2

    # Append to summary
    python3 -c "
import json, sys
data = json.load(open('$BATCH_SUMMARY'))
data.append({'id': '$ISS_ID', 'title': '''$ISS_TITLE''', 'url': '$ISS_URL', 'verdict': '$VERDICT', 'log': '$SUB_LOG'})
json.dump(data, open('$BATCH_SUMMARY', 'w'), indent=2)
"
  done

  # Final aggregate
  echo "" >&2
  echo "[batch] ═══ BATCH SUMMARY ═══" >&2
  python3 - "$BATCH_SUMMARY" "$BATCH_DIR/REPORT.md" <<'PYEOF'
import json, sys
from collections import Counter
data = json.load(open(sys.argv[1]))
counts = Counter(item['verdict'] for item in data)
report_path = sys.argv[2]
with open(report_path, 'w') as f:
    f.write(f"# QA Scan Batch Report\n\n")
    f.write(f"Total: {len(data)} issue(s)\n\n")
    f.write("## Verdict breakdown\n\n")
    f.write("| Verdict | Count |\n|---------|-------|\n")
    for v in ['PASS', 'PARTIAL', 'FAIL', 'ABORTED', 'UNKNOWN']:
        if counts.get(v, 0):
            f.write(f"| {v} | {counts[v]} |\n")
    f.write("\n## Per-issue\n\n")
    f.write("| Issue | Title | Verdict | Log |\n|-------|-------|---------|-----|\n")
    for item in data:
        f.write(f"| {item['id']} | {item.get('title','')} | {item['verdict']} | `{item['log']}` |\n")
print(f"PASS={counts.get('PASS',0)} PARTIAL={counts.get('PARTIAL',0)} FAIL={counts.get('FAIL',0)} ABORTED={counts.get('ABORTED',0)}")
PYEOF
  echo "BATCH_DONE summary=$BATCH_SUMMARY report=$BATCH_DIR/REPORT.md"
  exit 0
fi

# ── URL → issue-key extraction (Linear / GitHub paste-friendly) ──────────────
# Accepts:
#   - Plain key:   MEK-123
#   - Linear URL:  https://linear.app/{workspace}/issue/MEK-123/some-slug
#   - GitHub URL:  https://github.com/{org}/{repo}/issues/123  (repo is converted to KEY-NUM by analyzer)
if [[ "$ISSUE_ID" == *"linear.app"* ]] || [[ "$ISSUE_ID" == *"github.com"* ]]; then
  EXTRACTED=$(echo "$ISSUE_ID" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  if [[ -n "$EXTRACTED" ]]; then
    echo "[info] extracted issue id from URL: $EXTRACTED" >&2
    ISSUE_ID="$EXTRACTED"
  else
    echo "ERROR: cannot extract issue key (e.g. MEK-123) from URL: $ISSUE_ID" >&2
    exit 1
  fi
fi

# ── dependency checks ────────────────────────────────────────────────────────

for bin in gemini python3 jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: '$bin' not in PATH" >&2; exit 1; }
done

# ── path resolution ──────────────────────────────────────────────────────────

CONFIG_FILE=".agents/qa-scan/config/qa.config.yaml"
MANIFEST_FILE=".agents/qa-scan/references/qa-pipeline.yaml"
TEMPLATES_DIR=".agents/qa-scan/references/templates"
GEMINI_AGENT_DIR=".gemini/agents"

# Fallback: when running directly inside qa-scan-repo (not workspace install),
# references live at top level instead of .agents/qa-scan/.
if [[ ! -f "$MANIFEST_FILE" && -f "references/qa-pipeline.yaml" ]]; then
  MANIFEST_FILE="references/qa-pipeline.yaml"
  TEMPLATES_DIR="references/templates"
fi
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found. Run from a workspace with qa-scan installed." >&2
  exit 1
fi
if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "ERROR: $MANIFEST_FILE not found." >&2
  exit 1
fi

# ── config / repo resolution ─────────────────────────────────────────────────

if [[ -z "$REPO_KEY" ]]; then
  ISSUE_PREFIX="${ISSUE_ID%%-*}"
  REPO_KEY="$(python3 -c "
import yaml
cfg = yaml.safe_load(open('$CONFIG_FILE'))
for k, v in cfg.get('repos', {}).items():
    if v.get('project_key') == '$ISSUE_PREFIX':
        print(k); break
" 2>/dev/null)"
  [[ -z "$REPO_KEY" ]] && {
    echo "ERROR: cannot resolve repo for issue prefix '$ISSUE_PREFIX'. Pass --repo." >&2
    exit 1
  }
fi

REPO_PATH="$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['repos']['$REPO_KEY']['path'])")"
RESULTS_DIR_BASE="$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['defaults']['results_dir'])")"
RESULTS_DIR="$RESULTS_DIR_BASE/$REPO_KEY/$ISSUE_ID"
STATE_DIR="$RESULTS_DIR/state"
EVIDENCE_DIR="$RESULTS_DIR/evidence"
mkdir -p "$STATE_DIR" "$EVIDENCE_DIR"

NONINTERACTIVE="${QA_SCAN_NONINTERACTIVE:-0}"
MAX_RETRIES="${QA_SCAN_MAX_RETRIES:-3}"

# ── helpers ──────────────────────────────────────────────────────────────────

mark()  { printf '%s\n' "$*"; }
log()   { printf '[qa-scan] %s\n' "$*" >&2; }

# Parse status from the agent's stdout log (returns "DONE" / "BLOCKED" / etc.)
parse_status() {
  grep -E '^\*\*Status:\*\*' "$1" 2>/dev/null | head -1 \
    | sed -E 's/.*Status:\*\* *//; s/[[:space:]].*//' \
    | tr -d '[:space:]' \
    || echo UNKNOWN
}

# Parse `escalation` JSON object from the output JSON file (NEEDS_CONTEXT / BLOCKED).
# Returns empty string if no escalation block.
extract_escalation() {
  local OUT="$1"
  [[ -f "$OUT" ]] || { echo ""; return; }
  jq -c '.escalation // empty' "$OUT" 2>/dev/null || echo ""
}

# Render a numbered options list to stderr, then read user choice.
# Args: $1 = JSON escalation object
# Outputs: chosen option `id` on stdout
prompt_user() {
  local ESC="$1"
  local TPL Q OPTS_JSON COUNT i
  TPL="$(echo "$ESC" | jq -r '.template // "none"')"
  Q="$(echo "$ESC" | jq -r '.question // "(no question)"')"
  OPTS_JSON="$(echo "$ESC" | jq -c '.options // []')"
  COUNT="$(echo "$OPTS_JSON" | jq 'length')"

  {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "## Sub-agent cần thông tin (template: $TPL)"
    echo ""
    echo "$Q"
    echo ""
    if [[ -f "$TEMPLATES_DIR/$TPL.md" ]]; then
      echo "Tham khảo: $TEMPLATES_DIR/$TPL.md"
      echo ""
    fi
    echo "Lựa chọn:"
    for ((i=0; i<COUNT; i++)); do
      local LABEL DESC
      LABEL="$(echo "$OPTS_JSON" | jq -r ".[$i].label")"
      DESC="$(echo "$OPTS_JSON" | jq -r ".[$i].description // empty")"
      printf '  %d) %s' "$((i+1))" "$LABEL"
      [[ -n "$DESC" && "$DESC" != "null" ]] && printf ' — %s' "$DESC"
      printf '\n'
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -n "Trả lời bằng số [1-$COUNT] hoặc gõ 'abort': "
  } >&2

  local REPLY
  read -r REPLY < /dev/tty || { echo "abort"; return; }

  if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= COUNT )); then
    echo "$OPTS_JSON" | jq -r ".[$((REPLY-1))].id"
  else
    echo "abort"
  fi
}

# Render a single sub-agent prompt. Reads agent file from .gemini/agents/.
build_prompt() {
  local AGENT="$1" OUTFILE="$2" INPUTS="$3" ANSWER="${4:-}"
  local AGENT_FILE="$GEMINI_AGENT_DIR/$AGENT.md"
  [[ -f "$AGENT_FILE" ]] || { echo "ERROR: $AGENT_FILE missing" >&2; return 1; }

  cat <<EOF
You are the **$AGENT** sub-agent. Execute per the spec below in a single, focused pass.

# Inputs
$INPUTS
EOF

  if [[ -n "$ANSWER" ]]; then
    cat <<EOF

# User Answer (from previous escalation)
$ANSWER
EOF
  fi

  cat <<EOF

# Output
Write your structured JSON output to: $OUTFILE
After writing, return ONLY the status block per references/status-protocol.md.
If you need user input, populate \`escalation\` in the JSON and return status NEEDS_CONTEXT
(see references/non-interactive-rule.md). NEVER call AskUserQuestion or wait for stdin.

# Agent Specification
$(cat "$AGENT_FILE")
EOF
}

# Run one step (with retry on NEEDS_CONTEXT). Returns 0 on DONE/PARTIAL accept, 1 on hard failure.
# Args: $1=step_id, $2=agent_name, $3=outfile_path, $4=inputs_block, $5=on_failure (abort|partial)
run_step() {
  local STEP="$1" AGENT="$2" OUTFILE="$3" INPUTS="$4" ON_FAIL="${5:-abort}"
  local LOGFILE="$STATE_DIR/.$AGENT.log"
  local ATTEMPT=0
  local USER_ANSWER=""

  mark "STEP_BEGIN step=$STEP name=$AGENT"

  while (( ATTEMPT < MAX_RETRIES )); do
    ATTEMPT=$((ATTEMPT+1))
    local PROMPT
    PROMPT="$(build_prompt "$AGENT" "$OUTFILE" "$INPUTS" "$USER_ANSWER")"

    if ! gemini -y -p "$PROMPT" > "$LOGFILE" 2>&1; then
      mark "STEP_FAILED step=$STEP name=$AGENT reason=gemini_nonzero_exit log=$LOGFILE attempt=$ATTEMPT"
      [[ "$ON_FAIL" == "partial" ]] && return 0 || return 1
    fi

    if [[ ! -f "$OUTFILE" ]]; then
      mark "STEP_FAILED step=$STEP name=$AGENT reason=output_file_not_written expected=$OUTFILE attempt=$ATTEMPT"
      [[ "$ON_FAIL" == "partial" ]] && return 0 || return 1
    fi

    local STATUS
    STATUS="$(parse_status "$LOGFILE")"

    case "$STATUS" in
      DONE|DONE_WITH_CONCERNS)
        mark "STEP_COMPLETE step=$STEP name=$AGENT status=$STATUS output=$OUTFILE"
        return 0
        ;;
      NEEDS_CONTEXT)
        local ESC
        ESC="$(extract_escalation "$OUTFILE")"
        if [[ -z "$ESC" ]]; then
          mark "STEP_FAILED step=$STEP name=$AGENT reason=needs_context_no_escalation_block attempt=$ATTEMPT"
          [[ "$ON_FAIL" == "partial" ]] && return 0 || return 1
        fi

        local TPL
        TPL="$(echo "$ESC" | jq -r '.template // "none"')"
        mark "NEEDS_USER_INPUT step=$STEP name=$AGENT template=$TPL question_file=$OUTFILE"

        if [[ "$NONINTERACTIVE" == "1" ]]; then
          mark "STEP_FAILED step=$STEP name=$AGENT reason=needs_context_in_noninteractive_mode"
          return 1
        fi

        local CHOICE
        CHOICE="$(prompt_user "$ESC")"
        if [[ "$CHOICE" == "abort" ]]; then
          mark "STEP_FAILED step=$STEP name=$AGENT reason=user_aborted"
          return 1
        fi

        mark "STEP_RETRY step=$STEP name=$AGENT attempt=$ATTEMPT chosen=$CHOICE"
        USER_ANSWER="user_choice: $CHOICE"
        # If user wants free-form input, prompt again
        if [[ "$CHOICE" == "rewrite" || "$CHOICE" == "input_manual" || "$CHOICE" == "paste_paths" || "$CHOICE" == "manual_test" ]]; then
          {
            echo ""
            echo "Nhập nội dung (kết thúc bằng dòng EOF):"
          } >&2
          local LINE BUF=""
          while IFS= read -r LINE < /dev/tty; do
            [[ "$LINE" == "EOF" ]] && break
            BUF+="$LINE"$'\n'
          done
          USER_ANSWER+=$'\n'"user_input:"$'\n'"$BUF"
        fi
        # Loop continues — re-spawn agent with USER_ANSWER appended to inputs
        ;;
      BLOCKED)
        mark "STEP_FAILED step=$STEP name=$AGENT reason=blocked attempt=$ATTEMPT"
        # Surface escalation if present
        local ESC
        ESC="$(extract_escalation "$OUTFILE")"
        if [[ -n "$ESC" && "$NONINTERACTIVE" != "1" ]]; then
          local TPL
          TPL="$(echo "$ESC" | jq -r '.template // "none"')"
          mark "NEEDS_USER_INPUT step=$STEP name=$AGENT template=$TPL question_file=$OUTFILE"
          local CHOICE
          CHOICE="$(prompt_user "$ESC")"
          [[ "$CHOICE" == "abort" ]] && return 1
          USER_ANSWER="user_choice: $CHOICE"
          continue   # retry
        fi
        [[ "$ON_FAIL" == "partial" ]] && return 0 || return 1
        ;;
      *)
        mark "STEP_FAILED step=$STEP name=$AGENT reason=unknown_status:$STATUS attempt=$ATTEMPT"
        [[ "$ON_FAIL" == "partial" ]] && return 0 || return 1
        ;;
    esac
  done

  mark "STEP_FAILED step=$STEP name=$AGENT reason=max_retries_exhausted attempts=$MAX_RETRIES"
  [[ "$ON_FAIL" == "partial" ]] && return 0 || return 1
}

# Render the inputs block for a step using the manifest definition.
# Args: $1=step_id
render_inputs() {
  local STEP="$1"
  python3 - <<EOF
import yaml
m = yaml.safe_load(open('$MANIFEST_FILE'))
step = next(s for s in m['steps'] if s['step'] == '$STEP')
results_dir = '$RESULTS_DIR'
issue_id = '$ISSUE_ID'
repo_path = '$REPO_PATH'
repo_key = '$REPO_KEY'
state_dir = f'{results_dir}/state'
evidence_dir = f'{results_dir}/evidence'

scope = {
    'repo_path': repo_path,
    'repo_key': repo_key,
    'issue_id': issue_id,
    'results_dir': results_dir,
}

for inp in step.get('inputs', []):
    if isinstance(inp, str):
        key = inp
        val = scope.get(key, '')
    elif isinstance(inp, dict):
        key, raw = next(iter(inp.items()))
        if raw == 'optional':
            val = f'{repo_path}/.qa-scan.yaml (if exists)'
        elif raw.startswith('state/'):
            val = f'{state_dir}/{raw[6:]}'
        elif raw.startswith('evidence/'):
            val = f'{evidence_dir}/{raw[9:]}'
        else:
            val = raw
    else:
        continue
    print(f'- {key}: {val}')
EOF
}

# ── pipeline driver ──────────────────────────────────────────────────────────

mark "PIPELINE_BEGIN issue=$ISSUE_ID repo=$REPO_KEY results_dir=$RESULTS_DIR"

STEP_IDS="$(python3 -c "import yaml; print(' '.join(s['step'] for s in yaml.safe_load(open('$MANIFEST_FILE'))['steps']))")"
PLANNER_OUTFILE="$STATE_DIR/step-1b-plan.json"
EXECUTION_PLAN=""   # populated after planner step runs; CSV of selectable step ids the planner chose

# Lookup helpers — read manifest field for a given step id.
manifest_field() {
  local STEP="$1" FIELD="$2" DEFAULT="${3:-}"
  python3 -c "
import yaml
m = yaml.safe_load(open('$MANIFEST_FILE'))
s = next(s for s in m['steps'] if s['step']=='$STEP')
v = s.get('$FIELD', '$DEFAULT')
print(v)"
}

# True if step should run: always_run OR present in execution_plan.
should_run_step() {
  local STEP="$1"
  local ALWAYS
  ALWAYS="$(manifest_field "$STEP" "always_run" "False")"
  if [[ "$ALWAYS" == "True" ]]; then
    return 0
  fi
  # Selectable step — gate on planner's execution_plan
  if [[ -z "$EXECUTION_PLAN" ]]; then
    # Planner hasn't run yet — should never happen if step ordering is correct
    return 0
  fi
  if [[ ",$EXECUTION_PLAN," == *",$STEP,"* ]]; then
    return 0
  fi
  return 1
}

for STEP in $STEP_IDS; do
  AGENT="$(manifest_field "$STEP" "name")"
  OUTNAME="$(manifest_field "$STEP" "outfile")"
  WRITE_TO_ROOT="$(manifest_field "$STEP" "write_to_root" "False")"
  ON_FAIL="$(manifest_field "$STEP" "on_failure" "abort")"

  if ! should_run_step "$STEP"; then
    SKIP_REASON="$(jq -r --arg s "$STEP" '.skipped[]? | select(.step==$s) | .reason' "$PLANNER_OUTFILE" 2>/dev/null | head -1)"
    [[ -z "$SKIP_REASON" ]] && SKIP_REASON="not_selected_by_planner"
    mark "STEP_SKIPPED step=$STEP name=$AGENT reason=$SKIP_REASON"
    continue
  fi

  if [[ "$WRITE_TO_ROOT" == "True" ]]; then
    OUTFILE="$RESULTS_DIR/$OUTNAME"
  else
    OUTFILE="$STATE_DIR/$OUTNAME"
  fi

  INPUTS="$(render_inputs "$STEP")"

  if ! run_step "$STEP" "$AGENT" "$OUTFILE" "$INPUTS" "$ON_FAIL"; then
    if [[ "$ON_FAIL" == "partial" ]]; then
      mark "PIPELINE_DONE verdict=PARTIAL reason=step-${STEP}_failed report=$RESULTS_DIR/report.md"
      exit 0
    fi
    mark "PIPELINE_DONE verdict=ABORTED reason=step-${STEP}_failed"
    exit 1
  fi

  # After the planner step, capture its execution_plan into a bash CSV string
  if [[ "$STEP" == "1b" && -f "$PLANNER_OUTFILE" ]]; then
    EXECUTION_PLAN="$(jq -r '.execution_plan | join(",")' "$PLANNER_OUTFILE" 2>/dev/null || echo "")"
    if [[ -z "$EXECUTION_PLAN" ]]; then
      mark "STEP_FAILED step=1b name=qa-pipeline-planner reason=missing_execution_plan_in_output"
      mark "PIPELINE_DONE verdict=ABORTED reason=planner_no_plan"
      exit 1
    fi
    mark "EXECUTION_PLAN selected=$EXECUTION_PLAN"
  fi
done

# Extract verdict from report (best-effort)
VERDICT="$(grep -E '^\*\*VERDICT:\*\*|^VERDICT:' "$RESULTS_DIR/report.md" 2>/dev/null | head -1 | sed -E 's/.*VERDICT:\*?\*? *//' || echo UNKNOWN)"

mark "PIPELINE_DONE verdict=$VERDICT report=$RESULTS_DIR/report.md"
exit 0
