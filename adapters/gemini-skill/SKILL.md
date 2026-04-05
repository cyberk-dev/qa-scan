---
name: qa-scan
description: "QA automation: multi-agent pipeline with enforced tool restrictions. Analyze issue → scout → analyze flow → generate test → run → coverage verify → VERDICT report"
version: 3.0.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>] [--all] [--post]"
---

# QA Scan

Automated QA with enforced multi-agent pipeline.

Spawn the `qa-orchestrator` agent to run the full pipeline:

```
@qa-orchestrator QA scan issue {argument}
```

## Quick Start
```
/qa:scan SKIN-101              # Single issue
/qa:scan --all                 # All QA issues (batch)
/qa:scan SKIN-101 --post       # Single + post report
```

## Configuration
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Agents: `.gemini/agents/qa-*.md`
- Evidence: `.agents/qa-scan/evidence/`
- Verify: `bash .agents/qa-scan/scripts/verify.sh`
