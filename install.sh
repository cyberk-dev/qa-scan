#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$(cd "$AGENTS_DIR/../.." && pwd)"

cd "$AGENTS_DIR"

echo "=== QA Scan Setup ==="

# 1. Install dependencies
echo "→ Installing Playwright..."
bun install
npx playwright install chromium

# 2. Create evidence dir + hotspot memory
mkdir -p evidence/logs
[ -f evidence/hotspot-memory.json ] || echo "[]" > evidence/hotspot-memory.json
[ -f evidence/qa-tracker.json ] || echo "[]" > evidence/qa-tracker.json
[ -f evidence/flaky-memory.json ] || echo "[]" > evidence/flaky-memory.json

# 3. Create thin adapters for all 3 agent systems
echo "→ Creating agent adapters..."

# Claude Code adapter
mkdir -p "$WORKSPACE/.claude/skills/qa-scan"
cat > "$WORKSPACE/.claude/skills/qa-scan/SKILL.md" << 'CLAUDE_ADAPTER'
---
name: qa-scan
description: "QA automation: analyze issue → scout code → generate + run Playwright E2E test → adversarial verification → structured VERDICT report"
version: 1.0.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>]"
---

# QA Scan

Automated QA workflow with adversarial verification.

Load: `.agents/qa-scan/workflow.md`

## Quick Reference
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Prompts: `.agents/qa-scan/references/`
- Evidence: `.agents/qa-scan/evidence/`
- Setup: `bash .agents/qa-scan/scripts/install.sh`
- Verify: `bash .agents/qa-scan/scripts/verify.sh`
CLAUDE_ADAPTER

# Gemini CLI adapter
mkdir -p "$WORKSPACE/.gemini"
cat > "$WORKSPACE/.gemini/qa-scan.md" << 'GEMINI_ADAPTER'
# QA Scan Tool (Gemini CLI)

Automated QA workflow: analyze issue → scout code → generate E2E test → run Playwright → adversarial verification → VERDICT report.

## Configuration
- Workflow: `.agents/qa-scan/workflow.md`
- Prompts: `.agents/qa-scan/references/`
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Evidence: `.agents/qa-scan/evidence/`

## Usage
```
qa-scan <issue-id-or-url> [--repo <repo-key>]
```

Follow the 8-step pipeline defined in workflow.md.
GEMINI_ADAPTER

# Antigravity adapter
mkdir -p "$WORKSPACE/.antigravity"
cat > "$WORKSPACE/.antigravity/qa-scan.md" << 'ANTIGRAVITY_ADAPTER'
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
ANTIGRAVITY_ADAPTER

# 5. Copy agent definitions for portability (other AI agents)
echo "→ Copying agent definitions for portability..."
mkdir -p "$AGENTS_DIR/agents"
for agent_file in "$WORKSPACE/.claude/agents"/qa-*.md; do
  [ -f "$agent_file" ] && cp "$agent_file" "$AGENTS_DIR/agents/"
done
echo "  Agents copied to .agents/qa-scan/agents/"

echo ""
echo "✓ QA Scan installed successfully."
echo "  Adapters created: Claude, Gemini, Antigravity"
echo "  Agent definitions copied to .agents/qa-scan/agents/"
echo "  Run: bash .agents/qa-scan/scripts/verify.sh"
