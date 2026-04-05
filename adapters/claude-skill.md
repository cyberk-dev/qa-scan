---
name: qa-scan
description: "QA automation: multi-agent pipeline with enforced tool restrictions. Analyze issue → scout → analyze flow → generate test → run → coverage verify → VERDICT report"
version: 3.0.0
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

Spawns `qa-orchestrator` agent which coordinates 7 sub-agents in the main pipeline:

| # | Agent | Restriction | Role |
|---|-------|------------|------|
| 1 | qa-issue-analyzer | Read-only | Extract test requirements from issue |
| 2 | qa-code-scout | Read-only | Find relevant code files |
| 2b | qa-flow-analyzer | Read-only | Analyze code → extract states/branches → test matrix |
| 3 | qa-test-generator | Write evidence/ only | Generate Playwright tests from matrix |
| 4 | qa-test-runner | Bash only | Execute tests + capture video |
| 5 | qa-coverage-verifier | Read-only + background | Verify test coverage completeness |
| 6 | qa-report-synthesizer | Write report only | VERDICT: PASS/FAIL/PARTIAL |

> `qa-adversarial-verifier` kept as alternative verification mode.

**Key improvement (v3):** Flow analyzer reads actual code to build a test coverage matrix (states, branches, actions). Test-generator creates tests for EVERY state, not just issue description. Coverage verifier checks completeness against the matrix.

## Configuration
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Prompts: `.agents/qa-scan/references/`
- Evidence: `.agents/qa-scan/evidence/`
- Setup: `bash .agents/qa-scan/scripts/install.sh`
- Verify: `bash .agents/qa-scan/scripts/verify.sh`

## Multi-Agent Support
- **Claude Code:** Native agents in `.claude/agents/qa-*.md`
- **Gemini CLI:** Native agents in `.gemini/agents/qa-*.md` (same enforcement)
- **Antigravity:** Uses `workflow.md` (prompt-based fallback)
