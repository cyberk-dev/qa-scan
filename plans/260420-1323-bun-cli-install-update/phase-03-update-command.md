# Phase 3: Update Command

## Overview
- **Priority:** P1
- **Status:** pending
- **Effort:** 30m

## Files to Create

| File | Action |
|------|--------|
| `cli/update.ts` | Create - selective sync logic |

## Key Difference from Install

| Aspect | Install | Update |
|--------|---------|--------|
| Dependencies | ✓ Install | Skip |
| qa-results folder | ✓ Create | Skip |
| Agents | ✓ Sync | ✓ Sync |
| SKILL.md | ✓ Create | ✓ Overwrite |
| References | ✓ Sync | ✓ Sync |
| **config/qa.config.yaml** | ✓ Create template | **SKIP** |
| **auth-state-*.json** | N/A | **SKIP** |

## Implementation

```typescript
import { existsSync, copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { glob } from 'glob';

export async function update() {
  const agentsDir = dirname(dirname(import.meta.dir));
  const workspace = dirname(dirname(agentsDir));
  
  // Check if installed
  const installedVersionFile = join(workspace, '.agents/qa-scan/.installed-version');
  const currentVersionFile = join(agentsDir, '.version');
  
  if (!existsSync(installedVersionFile)) {
    console.log('qa-scan not installed. Run: bunx qa-scan install');
    process.exit(1);
  }
  
  const installedVersion = readFileSync(installedVersionFile, 'utf-8').trim();
  const currentVersion = readFileSync(currentVersionFile, 'utf-8').trim();
  
  console.log(`=== QA Scan Update ===`);
  console.log(`Updating: v${installedVersion} → v${currentVersion}\n`);
  
  // Sync agents (Claude + Gemini)
  console.log('→ Syncing agents...');
  syncAgents(agentsDir, workspace);
  
  // Sync SKILL.md
  console.log('→ Syncing Claude skill...');
  syncSkill(agentsDir, workspace);
  
  // Sync Gemini commands
  console.log('→ Syncing Gemini commands...');
  syncCommands(agentsDir, workspace);
  
  // Sync Antigravity
  console.log('→ Syncing Antigravity adapter...');
  syncAntigravity(agentsDir, workspace);
  
  // Sync references
  console.log('→ Syncing references...');
  syncReferences(agentsDir, workspace);
  
  // Update installed version
  writeFileSync(installedVersionFile, currentVersion);
  
  console.log('\n✓ Update complete.');
  console.log('  Skipped: config/qa.config.yaml (preserved)');
}

function syncAgents(agentsDir: string, workspace: string) {
  const targets = [
    { src: 'agents', dest: '.claude/agents' },
    { src: 'agents', dest: '.gemini/agents' },
  ];
  
  for (const { src, dest } of targets) {
    const destDir = join(workspace, dest);
    mkdirSync(destDir, { recursive: true });
    
    for (const f of glob.sync(`${src}/qa-*.md`, { cwd: agentsDir })) {
      const filename = f.replace(`${src}/`, '');
      copyFileSync(join(agentsDir, f), join(destDir, filename));
    }
  }
}

function syncSkill(agentsDir: string, workspace: string) {
  const skillDir = join(workspace, '.claude/skills/qa-scan');
  mkdirSync(skillDir, { recursive: true });
  // Write SKILL.md content (same as install)
}

function syncCommands(agentsDir: string, workspace: string) {
  const dest = join(workspace, '.gemini/commands');
  mkdirSync(dest, { recursive: true });
  
  for (const f of glob.sync('commands/*.toml', { cwd: agentsDir })) {
    copyFileSync(join(agentsDir, f), join(dest, f.replace('commands/', '')));
  }
}

function syncAntigravity(agentsDir: string, workspace: string) {
  const dest = join(workspace, '.antigravity');
  mkdirSync(dest, { recursive: true });
  // Write qa-scan.md content
}

function syncReferences(agentsDir: string, workspace: string) {
  const dest = join(workspace, 'references');
  mkdirSync(dest, { recursive: true });
  
  for (const f of glob.sync('references/*.md', { cwd: agentsDir })) {
    copyFileSync(join(agentsDir, f), join(dest, f.replace('references/', '')));
  }
}
```

## Todo

- [ ] Create cli/update.ts
- [ ] Implement version comparison
- [ ] Implement selective sync (skip config)
- [ ] Test: modify an agent, run update, verify overwritten

## Success Criteria

- Shows version diff: "v2.0.0 → v3.0.0"
- Agents overwritten
- config/qa.config.yaml preserved
- qa-results/ preserved
