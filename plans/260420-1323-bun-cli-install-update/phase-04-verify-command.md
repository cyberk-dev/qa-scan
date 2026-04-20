# Phase 4: Verify Command

## Overview
- **Priority:** P2
- **Status:** pending
- **Effort:** 20m

## Files to Create

| File | Action |
|------|--------|
| `cli/verify.ts` | Create - port verify.sh logic |

## Implementation

```typescript
import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { $ } from 'bun';

export async function verify() {
  const agentsDir = dirname(dirname(import.meta.dir));
  const workspace = dirname(dirname(agentsDir));
  
  let errors = 0;
  let warnings = 0;
  
  console.log('=== QA Scan Environment Check ===\n');
  
  // Core deps
  console.log('--- Core ---');
  errors += await checkCommand('bun --version', 'Bun');
  errors += await checkCommand('npx playwright --version', 'Playwright', agentsDir);
  
  // Config
  console.log('\n--- Config ---');
  errors += checkFile(join(agentsDir, 'config/qa.config.yaml'), 'qa.config.yaml');
  errors += checkFile(join(agentsDir, 'workflow.md'), 'workflow.md');
  
  // Adapters
  console.log('\n--- Adapters ---');
  warnings += checkFile(join(workspace, '.claude/skills/qa-scan/SKILL.md'), 'Claude skill', true);
  warnings += checkFile(join(workspace, '.antigravity/qa-scan.md'), 'Antigravity', true);
  
  // Claude agents
  console.log('\n--- Claude Agents ---');
  const agents = ['qa-orchestrator', 'qa-issue-analyzer', 'qa-code-scout', 'qa-test-generator', 'qa-test-runner'];
  for (const a of agents) {
    warnings += checkFile(join(workspace, `.claude/agents/${a}.md`), a, true);
  }
  
  // Gemini agents
  console.log('\n--- Gemini Agents ---');
  for (const a of agents) {
    warnings += checkFile(join(workspace, `.gemini/agents/${a}.md`), `${a} (gemini)`, true);
  }
  
  // Results folder
  console.log('\n--- Results ---');
  const qaResults = join(workspace, 'qa-results');
  errors += checkFile(qaResults, 'qa-results/', false, true);
  warnings += checkFile(join(qaResults, 'qa-tracker.json'), 'qa-tracker.json', true);
  
  // Summary
  console.log('\n========================');
  if (errors === 0 && warnings === 0) {
    console.log('✓ All checks passed');
  } else if (errors === 0) {
    console.log(`⚠ ${warnings} warnings (run: bunx qa-scan install)`);
  } else {
    console.log(`✗ ${errors} errors, ${warnings} warnings`);
    process.exit(1);
  }
}

async function checkCommand(cmd: string, name: string, cwd?: string): Promise<number> {
  try {
    const result = cwd 
      ? await $`${cmd.split(' ')}`.cwd(cwd).quiet()
      : await $`${cmd.split(' ')}`.quiet();
    console.log(`✓ ${name}`);
    return 0;
  } catch {
    console.log(`✗ ${name} not installed`);
    return 1;
  }
}

function checkFile(path: string, name: string, warn = false, isDir = false): number {
  const exists = existsSync(path);
  if (exists) {
    console.log(`✓ ${name}`);
    return 0;
  } else {
    console.log(`${warn ? '⚠' : '✗'} ${name} missing`);
    return 1;
  }
}
```

## Todo

- [ ] Create cli/verify.ts
- [ ] Port verify.sh checks
- [ ] Test: `bun run cli/index.ts verify`

## Success Criteria

- Shows all checks with ✓/✗/⚠
- Exit code 1 if errors
- Exit code 0 if only warnings
