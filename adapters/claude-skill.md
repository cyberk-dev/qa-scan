---
name: qa-scan
description: "QA automation: multi-agent pipeline with enforced tool restrictions. Analyze issue → scout → analyze flow → generate test → run → coverage verify → VERDICT report"
version: 3.1.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>] [--all] [--post]"
---

# QA Scan

Automated QA with **enforced multi-agent pipeline**.

## No Arguments? → Interactive Mode

If invoked WITHOUT arguments (`/qa-scan`), use `AskUserQuestion` to present options:

| Option | Description |
|--------|-------------|
| Scan single issue | Enter issue ID (e.g., SKIN-101) |
| Scan all QA issues | Batch scan all issues in QA status |
| Run test app | Quick test with built-in test app |
| Show config | Display current qa.config.yaml |
| Verify setup | Run verify.sh to check installation |

After user selects, proceed with the appropriate mode.

## With Arguments → Direct Execution

```
/qa-scan SKIN-101              # Single issue
/qa-scan --all                 # All QA issues (batch)
/qa-scan SKIN-101 --post       # Single + post report
/qa-scan --verify              # Run verify.sh
```

Spawn `qa-orchestrator` agent to execute the pipeline.

## Pipeline

| # | Agent | Restriction | Role |
|---|-------|------------|------|
| 1 | qa-issue-analyzer | Read-only | Extract test requirements |
| 2 | qa-code-scout | Read-only | Find relevant code |
| 2b | qa-flow-analyzer | Read-only | Code → test matrix |
| 3 | qa-test-generator | Write evidence/ only | Playwright tests from matrix |
| 4 | qa-test-runner | Bash only | Execute + capture video |
| 5 | qa-coverage-verifier | Read-only, background | Verify coverage completeness |
| 6 | qa-report-synthesizer | Write report only | VERDICT: PASS/FAIL/PARTIAL |

## Configuration
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Evidence: `.agents/qa-scan/evidence/`
- Setup: `bash .agents/qa-scan/scripts/install.sh`
- Verify: `bash .agents/qa-scan/scripts/verify.sh`
