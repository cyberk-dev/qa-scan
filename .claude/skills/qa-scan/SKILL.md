---
name: qa-scan
description: "QA automation with status protocol: analyze → scout → generate → run → verify → report. Supports user escalation and retry logic."
version: 3.0.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>] [--interactive] [--all]"
---

# QA Scan

Automated QA with **status protocol** for user escalation and retry handling.

Load: `.agents/qa-scan/workflow.md`

## Usage

```
/qa-scan SKI-101                    # Single issue (auto mode)
/qa-scan SKI-101 --interactive      # Step-by-step confirmation
/qa-scan --all                      # Batch: all QA issues
```

## Status Protocol

Agents return: `DONE` | `DONE_WITH_CONCERNS` | `BLOCKED` | `NEEDS_CONTEXT`

- **BLOCKED/NEEDS_CONTEXT** → User escalation
- **3x retry limit** → Then escalate
- **Interactive mode** → Confirm each step

## Quick Reference
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Prompts: `references/` (synced to workspace root)
- Results: `qa-results/{repo}/{issue}/` (workspace level)
- Status Protocol: `references/status-protocol.md`
- Setup: `bunx qa-scan install`
- Verify: `bunx qa-scan verify`

## For Non-Claude Agents
Gemini/Antigravity: use `.agents/qa-scan/workflow.md` (prompt-based)
