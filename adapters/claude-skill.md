---
name: qa-scan
description: "QA automation: multi-agent pipeline with enforced tool restrictions. Analyze issue → scout → generate test → run → adversarial verify → VERDICT report"
version: 2.0.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>] [--all] [--post]"
---

# QA Scan

Automated QA with **enforced multi-agent pipeline**. Each sub-agent has restricted tool access.

## Quick Start
```
/qa-scan SKIN-101              # Single issue
/qa-scan --all                 # All QA issues (batch)
/qa-scan SKIN-101 --post       # Single + post report to Linear
```

## How It Works

Spawns `qa-orchestrator` agent which coordinates 6 specialized sub-agents:

| Agent | Restriction | Role |
|-------|------------|------|
| qa-issue-analyzer | Read-only | Extract test requirements |
| qa-code-scout | Read-only | Find relevant code |
| qa-test-generator | Write evidence/ only | Generate Playwright test |
| qa-test-runner | Bash only | Execute test + capture video |
| qa-adversarial-verifier | Read-only + background | Try to break it (FavAI-style) |
| qa-report-synthesizer | Write report only | VERDICT: PASS/FAIL/PARTIAL |

## Configuration
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Prompts: `.agents/qa-scan/references/`
- Evidence: `.agents/qa-scan/evidence/`
- Setup: `bash .agents/qa-scan/scripts/install.sh`
- Verify: `bash .agents/qa-scan/scripts/verify.sh`

## For Non-Claude Agents
Gemini/Antigravity: use `.agents/qa-scan/workflow.md` (prompt-based, no enforcement)
