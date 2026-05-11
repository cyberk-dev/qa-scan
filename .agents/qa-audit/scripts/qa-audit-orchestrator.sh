#!/usr/bin/env bash
# qa-audit-orchestrator.sh — Drive the qa-audit pipeline (board-wide pre-deploy audit).
#
# Architecture:
#   - Manifest-driven: steps in references/qa-audit-pipeline.yaml
#   - Per-run audit dir: {audit.output_dir}/{YYYY-MM-DD}-{repo_key}/
#   - kind=script  → orchestrator runs `bash <script>` and pipes stdout to state/{outfile}
#   - kind=agent   → orchestrator spawns `gemini -y -p` with the agent prompt (added later)
#
# Usage:
#   bash .agents/qa-audit/scripts/qa-audit-orchestrator.sh <repo-key> [flags]
#
# Flags (forwarded to issue collector):
#   --state {open|closed|all}      default: from config
#   --labels lbl1,lbl2             default: from config
#   --since YYYY-MM-DD             default: from config
#   --max-items N                  default: 200
#
# Stdout markers (parseable by callers):
#   PIPELINE_BEGIN  repo=<key> github_repo=<slug> audit_dir=<path>
#   STEP_BEGIN      step=<n> name=<agent> kind=<script|agent>
#   STEP_COMPLETE   step=<n> name=<agent> status=<DONE|DONE_WITH_CONCERNS> output=<path>
#   STEP_FAILED     step=<n> name=<agent> reason=<text>
#   PIPELINE_DONE   verdict=<PASS|FAIL|PARTIAL|ABORTED> audit_dir=<path>

set -euo pipefail

# ── argument parsing ─────────────────────────────────────────────────────────

REPO_KEY=""
STATE_OVERRIDE=""
LABELS_OVERRIDE=""
SINCE_OVERRIDE=""
MAX_ITEMS_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)      STATE_OVERRIDE="$2"; shift 2 ;;
    --labels)     LABELS_OVERRIDE="$2"; shift 2 ;;
    --since)      SINCE_OVERRIDE="$2"; shift 2 ;;
    --max-items)  MAX_ITEMS_OVERRIDE="$2"; shift 2 ;;
    --help|-h)    sed -n '1,30p' "$0"; exit 0 ;;
    -*)           echo "ERROR: unknown flag: $1" >&2; exit 1 ;;
    *)            REPO_KEY="$1"; shift ;;
  esac
done

if [[ -z "$REPO_KEY" ]]; then
  echo "Usage: bash .agents/qa-audit/scripts/qa-audit-orchestrator.sh <repo-key> [flags]" >&2
  exit 1
fi

# ── dependency checks ───────────────────────────────────────────────────────

for bin in python3 jq gh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: '$bin' not in PATH" >&2; exit 1; }
done

# ── path resolution ─────────────────────────────────────────────────────────

CONFIG_FILE=".agents/qa-audit/config/audit.config.yaml"
MANIFEST_FILE=".agents/qa-audit/references/qa-audit-pipeline.yaml"

[[ -f "$CONFIG_FILE" ]]   || { echo "ERROR: $CONFIG_FILE not found" >&2; exit 1; }
[[ -f "$MANIFEST_FILE" ]] || { echo "ERROR: $MANIFEST_FILE not found" >&2; exit 1; }

# Resolve github_repo + output_dir from config.
# NOTE: bash 3.2 (macOS default) mishandles heredocs inside $(...) — use python3 -c instead.
RESOLVE_PY='
import os, yaml, shlex
key  = os.environ["RK"]
path = os.environ["CF"]
cfg  = yaml.safe_load(open(path)) or {}
repo = (cfg.get("repos", {}) or {}).get(key)
if not repo:
    print("echo \"ERROR: repo key not in config: " + key + "\" >&2; exit 1")
    raise SystemExit(0)
out_dir = ((cfg.get("audit", {}) or {}).get("output_dir")) or "./.agents/qa-audit/evidence/audits"
print("GITHUB_REPO=" + shlex.quote(repo.get("github_repo","")))
print("OUTPUT_DIR=" + shlex.quote(out_dir))
'
eval "$(RK="$REPO_KEY" CF="$CONFIG_FILE" python3 -c "$RESOLVE_PY")"

[[ -n "${GITHUB_REPO:-}" ]] || { echo "ERROR: github_repo not set for repo '$REPO_KEY'" >&2; exit 1; }

DATE_TAG="$(date +%Y-%m-%d)"
AUDIT_DIR="$OUTPUT_DIR/${DATE_TAG}-${REPO_KEY}"
STATE_DIR="$AUDIT_DIR/state"
mkdir -p "$STATE_DIR"

# ── helpers ─────────────────────────────────────────────────────────────────

mark() { printf '%s\n' "$*"; }
log()  { printf '[qa-audit] %s\n' "$*" >&2; }

manifest_field() {
  local STEP="$1" FIELD="$2" DEFAULT="${3:-}"
  MF_FILE="$MANIFEST_FILE" MF_STEP="$STEP" MF_FIELD="$FIELD" MF_DEFAULT="$DEFAULT" \
    python3 -c '
import os, yaml
m = yaml.safe_load(open(os.environ["MF_FILE"]))
s = next(s for s in m["steps"] if s["step"]==os.environ["MF_STEP"])
print(s.get(os.environ["MF_FIELD"], os.environ["MF_DEFAULT"]))'
}

# Run a kind=script step. Orchestrator builds the arg list per step name.
# Args: $1=step_id $2=name $3=script_path $4=outfile_abs
run_script_step() {
  local STEP="$1" NAME="$2" SCRIPT="$3" OUT="$4"
  local ARGS=()

  case "$NAME" in
    qa-audit-issue-collector)
      ARGS+=( --repo "$REPO_KEY" )
      [[ -n "$STATE_OVERRIDE"     ]] && ARGS+=( --state "$STATE_OVERRIDE" )
      [[ -n "$LABELS_OVERRIDE"    ]] && ARGS+=( --labels "$LABELS_OVERRIDE" )
      [[ -n "$SINCE_OVERRIDE"     ]] && ARGS+=( --since "$SINCE_OVERRIDE" )
      [[ -n "$MAX_ITEMS_OVERRIDE" ]] && ARGS+=( --max-items "$MAX_ITEMS_OVERRIDE" )
      ;;
    *)
      log "no script-arg mapping for $NAME — invoking with no args"
      ;;
  esac

  if ! bash "$SCRIPT" "${ARGS[@]}" > "$OUT" 2> "$OUT.stderr"; then
    mark "STEP_FAILED step=$STEP name=$NAME reason=script_nonzero_exit log=$OUT.stderr"
    return 1
  fi

  # Validate JSON + classify status.
  if ! jq empty "$OUT" >/dev/null 2>&1; then
    mark "STEP_FAILED step=$STEP name=$NAME reason=invalid_json output=$OUT"
    return 1
  fi

  local COUNT STATUS
  COUNT=$(jq 'length' "$OUT" 2>/dev/null || echo 0)
  if [[ "$COUNT" == "0" ]]; then
    STATUS="DONE_WITH_CONCERNS"
  else
    STATUS="DONE"
  fi
  mark "STEP_COMPLETE step=$STEP name=$NAME status=$STATUS output=$OUT count=$COUNT"
  return 0
}

# ── pipeline driver ─────────────────────────────────────────────────────────

mark "PIPELINE_BEGIN repo=$REPO_KEY github_repo=$GITHUB_REPO audit_dir=$AUDIT_DIR"

STEP_IDS="$(python3 -c "import yaml; print(' '.join(s['step'] for s in yaml.safe_load(open('$MANIFEST_FILE'))['steps']))")"

for STEP in $STEP_IDS; do
  NAME="$(manifest_field "$STEP" "name")"
  KIND="$(manifest_field "$STEP" "kind" "agent")"
  OUTNAME="$(manifest_field "$STEP" "outfile")"
  ON_FAIL="$(manifest_field "$STEP" "on_failure" "abort")"
  OUT="$STATE_DIR/$OUTNAME"

  mark "STEP_BEGIN step=$STEP name=$NAME kind=$KIND"

  case "$KIND" in
    script)
      SCRIPT="$(manifest_field "$STEP" "script")"
      [[ -f "$SCRIPT" ]] || { mark "STEP_FAILED step=$STEP name=$NAME reason=script_not_found:$SCRIPT"; exit 1; }
      if ! run_script_step "$STEP" "$NAME" "$SCRIPT" "$OUT"; then
        if [[ "$ON_FAIL" == "partial" ]]; then
          mark "PIPELINE_DONE verdict=PARTIAL reason=step-${STEP}_failed audit_dir=$AUDIT_DIR"
          exit 0
        fi
        mark "PIPELINE_DONE verdict=ABORTED reason=step-${STEP}_failed audit_dir=$AUDIT_DIR"
        exit 1
      fi
      ;;
    agent)
      mark "STEP_FAILED step=$STEP name=$NAME reason=kind_agent_not_yet_implemented"
      mark "PIPELINE_DONE verdict=ABORTED reason=agent_runtime_pending audit_dir=$AUDIT_DIR"
      exit 1
      ;;
    *)
      mark "STEP_FAILED step=$STEP name=$NAME reason=unknown_kind:$KIND"
      exit 1
      ;;
  esac
done

mark "PIPELINE_DONE verdict=PASS audit_dir=$AUDIT_DIR"
exit 0
