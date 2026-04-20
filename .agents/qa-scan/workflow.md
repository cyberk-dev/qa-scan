# QA Scan — Universal Workflow

> **Claude Code / Gemini CLI:** Use native agents in `.claude/agents/` or `.gemini/agents/` (auto-installed by `install.sh`). This workflow.md serves as documentation reference and fallback for agents without native agent support (e.g., Antigravity).

Automated QA pipeline with **status protocol** for user escalation and retry handling.

## Usage

```
qa-scan <issue-id-or-url> [--repo <repo-key>]           # Single issue (auto mode)
qa-scan <issue-id-or-url> --interactive                  # Step-by-step confirmation
qa-scan --all [--repo <repo-key>]                        # Batch: all QA issues
qa-scan --all --interactive                              # Batch with per-issue confirmation
```

**Arguments:**
- `issue-id-or-url`: Linear issue ID (e.g., `SKIN-101`), GitHub issue (e.g., `#42` or `org/repo#42`), or full URL
- `--all`: Fetch ALL issues in QA status and run pipeline for each
- `--repo`: Override/filter repo key from `config/qa.config.yaml`
- `--post`: Auto-post report to issue after scan
- `--interactive`: Enable step-by-step confirmation mode

---

## Status Protocol

All sub-agents report one of these statuses (see `references/status-protocol.md`):

| Status | Meaning | Orchestrator Action |
|--------|---------|---------------------|
| `DONE` | Completed successfully | Proceed to next step |
| `DONE_WITH_CONCERNS` | Completed with flags | Log concern, proceed (or pause if `[correctness]`) |
| `BLOCKED` | Cannot proceed | Escalate to user |
| `NEEDS_CONTEXT` | Missing info | Ask user, retry (max 3x) |

### Escalation Ladder (BLOCKED)

When an agent returns BLOCKED:
1. **More context** → Ask user for additional info
2. **Simpler task** → Decompose into smaller steps
3. **Skip step** → Mark as PARTIAL, continue
4. **Abort** → Stop entire scan

### Retry Logic

- Max 3 retries per step for NEEDS_CONTEXT
- Context REPLACED on retry (not accumulated)
- After 3 failures → escalate as BLOCKED

---

## Interactive Mode (`--interactive`)

Step-by-step confirmation for careful QA:

| Status | Auto Mode | Interactive Mode |
|--------|-----------|------------------|
| DONE | Auto-proceed | Show summary, ask "Continue? [Y/n]" |
| DONE_WITH_CONCERNS | Log, proceed | Show concerns, ask "Continue anyway? [Y/n/review]" |
| BLOCKED | Escalate | Escalate (same) |
| NEEDS_CONTEXT | Ask user | Ask user (same) |

### CLI Fallback

If `AskUserQuestion` tool unavailable (CLI mode):
```
Step 1: Analyze Issue ✓

Status: DONE
Summary: Extracted 3 test scenarios for login flow
Confidence: 0.85

Continue? [Y/n/review]:
```

User replies with: `y`, `n`, or `review` in next message

**Prerequisites:**
- Target app dev server running at configured `base_url`
- Run `bash .agents/qa-scan/scripts/install.sh` first if not set up

---

## Batch Mode (`--all`)

Scans all issues currently in QA status:

1. **Fetch QA issues:**
   - Linear: `linear_listIssues({filter: {state: {name: {eq: "QA"}}, project: {key: {eq: "SKIN"}}}})` 
   - GitHub: `gh issue list --label "QA" --state open --repo org/repo`

2. **For each issue:** Run full pipeline with status handling

3. **Aggregate verdicts:**

| Issue Results | Batch Verdict |
|--------------|---------------|
| All DONE | PASS |
| Any DONE_WITH_CONCERNS, no BLOCKED | PARTIAL |
| Any BLOCKED (skipped) | PARTIAL |
| Any BLOCKED (aborted) | ABORTED |
| Mix of PASS/FAIL verdicts | Report counts |

4. **Generate batch summary report** → `evidence/batch-{date}/summary.md`:
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

## Pipeline (9 Steps)

### Step -1 — Pre-flight Check (MANDATORY)

Before starting, verify required tools are available:

| Tool | Check | Required | Fallback |
|------|-------|----------|----------|
| Linear MCP | `mcp__linear__list_teams()` | ✓ Yes | Manual issue input |
| GitNexus MCP | `mcp__gitnexus__list_repos()` | Optional | Pattern-based scout |
| Playwright | `npx playwright --version` | ✓ Yes | Skip tests (PARTIAL) |

**If any required tool fails:**
1. Show error to user with options
2. User chooses: Fix / Workaround / Abort
3. If Abort → VERDICT = ABORTED

**Example error handling:**
```
Pre-flight: Linear MCP not responding
Options:
  1. Help me start Linear MCP
  2. I'll paste issue details manually
  3. Abort scan
```

### Step 0 — Project Context + Server Health (Claude agents: automatic)

Before running the pipeline, verify:
1. Read project docs (`README.md`, `CLAUDE.md`, `package.json`) — understand tech stack
2. Dev server health check: `curl -s -o /dev/null -w "%{http_code}" {base_url}`
   - If `200`: continue
   - If fail: auto-start via `dev_command` from config, poll 2s intervals, timeout 30s
   - If still fail: VERDICT: PARTIAL ("Server could not be started")

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

### Step 1c — Xác Nhận Phân Tích (Vietnamese)

Present extracted results to user for confirmation:

```
📋 KẾT QUẢ PHÂN TÍCH ISSUE

Issue: SKI-101 - Fix login redirect
Nguồn: Linear

TÍNH NĂNG: Authentication
KỊCH BẢN TEST:
1. Đăng nhập thành công → redirect dashboard
2. Sai password → hiển thị lỗi
3. Để trống fields → validation error

ĐỘ TIN CẬY: 85%

XÁC NHẬN:
1. ✓ Đúng rồi, tiếp tục
2. ✏️ Cần chỉnh sửa
3. ✕ Hủy scan
```

- **Auto mode + confidence >= 0.8:** Skip confirmation
- **Interactive mode:** Always confirm
- User chọn 2 → Nhập chỉnh sửa → Re-confirm
- User chọn 3 → VERDICT = ABORTED

### Step 2 — Scout Code

Load: `./references/scout-code.md`

Find relevant source code for the feature area.

**With GitNexus (if `gitnexus: true` in config):**
1. `gitnexus_query({query: "{feature_area}"})` → find symbols
2. `gitnexus_impact({target: "{changed_function}", direction: "upstream"})` → blast radius
3. `gitnexus_context({name: "{symbol}"})` → callers, callees

**Without GitNexus (fallback):**
1. Grep for feature_area keywords in routes, components, API handlers
2. Glob for related file patterns
3. Read key files to understand structure

**Output:** List of relevant files with purpose of each.

### Step 2b — Analyze Flow

Load: `./references/analyze-flow.md`

Read the code files from Step 3 and extract all testable states, branches, and user actions.

**What to extract:**
- UI states: loading, success, error, empty, auth-required
- Conditional renders: `{condition && ...}`, ternary operators
- User actions: onClick, onSubmit, onChange handlers
- API call states: useQuery/useMutation loading/error/success

**Output:** Test coverage matrix (JSON) — states[], actions[], coverage_summary.

> **Note:** This step runs automatically in the Claude agents pipeline (qa-flow-analyzer). For Gemini/Antigravity, manually read the top 3-5 files from Step 3 and extract states before generating tests.

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
