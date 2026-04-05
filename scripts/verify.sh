#!/bin/bash
# QA Scan — Environment Verification
# Checks: dependencies, config, prompts, agents, adapters

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ERRORS=0
WARNINGS=0

echo "=== QA Scan Environment Check ==="
echo "Repo: $REPO_DIR"
echo ""

# Core dependencies
echo "--- Core ---"
command -v bun >/dev/null 2>&1 && echo "✓ Bun $(bun --version)" || { echo "✗ Bun not installed"; ERRORS=$((ERRORS+1)); }
cd "$REPO_DIR" && npx playwright --version >/dev/null 2>&1 && echo "✓ Playwright $(npx playwright --version 2>/dev/null)" || { echo "✗ Playwright not installed (run: bun run setup)"; ERRORS=$((ERRORS+1)); }

# Config files
echo ""
echo "--- Config ---"
[ -f "$REPO_DIR/config/qa.config.yaml" ] && echo "✓ qa.config.yaml" || { echo "⚠ qa.config.yaml missing (run install.sh to configure)"; WARNINGS=$((WARNINGS+1)); }
[ -f "$REPO_DIR/config/qa.config.example.yaml" ] && echo "✓ qa.config.example.yaml" || { echo "✗ qa.config.example.yaml missing"; ERRORS=$((ERRORS+1)); }
[ -f "$REPO_DIR/workflow.md" ] && echo "✓ workflow.md" || { echo "✗ workflow.md missing"; ERRORS=$((ERRORS+1)); }
[ -f "$REPO_DIR/scripts/playwright.config.ts" ] && echo "✓ playwright.config.ts" || { echo "✗ playwright.config.ts missing"; ERRORS=$((ERRORS+1)); }

# Prompt references
echo ""
echo "--- Prompts ---"
for prompt in analyze-issue generate-test scout-code adversarial-verifier synthesize-report self-heal-test vision-analyze config-schema gemini-adapter-guide; do
  [ -f "$REPO_DIR/references/$prompt.md" ] && echo "✓ $prompt.md" || { echo "✗ $prompt.md missing"; ERRORS=$((ERRORS+1)); }
done

# Agent definitions (in repo)
echo ""
echo "--- Agents ---"
for agent in qa-orchestrator qa-issue-analyzer qa-code-scout qa-test-generator qa-test-runner qa-adversarial-verifier qa-report-synthesizer; do
  [ -f "$REPO_DIR/agents/$agent.md" ] && echo "✓ $agent" || { echo "✗ $agent.md missing"; ERRORS=$((ERRORS+1)); }
done

# Adapter templates (in repo)
echo ""
echo "--- Adapters ---"
[ -f "$REPO_DIR/adapters/claude-skill.md" ] && echo "✓ Claude adapter template" || { echo "✗ claude-skill.md missing"; ERRORS=$((ERRORS+1)); }
[ -f "$REPO_DIR/adapters/gemini-adapter.md" ] && echo "✓ Gemini adapter template" || { echo "✗ gemini-adapter.md missing"; ERRORS=$((ERRORS+1)); }
[ -f "$REPO_DIR/adapters/antigravity-adapter.md" ] && echo "✓ Antigravity adapter template" || { echo "✗ antigravity-adapter.md missing"; ERRORS=$((ERRORS+1)); }

# Scripts
echo ""
echo "--- Scripts ---"
[ -f "$REPO_DIR/scripts/qa-orchestrator.sh" ] && echo "✓ qa-orchestrator.sh" || { echo "✗ qa-orchestrator.sh missing"; ERRORS=$((ERRORS+1)); }
[ -f "$REPO_DIR/scripts/auth-setup.ts" ] && echo "✓ auth-setup.ts" || { echo "✓ auth-setup.ts (optional)"; }

# Evidence
echo ""
echo "--- Evidence ---"
[ -d "$REPO_DIR/evidence" ] && echo "✓ evidence/" || { echo "✗ evidence/ missing"; ERRORS=$((ERRORS+1)); }

# Summary
echo ""
echo "========================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo "✓ All checks passed"
elif [ $ERRORS -eq 0 ]; then
  echo "⚠ $WARNINGS warnings (run install.sh to configure)"
else
  echo "✗ $ERRORS errors, $WARNINGS warnings"
fi
