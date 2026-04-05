# QA Scan — Agentic QA Automation

Multi-agent QA pipeline with **enforced tool restrictions** and **coverage-driven testing**. Analyzes code to extract testable states, generates comprehensive Playwright tests, verifies coverage completeness.

Works with: **Claude Code** (native agents) | **Gemini CLI** (native agents) | **Antigravity** (workflow.md)

## Install

### Prerequisites

Install an AI coding agent (one of):

```bash
# Claude Code (recommended)
npm install -g @anthropic-ai/claude-code
claude login

# Or: Gemini CLI, Antigravity, etc.
```

### 1-Command Setup

```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
```

With options:
```bash
# Specify install location + project directory
curl -fsSL https://...install.sh | bash -s -- --dir ~/qa-scan --project-dir /path/to/project

# Non-interactive (uses template config, edit manually)
curl -fsSL https://...install.sh | bash -s -- --non-interactive
```

The interactive wizard will:
1. Auto-install Bun + jq (if missing)
2. Clone qa-scan repo to `.agents/qa-scan/`
3. Ask: **Linear** or **GitHub Issues**? Configure auth (API key or OAuth)
4. Configure your project (URL, dev command, branch)
5. Auto-setup **MCP servers** (Linear + GitNexus → `.claude/mcp.json`)
6. Install **Playwright + Chromium**
7. Detect AI agents and install: Claude agents + Gemini agents + Antigravity adapter
8. Print usage instructions

## Usage

### Single Issue
```
/qa-scan SKIN-101
/qa-scan #42 --repo my-project
/qa-scan https://linear.app/team/issue/SKIN-101
```

### All QA Issues (batch)
```
/qa-scan --all
/qa-scan --all --repo my-project --post
```

### Zero-Touch (auto-poll)
```bash
bash ~/.qa-scan/scripts/qa-orchestrator.sh --watch 600
```
Polls Linear every 10 minutes. Auto-tests new QA issues. Posts results + labels.

## How It Works

### Pipeline (v3)

```
Step 0: Project context + dev server health check
Step 1: Fetch + analyze issue → test requirements
Step 2: Scout code → find relevant files (GitNexus if available)
Step 2b: Analyze flow → read code, extract states/branches → test matrix
Step 3: Generate test → Playwright E2E from matrix + issue scenarios
Step 4: Run test → execute + capture video/trace/screenshots
Step 5: Coverage verification → compare tests vs flow matrix
Step 6: Synthesize report → VERDICT: PASS/FAIL/PARTIAL
Step 7: Post results → comment + label on Linear/GitHub
Step 8: Update hotspot memory → track buggy files for future runs
```

**Key v3 improvement:** Step 2b (flow analyzer) reads actual source code to extract every testable state (loading, error, empty, auth, success). Tests are generated for ALL states, not just what the issue description mentions. Coverage verifier checks completeness against the matrix.

### 9 Enforced Agents

Each agent has restricted tool access — cannot exceed its role:

| # | Agent | Access | Role |
|---|-------|--------|------|
| - | orchestrator | Read + spawn | Coordinates pipeline |
| 1 | issue-analyzer | Read-only | Extract test requirements |
| 2 | code-scout | Read-only | Find relevant code files |
| 2b | flow-analyzer | Read-only | Analyze code → test coverage matrix |
| 3 | test-generator | Write evidence/ only | Generate Playwright tests from matrix |
| 4 | test-runner | Bash only | Execute test + capture video |
| 5 | coverage-verifier | Read-only, background | Verify test coverage completeness |
| 6 | report-synthesizer | Write report only | VERDICT: PASS/FAIL/PARTIAL |

> `adversarial-verifier` kept as fallback for Gemini/Antigravity (via workflow.md).

### Feedback Loops

| Memory | Purpose |
|--------|---------|
| `evidence/hotspot-memory.json` | Tracks files with repeated bugs → extra-thorough tests |
| `evidence/flaky-memory.json` | Tracks bad selectors → auto-avoid in test generation |
| `evidence/qa-tracker.json` | Tracks scanned issues → prevents re-scanning |

### Post-QA Labels (auto-applied)

| VERDICT | Label | Action |
|---------|-------|--------|
| PASS | `qa-auto-passed` | Ready for release |
| FAIL | `qa-auto-failed` | Needs fix, tagged to assignee |
| PARTIAL | `qa-needs-manual` | Needs human QA review |

## Configuration

Edit `~/.qa-scan/config/qa.config.yaml`:

```yaml
repos:
  my-project:
    path: /path/to/your/project
    base_url: http://localhost:3000
    source: linear             # or github
    project_key: PROJ          # Linear project key
    branch: dev
    gitnexus: true             # Enable semantic code analysis
```

See `config/qa.config.example.yaml` for all options including auth, vision, labels, and orchestrator settings.

## Auto-Run (Cron)

### macOS (launchd)

Create `~/Library/LaunchAgents/com.cyberk.qa-scan.plist` — runs every 10 min.

### Linux (crontab)

```bash
crontab -e
# Add (replace WORKSPACE_PATH):
*/10 * * * * cd WORKSPACE_PATH && PATH="/usr/local/bin:$PATH" bash .agents/qa-scan/scripts/qa-orchestrator.sh >> /tmp/qa-scan-cron.log 2>&1
```

### Simple (any OS)

```bash
bash ~/.qa-scan/scripts/qa-orchestrator.sh --watch 600
```

See `workflow.md` → "Auto-Run" section for full launchd plist template.

## File Structure

```
agents/          9 agent definitions (tool-restricted, slim — details in references/)
references/      10 prompt templates + verdict rules
scripts/         Playwright config, auth, orchestrator, webhook bridge, verify
config/          qa.config.example.yaml (template)
templates/       Report template (coverage analysis format)
evidence/        Test artifacts, tracker, memory files
workflow.md      Universal pipeline reference (Antigravity fallback)
adapters/        Pre-built agent adapters (Claude, Gemini, Antigravity)
```

## Updating

Re-run the install command — it pulls latest changes:

```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
```

## License

MIT — CyberK
