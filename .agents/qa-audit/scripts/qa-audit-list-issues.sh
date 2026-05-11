#!/usr/bin/env bash
# qa-audit-list-issues.sh — Fetch GitHub issues "in scope" for a pre-deploy QA audit.
#
# Output (stdout): JSON array of normalized issue objects:
#   [{"id":"42","number":42,"title":"...","url":"...","state":"closed",
#     "labels":["qa-ready"],"milestone":"v1.2","repo":"org/repo",
#     "assignees":["alice"],"updatedAt":"2026-05-01T..."}]
# Logs (stderr): human-readable progress + filter summary.
#
# Usage:
#   bash .agents/qa-audit/scripts/qa-audit-list-issues.sh --repo visible-brands-fe
#   bash .agents/qa-audit/scripts/qa-audit-list-issues.sh \
#       --github-repo cyberk-dev/visible-brands-fe \
#       --state closed --labels qa-ready,ready-for-release --since 2026-04-01
#
# Prerequisites:
#   - gh CLI v2.0+ (`gh --version`)
#   - Authenticated with `repo` scope: `gh auth status` (run `gh auth login` if not)

set -euo pipefail

# ── argument parsing ─────────────────────────────────────────────────────────

REPO_KEY=""
GITHUB_REPO=""
STATE=""
LABELS=""
SINCE=""
MAX_ITEMS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)         REPO_KEY="$2"; shift 2 ;;
    --github-repo)  GITHUB_REPO="$2"; shift 2 ;;
    --state)        STATE="$2"; shift 2 ;;
    --labels)       LABELS="$2"; shift 2 ;;
    --since)        SINCE="$2"; shift 2 ;;
    --max-items)    MAX_ITEMS="$2"; shift 2 ;;
    --help|-h)      sed -n '1,25p' "$0"; exit 0 ;;
    *)              echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── prerequisite check ───────────────────────────────────────────────────────

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not installed. See https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh not authenticated. Run: gh auth login -s repo" >&2
  exit 1
fi

# ── resolve from config if --repo provided ───────────────────────────────────

CONFIG_FILE=".agents/qa-audit/config/audit.config.yaml"
if [[ -n "$REPO_KEY" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config not found at $CONFIG_FILE" >&2
    exit 1
  fi
  eval "$(python3 - "$REPO_KEY" "$CONFIG_FILE" <<'PY'
import sys, yaml, shlex
key, path = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(open(path)) or {}
defaults = cfg.get("defaults", {}) or {}
def_filter = defaults.get("filter", {}) or {}
repo = (cfg.get("repos", {}) or {}).get(key)
if not repo:
    print(f"echo 'ERROR: repo key not found in config: {key}' >&2; exit 1")
    sys.exit(0)
flt = repo.get("filter", {}) or {}
def merged(name, default=None):
    val = flt.get(name)
    if val in (None, "", []):
        val = def_filter.get(name, default)
    return val
def emit(name, val):
    if val is None or val == "" or val == []:
        return
    if isinstance(val, list):
        val = ",".join(str(v) for v in val)
    print(f"CFG_{name}={shlex.quote(str(val))}")
emit("REPO",   repo.get("github_repo"))
emit("STATE",  merged("state", "closed"))
emit("LABELS", merged("labels", []))
emit("SINCE",  merged("since", ""))
emit("MAX",    defaults.get("max_items", 200))
PY
)"
  GITHUB_REPO="${GITHUB_REPO:-${CFG_REPO:-}}"
  STATE="${STATE:-${CFG_STATE:-closed}}"
  LABELS="${LABELS:-${CFG_LABELS:-}}"
  SINCE="${SINCE:-${CFG_SINCE:-}}"
  MAX_ITEMS="${MAX_ITEMS:-${CFG_MAX:-200}}"
fi

STATE="${STATE:-closed}"
MAX_ITEMS="${MAX_ITEMS:-200}"

if [[ -z "$GITHUB_REPO" ]]; then
  echo "ERROR: --github-repo required (or --repo with config entry)" >&2
  exit 1
fi

echo "[info] Listing issues: repo=$GITHUB_REPO state=$STATE labels=\"${LABELS:-<none>}\" since=\"${SINCE:-<none>}\" max=$MAX_ITEMS" >&2

# ── build gh issue list args ─────────────────────────────────────────────────

GH_ARGS=( issue list --repo "$GITHUB_REPO" --state "$STATE" --limit "$MAX_ITEMS" \
          --json number,title,url,state,labels,milestone,assignees,updatedAt,closedAt,author )

if [[ -n "$LABELS" ]]; then
  IFS=',' read -ra LABEL_ARR <<< "$LABELS"
  for lbl in "${LABEL_ARR[@]}"; do
    lbl_trimmed="$(echo "$lbl" | xargs)"
    [[ -n "$lbl_trimmed" ]] && GH_ARGS+=( --label "$lbl_trimmed" )
  done
fi

# `--search "updated:>=YYYY-MM-DD"` is the documented way to filter by date.
if [[ -n "$SINCE" ]]; then
  GH_ARGS+=( --search "updated:>=$SINCE" )
fi

# ── invoke + normalize ───────────────────────────────────────────────────────

GH_ERR=$(mktemp)
RAW=$(gh "${GH_ARGS[@]}" 2>"$GH_ERR") || {
  echo "ERROR: gh issue list failed:" >&2
  cat "$GH_ERR" >&2
  rm -f "$GH_ERR"
  exit 2
}
rm -f "$GH_ERR"

NORMALIZED=$(GH_RAW="$RAW" python3 - "$GITHUB_REPO" <<'PY'
import sys, json, os
raw_text = os.environ.get("GH_RAW", "")
repo     = sys.argv[1]
try:
    items = json.loads(raw_text)
except json.JSONDecodeError as e:
    print(f"ERROR: gh returned non-JSON: {e}", file=sys.stderr)
    print(raw_text[:500], file=sys.stderr)
    sys.exit(2)

if not isinstance(items, list):
    print("ERROR: unexpected gh output (not a list)", file=sys.stderr)
    sys.exit(2)

out = []
for it in items:
    labels = [l.get("name") for l in (it.get("labels") or []) if isinstance(l, dict)]
    milestone = it.get("milestone")
    if isinstance(milestone, dict):
        milestone = milestone.get("title")
    assignees = [a.get("login") for a in (it.get("assignees") or []) if isinstance(a, dict)]
    author = (it.get("author") or {}).get("login")
    out.append({
        "id":        str(it.get("number")),
        "number":    it.get("number"),
        "title":     it.get("title") or "",
        "url":       it.get("url") or "",
        "state":     (it.get("state") or "").lower(),
        "labels":    [l for l in labels if l],
        "milestone": milestone,
        "repo":      repo,
        "assignees": [a for a in assignees if a],
        "author":    author,
        "updatedAt": it.get("updatedAt"),
        "closedAt":  it.get("closedAt"),
    })

print(json.dumps(out, indent=2))
print(f"[info] kept={len(out)}", file=sys.stderr)
PY
)

echo "$NORMALIZED"
