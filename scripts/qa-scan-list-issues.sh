#!/usr/bin/env bash
# qa-scan-list-issues.sh — Fetch QA-status issue keys from Linear via Gemini MCP subprocess.
#
# Output (stdout): JSON array `[{"id":"MEK-123","title":"...","url":"..."}]`
# Logs (stderr): human-readable progress
#
# Usage:
#   bash scripts/qa-scan-list-issues.sh --repo mekora-fe
#   bash scripts/qa-scan-list-issues.sh --project-key MEK [--status "QA Ready"] [--label qa-ready]
#
# Strategy:
#   1. Read repo config from qa.config.yaml to resolve project_key + filter
#   2. Spawn `gemini -p` with linear MCP loaded → ask for issues as JSON
#   3. Extract JSON from response (gemini may wrap in markdown)
#   4. Print clean JSON to stdout
#
# Why subprocess: consistent with qa-scan-gemini.sh pattern (clean context per call).
# Why not direct GraphQL: avoids managing API token separately when MCP OAuth already set up.

set -euo pipefail

# ── argument parsing ──────────────────────────────────────────────────────────

REPO_KEY=""
PROJECT_KEY=""
STATUS_FILTER="QA Ready"
LABEL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         REPO_KEY="$2"; shift 2 ;;
    --project-key)  PROJECT_KEY="$2"; shift 2 ;;
    --status)       STATUS_FILTER="$2"; shift 2 ;;
    --label)        LABEL_FILTER="$2"; shift 2 ;;
    --help|-h)      sed -n '1,20p' "$0"; exit 0 ;;
    *)              echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── resolve project_key from repo config if needed ───────────────────────────

CONFIG_FILE=".agents/qa-scan/config/qa.config.yaml"
if [[ -z "$PROJECT_KEY" && -n "$REPO_KEY" && -f "$CONFIG_FILE" ]]; then
  PROJECT_KEY=$(python3 -c "
import yaml, sys
cfg = yaml.safe_load(open('$CONFIG_FILE'))
repo = cfg.get('repos', {}).get('$REPO_KEY', {})
print(repo.get('project_key', ''))
" 2>/dev/null || echo "")
fi

if [[ -z "$PROJECT_KEY" ]]; then
  echo "ERROR: project_key not provided (use --project-key MEK or --repo with key in config)" >&2
  exit 1
fi

echo "[info] Listing Linear issues for project=$PROJECT_KEY status=\"$STATUS_FILTER\"" >&2

# ── build gemini prompt ──────────────────────────────────────────────────────

PROMPT=$(cat <<EOF
Use the linear MCP to list issues that are ready for QA testing.

Filter:
- Project key: $PROJECT_KEY
- Status (workflow state name): contains "$STATUS_FILTER" (case-insensitive). Common variants: "QA Ready", "QA", "Ready for QA", "In QA", "QA Testing".
${LABEL_FILTER:+- Label: $LABEL_FILTER}

For each matching issue, extract: identifier (e.g. "MEK-123"), title, url.

Return ONLY a JSON array, no prose, no markdown fence:
[{"id":"MEK-123","title":"Login form validation","url":"https://linear.app/..."}]

If no matches, return: []

If the linear MCP is not available or auth fails, return: {"error":"linear_mcp_unavailable"}
EOF
)

# ── invoke gemini -p subprocess ──────────────────────────────────────────────

echo "[info] Invoking gemini -p (this may take 5-15s)..." >&2

RAW_OUTPUT=$(echo "$PROMPT" | gemini -p "$(cat)" 2>/dev/null || true)

# ── extract JSON array from response ─────────────────────────────────────────
# Gemini may wrap response in markdown code fence or add explanatory text.
# Strategy: find the first `[` and matching `]` containing valid JSON.

JSON_OUTPUT=$(echo "$RAW_OUTPUT" | python3 -c "
import sys, json, re
text = sys.stdin.read()

# Strip markdown code fences
text = re.sub(r'\`\`\`(?:json)?\s*', '', text)
text = re.sub(r'\`\`\`', '', text)

# Try to find JSON array
matches = re.findall(r'\[[\s\S]*?\]', text)
for match in matches:
    try:
        data = json.loads(match)
        if isinstance(data, list):
            print(json.dumps(data))
            sys.exit(0)
    except json.JSONDecodeError:
        continue

# Try error object
err_match = re.search(r'\{[\s\S]*?\"error\"[\s\S]*?\}', text)
if err_match:
    try:
        json.loads(err_match.group(0))
        print(err_match.group(0))
        sys.exit(0)
    except:
        pass

# Fallback: empty array with diagnostic
print('[]')
print('WARN: could not parse gemini response', file=sys.stderr)
" 2>&1)

# Check if error response
if echo "$JSON_OUTPUT" | python3 -c "import sys, json; d = json.loads(sys.stdin.read()); sys.exit(0 if isinstance(d, dict) and 'error' in d else 1)" 2>/dev/null; then
  ERR=$(echo "$JSON_OUTPUT" | python3 -c "import sys, json; print(json.loads(sys.stdin.read()).get('error', 'unknown'))")
  echo "ERROR: linear query failed: $ERR" >&2
  exit 2
fi

# Count
COUNT=$(echo "$JSON_OUTPUT" | python3 -c "import sys, json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")
echo "[info] Found $COUNT issue(s)" >&2

# Print clean JSON to stdout
echo "$JSON_OUTPUT"
