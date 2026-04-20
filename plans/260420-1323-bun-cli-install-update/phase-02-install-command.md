# Phase 2: Install Command

## Overview
- **Priority:** P1
- **Status:** pending
- **Effort:** 30m

## Files to Create

| File | Action |
|------|--------|
| `cli/install.ts` | Create - full install logic |

## Implementation

Port install.sh logic to TypeScript:

```typescript
import { $ } from 'bun';
import { existsSync, mkdirSync, writeFileSync, copyFileSync } from 'fs';
import { join, dirname } from 'path';
import { glob } from 'glob';

export async function install() {
  const agentsDir = dirname(dirname(import.meta.dir));
  const workspace = dirname(dirname(agentsDir));
  
  console.log('=== QA Scan Setup ===\n');
  
  // 1. Install deps
  console.log('→ Installing Playwright...');
  await $`bun install`.cwd(agentsDir);
  await $`npx playwright install chromium`.cwd(agentsDir);
  
  // 2. Create qa-results folder
  const qaResults = join(workspace, 'qa-results');
  mkdirSync(qaResults, { recursive: true });
  
  const trackerFiles = ['qa-tracker.json', 'hotspot-memory.json', 'flaky-memory.json'];
  for (const file of trackerFiles) {
    const path = join(qaResults, file);
    if (!existsSync(path)) writeFileSync(path, '[]');
  }
  console.log(`  Results folder: ${qaResults}`);
  
  // 3. Sync adapters and agents
  await syncAll(agentsDir, workspace);
  
  // 4. Write installed version
  const version = Bun.file(join(agentsDir, '.version')).text();
  writeFileSync(join(workspace, '.agents/qa-scan/.installed-version'), await version);
  
  console.log('\n✓ QA Scan installed successfully.');
  console.log(`  Run: bunx qa-scan verify`);
}

async function syncAll(agentsDir: string, workspace: string) {
  // Claude skill
  const claudeSkill = join(workspace, '.claude/skills/qa-scan');
  mkdirSync(claudeSkill, { recursive: true });
  // ... (SKILL.md content)
  
  // Claude agents
  const claudeAgents = join(workspace, '.claude/agents');
  mkdirSync(claudeAgents, { recursive: true });
  for (const f of glob.sync('agents/qa-*.md', { cwd: agentsDir })) {
    copyFileSync(join(agentsDir, f), join(claudeAgents, f.replace('agents/', '')));
  }
  
  // Gemini agents + commands
  // ... similar pattern
  
  // Antigravity adapter
  // ...
  
  // References
  const refs = join(workspace, 'references');
  mkdirSync(refs, { recursive: true });
  for (const f of glob.sync('references/*.md', { cwd: agentsDir })) {
    copyFileSync(join(agentsDir, f), join(refs, f.replace('references/', '')));
  }
}
```

## Todo

- [ ] Create cli/install.ts
- [ ] Port all install.sh logic
- [ ] Test: `bun run cli/index.ts install`

## Success Criteria

- Fresh workspace installs successfully
- All adapters created
- qa-results folder created
