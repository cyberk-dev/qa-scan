import { existsSync, mkdirSync, writeFileSync, copyFileSync, readdirSync } from 'fs';
import { join } from 'path';

export const SKILL_CONTENT = `---
name: qa-scan
description: "QA automation with status protocol: analyze → scout → generate → run → verify → report. Supports user escalation and retry logic."
version: 3.0.0
argument-hint: "<issue-id-or-url> [--repo <repo-key>] [--interactive] [--all]"
---

# QA Scan

Automated QA with **status protocol** for user escalation and retry handling.

Load: \`.agents/qa-scan/workflow.md\`

## Usage

\`\`\`
/qa-scan SKI-101                    # Single issue (auto mode)
/qa-scan SKI-101 --interactive      # Step-by-step confirmation
/qa-scan --all                      # Batch: all QA issues
\`\`\`

## Status Protocol

Agents return: \`DONE\` | \`DONE_WITH_CONCERNS\` | \`BLOCKED\` | \`NEEDS_CONTEXT\`

- **BLOCKED/NEEDS_CONTEXT** → User escalation
- **3x retry limit** → Then escalate
- **Interactive mode** → Confirm each step

## Quick Reference
- Config: \`.agents/qa-scan/config/qa.config.yaml\`
- Prompts: \`references/\` (synced to workspace root)
- Results: \`qa-results/{repo}/{issue}/\` (workspace level)
- Status Protocol: \`references/status-protocol.md\`
- Setup: \`bunx qa-scan install\`
- Verify: \`bunx qa-scan verify\`

## For Non-Claude Agents
Gemini/Antigravity: use \`.agents/qa-scan/workflow.md\` (prompt-based)
`;

export const ANTIGRAVITY_CONTENT = `# QA Scan Command (Antigravity)

Automated QA workflow: analyze issue → scout code → generate E2E test → run Playwright → adversarial verification → VERDICT report.

## Configuration
- Workflow: \`.agents/qa-scan/workflow.md\`
- Prompts: \`.agents/qa-scan/references/\`
- Config: \`.agents/qa-scan/config/qa.config.yaml\`
- Results: \`qa-results/{repo}/{issue}/\` (workspace level)

## Usage
\`\`\`
/qa-scan <issue-id-or-url> [--repo <repo-key>]
\`\`\`

Follow the 8-step pipeline defined in workflow.md.
`;

export function syncFiles(srcDir: string, destDir: string, pattern: RegExp) {
  if (!existsSync(srcDir)) return;
  mkdirSync(destDir, { recursive: true });

  for (const file of readdirSync(srcDir)) {
    if (pattern.test(file)) {
      copyFileSync(join(srcDir, file), join(destDir, file));
    }
  }
}

export function syncAgents(agentsDir: string, destDir: string) {
  syncFiles(join(agentsDir, 'agents'), destDir, /^qa-.*\.md$/);
}

export function syncCommands(agentsDir: string, destDir: string) {
  syncFiles(join(agentsDir, 'commands'), destDir, /\.toml$/);
}

export function syncReferences(agentsDir: string, destDir: string) {
  syncFiles(join(agentsDir, 'references'), destDir, /\.md$/);
}

export function writeSkill(workspace: string) {
  const skillDir = join(workspace, '.claude/skills/qa-scan');
  mkdirSync(skillDir, { recursive: true });
  writeFileSync(join(skillDir, 'SKILL.md'), SKILL_CONTENT);
}

export function writeAntigravity(workspace: string) {
  const dest = join(workspace, '.antigravity');
  mkdirSync(dest, { recursive: true });
  writeFileSync(join(dest, 'qa-scan.md'), ANTIGRAVITY_CONTENT);
}
