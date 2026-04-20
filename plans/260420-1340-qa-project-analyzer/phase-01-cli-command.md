---
phase: 1
title: CLI Command
status: pending
effort: 1h
priority: P0
---

# Phase 1: CLI Command

Add `analyze` and `status` commands to CLI.

## Files to Modify

- `.agents/qa-scan/cli/index.ts` - Add analyze/status routing
- `.agents/qa-scan/cli/analyze.ts` - New file

## Implementation

### 1. Update cli/index.ts

Add routing for new commands:
```typescript
case 'analyze':
  await analyze(args);
  break;
case 'status':
  await status();
  break;
```

### 2. Create cli/analyze.ts

```typescript
export async function analyze(args: string[]) {
  const repoKey = parseArg(args, '--repo');
  const force = args.includes('--force');
  
  // Load qa.config.yaml
  const config = loadConfig();
  const repos = repoKey ? [config.repos[repoKey]] : Object.values(config.repos);
  
  for (const repo of repos) {
    console.log(`→ Analyzing ${repo.path}...`);
    
    // Check cache unless --force
    if (!force && isCacheValid(repo)) {
      console.log(`  ✓ Cache valid (commit: ${getCachedCommit(repo)})`);
      continue;
    }
    
    // Run analysis pipeline
    const domain = await detectDomain(repo.path);
    const flows = await extractFlows(repo.path, domain);
    const roadmap = generateRoadmap(repo, domain, flows);
    
    // Write cache
    writeRoadmap(repo, roadmap);
    console.log(`  ✓ Roadmap generated`);
  }
}
```

### 3. Create cli/status.ts

```typescript
export async function status() {
  const config = loadConfig();
  
  console.log('=== QA Scan Status ===\n');
  
  for (const [key, repo] of Object.entries(config.repos)) {
    const roadmap = loadRoadmap(repo);
    if (!roadmap) {
      console.log(`${key}: ✗ Not analyzed`);
      continue;
    }
    
    const stale = !isCacheValid(repo);
    console.log(`${key}: ${stale ? '⚠ Stale' : '✓ Fresh'} (${roadmap.analyzed_at})`);
  }
}
```

## Todo

- [ ] Add `analyze` case to cli/index.ts
- [ ] Create cli/analyze.ts with args parsing
- [ ] Create cli/status.ts
- [ ] Test: `bunx qa-scan analyze --help`
