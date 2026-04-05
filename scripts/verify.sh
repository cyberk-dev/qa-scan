#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE="$(cd "$AGENTS_DIR/../.." && pwd)"

ERRORS=0
WARNINGS=0

echo "=== QA Scan Environment Check ==="
echo ""

# Core dependencies
echo "--- Core ---"
command -v bun >/dev/null 2>&1 && echo "✓ Bun $(bun --version)" || { echo "✗ Bun not installed"; ERRORS=$((ERRORS+1)); }
cd "$AGENTS_DIR" && npx playwright --version >/dev/null 2>&1 && echo "✓ Playwright $(npx playwright --version 2>/dev/null)" || { echo "✗ Playwright not installed (run: bun run setup)"; ERRORS=$((ERRORS+1)); }

# Config files
echo ""
echo "--- Config ---"
[ -f "$AGENTS_DIR/config/qa.config.yaml" ] && echo "✓ qa.config.yaml" || { echo "✗ qa.config.yaml missing"; ERRORS=$((ERRORS+1)); }
[ -f "$AGENTS_DIR/workflow.md" ] && echo "✓ workflow.md" || { echo "✗ workflow.md missing"; ERRORS=$((ERRORS+1)); }
[ -f "$AGENTS_DIR/scripts/playwright.config.ts" ] && echo "✓ playwright.config.ts" || { echo "✗ playwright.config.ts missing"; ERRORS=$((ERRORS+1)); }

# Prompt references
echo ""
echo "--- Prompts ---"
for prompt in analyze-issue analyze-flow generate-test scout-code adversarial-verifier coverage-verifier synthesize-report adversarial-probes verdict-rules; do
  [ -f "$AGENTS_DIR/references/$prompt.md" ] && echo "✓ $prompt.md" || { echo "✗ $prompt.md missing"; ERRORS=$((ERRORS+1)); }
done

# Agent adapters
echo ""
echo "--- Adapters ---"
[ -f "$WORKSPACE/.claude/skills/qa-scan/SKILL.md" ] && echo "✓ Claude adapter" || { echo "⚠ Claude adapter missing"; WARNINGS=$((WARNINGS+1)); }
[ -f "$WORKSPACE/.gemini/qa-scan.md" ] && echo "✓ Gemini adapter" || { echo "⚠ Gemini adapter missing"; WARNINGS=$((WARNINGS+1)); }
[ -f "$WORKSPACE/.antigravity/qa-scan.md" ] && echo "✓ Antigravity adapter" || { echo "⚠ Antigravity adapter missing"; WARNINGS=$((WARNINGS+1)); }

# Agent definitions
echo ""
echo "--- Agents ---"
for agent in qa-orchestrator qa-issue-analyzer qa-code-scout qa-flow-analyzer qa-test-generator qa-test-runner qa-adversarial-verifier qa-coverage-verifier qa-report-synthesizer; do
  [ -f "$WORKSPACE/.claude/agents/$agent.md" ] && echo "✓ $agent" || { echo "Warning: $agent missing (run install.sh)"; WARNINGS=$((WARNINGS+1)); }
done

# Orchestrator script
echo ""
echo "--- Zero-Touch ---"
[ -f "$AGENTS_DIR/scripts/qa-orchestrator.sh" ] && echo "✓ qa-orchestrator.sh" || { echo "✗ qa-orchestrator.sh missing"; ERRORS=$((ERRORS+1)); }
[ -f "$AGENTS_DIR/evidence/qa-tracker.json" ] && echo "✓ qa-tracker.json" || { echo "Warning: qa-tracker.json missing (will be created on first run)"; WARNINGS=$((WARNINGS+1)); }
[ -f "$AGENTS_DIR/evidence/hotspot-memory.json" ] && echo "✓ hotspot-memory.json" || { echo "Warning: hotspot-memory.json missing (run install.sh)"; WARNINGS=$((WARNINGS+1)); }

# Evidence dir
echo ""
echo "--- Evidence ---"
[ -d "$AGENTS_DIR/evidence" ] && echo "✓ evidence/" || { echo "✗ evidence/ missing"; ERRORS=$((ERRORS+1)); }

# Summary
echo ""
echo "========================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo "✓ All checks passed"
elif [ $ERRORS -eq 0 ]; then
  echo "⚠ $WARNINGS warnings (run install.sh to fix)"
else
  echo "✗ $ERRORS errors, $WARNINGS warnings"
fi
