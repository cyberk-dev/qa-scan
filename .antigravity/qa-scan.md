# QA Scan Command (Antigravity)

Automated QA workflow: analyze issue → scout code → generate E2E test → run Playwright → adversarial verification → VERDICT report.

## Configuration
- Workflow: `.agents/qa-scan/workflow.md`
- Prompts: `.agents/qa-scan/references/`
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Evidence: `.agents/qa-scan/evidence/`

## Usage
```
/qa-scan <issue-id-or-url> [--repo <repo-key>]
```

Follow the 8-step pipeline defined in workflow.md.
