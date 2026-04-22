# QA Scan — Universal Workflow

> **Claude Code / Gemini CLI:** Use native agents in `.claude/agents/` or `.gemini/agents/` (auto-installed by `install.sh`). This workflow.md serves as documentation reference and fallback for agents without native agent support (e.g., Antigravity).

Automated QA pipeline: analyze issue → scout code → analyze flow → generate test → run → verify coverage → structured report.

## Usage

```
qa-scan <issue-id-or-url> [--repo <repo-key>]    # Single issue
qa-scan --all [--repo <repo-key>]                 # Batch: all QA issues
```

**Arguments:**
- `issue-id-or-url`: Linear issue ID (e.g., `SKIN-101`), GitHub issue (e.g., `#42` or `org/repo#42`), or full URL
- `--all`: Fetch ALL issues in QA status and run pipeline for each
- `--repo`: Override/filter repo key from `config/qa.config.yaml`
- `--post`: Auto-post report to issue after scan

**Prerequisites:**
- Target app dev server running at configured `base_url`
- Run `bash .agents/qa-scan/scripts/install.sh` first if not set up

---

## Batch Mode (`--all`)

Scans all issues currently in QA status:

1. **Fetch QA issues:**
   - Linear: `linear_listIssues({filter: {state: {name: {eq: "QA"}}, project: {key: {eq: "SKIN"}}}})` 
   - GitHub: `gh issue list --label "QA" --state open --repo org/repo`

2. **For each issue:** Run full 8-step pipeline (Steps 1-8)

3. **Generate batch summary report** → `evidence/batch-{date}/summary.md`:
   ```markdown
   # QA Batch Report — {date}
   
   | Issue | Title | VERDICT | Duration |
   |-------|-------|---------|----------|
   | SKIN-101 | Fix ingredient display | PASS | 45s |
   | SKIN-102 | Auth redirect bug | FAIL | 62s |
   
   ## Summary
   - Scanned: 5 issues
   - PASS: 3 | FAIL: 1 | PARTIAL: 1
   - Total time: 4m 12s
   
   ## Failed Issues (action needed)
   ### SKIN-102: Auth redirect bug
   - Failed check: redirect after login goes to /home instead of /dashboard
   - Reproduction: ...
   ```

4. **Rate limiting:** 30s delay between issues to avoid overwhelming dev server

---

## Pipeline (9 Steps — v4)

### Step 0 — Project Context (Claude: qa-context-extractor)

Read project docs (`README.md`, `CLAUDE.md`, `package.json`) → extract stack, entry points, dev command.

### Step 0a — Env Bootstrap (v4 ⭐NEW)

Load: `./references/env-bootstrap.md`

Auto-detect stack → install deps → setup `.env` → start Docker services → **kill port occupants** → spawn dev server → wait-for-ready.

Optional `.qa-scan.yaml` manifest ở target repo root override auto-detect.

Env var escape: `QA_SCAN_NO_KILL=1` → skip kill, BLOCKED on port conflict.

**Output:** `{base_url, server_pid, service_pids, cleanup_hook, diagnostics}`

### Step 1 — Fetch + Analyze Issue

Get issue details from the tracking system.

**Linear issues (SKIN-101, linear.app URL):**
- Use Linear MCP: `linear_getIssue({id: "SKIN-101"})`
- Or Linear API / `gh` fallback
- Extract: title, description, labels, assignee, branch name

**GitHub issues (#42, github.com URL):**
- Use `gh issue view 42 --json title,body,labels`
- Extract: title, body, labels, linked PRs

**Issue Auto-Detection:**
```
Input             → Source   → Repo Config
SKIN-101          → Linear   → match project_key "SKIN" → skin-agent-fe
#42               → GitHub   → requires --repo flag
cyberk-dev/repo#42 → GitHub  → match repo field → openclaw-services
linear.app/...    → Linear   → parse URL → match project_key
github.com/...    → GitHub   → parse URL → match repo field
--repo skin-agent-fe → Explicit override, skip auto-detect
```

**Output:** `{title, description, labels, branch, source}`

### Step 1b — Analyze Issue → Test Requirements

Load: `./references/analyze-issue.md`

Feed issue title + description to LLM with the analyze-issue prompt.

**Output:** JSON with:
- `feature_area`: which part of the app (e.g., "Product Detail", "Auth")
- `test_scenarios[]`: list of testable user flows
- `input_variables`: test data needed
- `expected_behavior`: what "correct" looks like
- `confidence`: 0-1 how clear the requirements are

If confidence < 0.5 → warn user, suggest manual testing.

### Step 2 — Scout Code + Flow + Routes + Shapes (v4 unified)

Load: `./references/scout-code.md` (includes former analyze-flow.md content inline)

v4: Step 2 + Step 2b merged. One agent pass produces everything.

**With GitNexus:**
1. `gitnexus_query({query: "{feature_area}"})` → flows + symbols
2. `gitnexus_impact(...)` → blast radius
3. `gitnexus_context(...)` → callers/callees
4. `gitnexus_route_map(...)` + `gitnexus_shape_check(...)` → API routes + response shapes

**Without GitNexus (fallback):**
1. Grep/glob files by feature keywords
2. Parse top 3-5 files for states/actions (see scout-code.md "Flow Extraction Fallback")
3. Grep route handlers + `.json(` calls → routes + shapes

**Output:** `{files, flows, routes, shapes, test_matrix: {states, actions, gaps}}`

> v4 note: `qa-flow-analyzer` agent removed. Logic lives inline trong `scout-code.md`. Gemini/Antigravity: the fallback section is runnable directly without separate agent.

### Step 3 — Generate Test

Load: `./references/generate-test.md`

Generate Playwright E2E test from requirements + code context.

**Rules (MANDATORY):**
- Accessibility-first selectors: `getByRole` > `getByLabel` > `getByText` > `getByTestId`
- NEVER use CSS selectors unless absolutely no alternative
- `test.describe()` with issue ID in name
- Handle loading states (wait for network idle or spinner)
- Meaningful assertions for expected behavior
- One test file per scenario

**Output:** Save test file to `evidence/{issue-id}/test.spec.ts`

### Step 4 — Run Test

Execute the generated test with Playwright.

```bash
cd .agents/qa-scan
QA_BASE_URL={base_url} npx playwright test evidence/{issue-id}/test.spec.ts \
  --config=scripts/playwright.config.ts
```

Video, trace, and screenshots auto-captured per `playwright.config.ts`.

**Output:** Test results (pass/fail), artifacts in `evidence/{issue-id}/`

### Step 5 — Coverage / Adversarial Verification

**Claude agents:** Load `./references/coverage-verifier.md` — compare test results vs flow analysis matrix.
**Gemini/Antigravity:** Load `./references/adversarial-verifier.md` — try to break the implementation.

READ-ONLY verification step:
- **CANNOT** modify project files
- **MUST** run actual commands (reading code is not verification)
- **CAN** write ephemeral scripts to `/tmp/qa-scan/{issue-id}/`

The verifier receives:
- Test results from Step 4
- Test matrix from Step 2b (if available)
- Feature area + relevant code files

Every check must follow structured format:
```
### Check: [what verifying]
**Command run:** [exact command]
**Output observed:** [terminal output]
**Expected vs Actual:** [comparison]
**Result:** PASS/FAIL or COVERED/GAP
```

Load: `.agents/qa-scan/references/verdict-rules.md`

### Step 6 — Synthesize Report

Load: `./references/synthesize-report.md`

Combine test results (Step 4) + verification results (Step 5) into structured report.

Save to: `evidence/{issue-id}/report.md`

Load: `.agents/qa-scan/references/verdict-rules.md`

### Step 7 — Post Report (Optional)

Post the QA report to the issue tracking system.

**Trigger:** `--post` flag, or `auto_post: true` in config.

**Linear issues:**
```bash
# Via Linear MCP (preferred)
linear_createComment({issueId: "{id}", body: "{report_summary}"})

# Or via Linear API
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: {LINEAR_API_KEY}" \
  -d '{"query": "mutation { commentCreate(input: {issueId: \"{id}\", body: \"{summary}\"}) { success } }"}'
```

**GitHub issues:**
```bash
gh issue comment {number} --repo {org/repo} --body "$(cat evidence/{issue-id}/report.md)"
```

**Report summary for comment** (shorter than full report):
```markdown
## QA Scan: {issue_id}
**VERDICT: {PASS/FAIL/PARTIAL}**

{1-2 sentence summary}

[Video evidence](evidence/{issue-id}/video.webm)
[Full report](evidence/{issue-id}/report.md)

{If FAIL: brief failure description + how to reproduce}
{If PARTIAL: what couldn't be verified and why}
```

---

## Config Reference

Config file: `./config/qa.config.yaml`

```yaml
repos:
  <repo-key>:
    path: <relative-path-to-repo>
    base_url: <dev-server-url>
    source: linear | github
    project_key: <LINEAR-KEY>  # for Linear
    repo: <org/repo>           # for GitHub
    branch: dev | main
    gitnexus: true | false
    auth:
      strategy: skip | storage-state
```

## Error Handling

- If Step 1 fails (can't fetch issue) → ask user to paste description manually
- If Step 4 generates invalid test → log error, skip to Step 6 (verify manually)
- If Step 5 test fails → proceed to Step 6 anyway (verifier may find different issues)
- If Step 6 environment issue → VERDICT: PARTIAL with explanation

---

## Auto-Run (Cron / Zero-Touch)

The zero-touch orchestrator polls for QA issues and runs the pipeline automatically.

### Quick Start (any OS)

```bash
# Run once — scan all repos
bash .agents/qa-scan/scripts/qa-orchestrator.sh

# Watch mode — poll every 10 minutes
bash .agents/qa-scan/scripts/qa-orchestrator.sh --watch 600

# Filter by repo
bash .agents/qa-scan/scripts/qa-orchestrator.sh --repo skin-agent-fe

# Dry run — preview without executing
bash .agents/qa-scan/scripts/qa-orchestrator.sh --dry-run
```

### macOS (launchd)

Create `~/Library/LaunchAgents/com.cyberk.qa-scan.plist` (replace `WORKSPACE_PATH` with your actual path):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.cyberk.qa-scan</string>
  <key>ProgramArguments</key>
  <array>
    <string>bash</string>
    <string>WORKSPACE_PATH/.agents/qa-scan/scripts/qa-orchestrator.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>600</integer>
  <key>WorkingDirectory</key>
  <string>WORKSPACE_PATH</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    <key>HOME</key>
    <string>/Users/YOUR_USER</string>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/qa-scan-cron.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/qa-scan-cron.log</string>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.cyberk.qa-scan.plist
```

### Linux (crontab)

```bash
crontab -e
# Add (replace WORKSPACE_PATH):
*/10 * * * * cd WORKSPACE_PATH && PATH="/usr/local/bin:$PATH" bash .agents/qa-scan/scripts/qa-orchestrator.sh >> /tmp/qa-scan-cron.log 2>&1
```

### Tracker

Results tracked in `evidence/qa-tracker.json` — prevents re-scanning the same issue.
Labels auto-applied to issues: `qa-auto-passed` / `qa-auto-failed` / `qa-needs-manual`.
