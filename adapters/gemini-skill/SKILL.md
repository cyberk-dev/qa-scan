---
name: qa-scan
description: "QA automation: multi-agent pipeline. Analyze issue → scout → analyze flow → generate test → run → coverage verify → VERDICT report"
version: 3.1.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>] [--all] [--post]"
---

# QA Scan

Automated QA with enforced multi-agent pipeline.

## No Arguments → Interactive

If activated without a specific issue, ask the user:
1. **Scan issue** — enter issue ID (e.g., SKIN-101)
2. **Scan all** — batch scan all QA issues
3. **Quick test** — run with built-in test-app
4. **Show config** — display qa.config.yaml
5. **Verify setup** — run verify.sh

## With Arguments → Execute

Spawn `qa-orchestrator` agent:
```
@qa-orchestrator QA scan issue {argument}
```

## Configuration
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Agents: `.gemini/agents/qa-*.md`
- Evidence: `.agents/qa-scan/evidence/`
