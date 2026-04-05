# QA Scan — Agentic QA Automation

Multi-agent QA pipeline with enforced tool restrictions. Fetch issue, analyze, scout code, generate Playwright E2E test, run with video evidence, adversarial verification, VERDICT report.

Works with: **Claude Code** | **Gemini CLI** | **Antigravity**

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

The installer will:
1. Auto-install Bun (if missing)
2. Clone qa-scan repo
3. Install Playwright + Chromium
4. Ask you to configure your project (interactive wizard)
5. Detect your AI agent and install adapters
6. Run verification

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
Polls Linear every 10 minutes. Auto-tests new QA issues. Posts results.

## How It Works

### 8-Step Pipeline

1. **Fetch issue** from Linear/GitHub
2. **Analyze** description → test requirements
3. **Scout code** → find relevant files
4. **Generate test** → Playwright E2E
5. **Run test** → execute + capture video/trace
6. **Adversarial verification** → try to break it (read-only)
7. **Synthesize report** → VERDICT: PASS/FAIL/PARTIAL
8. **Post results** → comment + label on issue

### 7 Enforced Agents

Each agent has restricted tool access — cannot exceed its role:

| Agent | Access | Role |
|-------|--------|------|
| orchestrator | Read + spawn | Coordinates pipeline |
| issue-analyzer | Read-only | Extract test requirements |
| code-scout | Read-only | Find relevant code |
| test-generator | Write evidence/ only | Generate Playwright test |
| test-runner | Bash only | Execute test + capture video |
| adversarial-verifier | Read-only, background | Try to break the fix |
| report-synthesizer | Write report only | VERDICT: PASS/FAIL/PARTIAL |

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
```

See `config/qa.config.example.yaml` for all options.

## File Structure

```
agents/          7 agent definitions (tool-restricted)
references/      9 prompt templates
scripts/         Playwright config, auth, orchestrator, webhook, verify
config/          qa.config.example.yaml (template)
templates/       Report template
workflow.md      Universal pipeline (Gemini/Antigravity fallback)
adapters/        Pre-built agent adapters (Claude, Gemini, Antigravity)
```

## Updating

Re-run the install command — it pulls latest changes:

```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
```

## License

MIT — CyberK
