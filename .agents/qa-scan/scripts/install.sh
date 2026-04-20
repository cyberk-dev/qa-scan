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

# 2. Create common qa-results folder (workspace level)
QA_RESULTS="$WORKSPACE/qa-results"
mkdir -p "$QA_RESULTS"
[ -f "$QA_RESULTS/qa-tracker.json" ] || echo "[]" > "$QA_RESULTS/qa-tracker.json"
[ -f "$QA_RESULTS/hotspot-memory.json" ] || echo "[]" > "$QA_RESULTS/hotspot-memory.json"
[ -f "$QA_RESULTS/flaky-memory.json" ] || echo "[]" > "$QA_RESULTS/flaky-memory.json"
echo "  Results folder: $QA_RESULTS"

# 3. Create thin adapters for all 3 agent systems
echo "→ Creating agent adapters..."

# Claude Code adapter
mkdir -p "$WORKSPACE/.claude/skills/qa-scan"
cat > "$WORKSPACE/.claude/skills/qa-scan/SKILL.md" << 'CLAUDE_ADAPTER'
---
name: qa-scan
description: "QA automation with status protocol: analyze → scout → generate → run → verify → report. Supports user escalation and retry logic."
version: 2.0.0
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
- Setup: `bash .agents/qa-scan/scripts/install.sh`
- Verify: `bash .agents/qa-scan/scripts/verify.sh`

## For Non-Claude Agents
Gemini/Antigravity: use `.agents/qa-scan/workflow.md` (prompt-based)
CLAUDE_ADAPTER

# Gemini CLI — install agents natively
echo "→ Installing Gemini agents..."
mkdir -p "$WORKSPACE/.gemini/agents"
for agent_file in agents/qa-*.md; do
  [ -f "$agent_file" ] && cp "$agent_file" "$WORKSPACE/.gemini/agents/"
done
echo "  Agents installed to .gemini/agents/"

# Gemini CLI — install slash commands
echo "→ Installing Gemini slash commands..."
mkdir -p "$WORKSPACE/.gemini/commands"
for cmd_file in commands/*.toml; do
  [ -f "$cmd_file" ] && cp "$cmd_file" "$WORKSPACE/.gemini/commands/"
done
echo "  Commands installed to .gemini/commands/"

# Antigravity adapter
mkdir -p "$WORKSPACE/.antigravity"
cat > "$WORKSPACE/.antigravity/qa-scan.md" << 'ANTIGRAVITY_ADAPTER'
# QA Scan Command (Antigravity)

Automated QA workflow: analyze issue → scout code → generate E2E test → run Playwright → adversarial verification → VERDICT report.

## Configuration
- Workflow: `.agents/qa-scan/workflow.md`
- Prompts: `.agents/qa-scan/references/`
- Config: `.agents/qa-scan/config/qa.config.yaml`
- Results: `qa-results/{repo}/{issue}/` (workspace level)

## Usage
```
/qa-scan <issue-id-or-url> [--repo <repo-key>]
```

Follow the 8-step pipeline defined in workflow.md.
ANTIGRAVITY_ADAPTER

# 5. Install Claude Code agents
echo "→ Installing Claude agents..."
mkdir -p "$WORKSPACE/.claude/agents"
for agent_file in agents/qa-*.md; do
  [ -f "$agent_file" ] && cp "$agent_file" "$WORKSPACE/.claude/agents/"
done
echo "  Agents installed to .claude/agents/"

# 6. Sync references to workspace root (agents reference these)
echo "→ Syncing references..."
mkdir -p "$WORKSPACE/references"
cp references/*.md "$WORKSPACE/references/" 2>/dev/null || true
echo "  References synced to workspace root"

echo ""
echo "✓ QA Scan installed successfully."
echo "  Claude skill:    /qa-scan via .claude/skills/qa-scan/"
echo "  Claude agents:   .claude/agents/qa-*.md"
echo "  Gemini command:  /qa-scan via .gemini/commands/qa-scan.toml"
echo "  Gemini agents:   .gemini/agents/qa-*.md"
echo "  Antigravity:     .antigravity/qa-scan.md (workflow.md fallback)"
echo "  Results:         $QA_RESULTS/{repo}/{issue}/"
echo "  Run: bash .agents/qa-scan/scripts/verify.sh"
