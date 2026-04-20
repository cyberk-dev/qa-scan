---
phase: 3
title: Flow Extraction
status: pending
effort: 1.5h
priority: P0
---

# Phase 3: Flow Extraction

Extract critical user flows from codebase using GitNexus or fallback patterns.

## Files to Create

- `.agents/qa-scan/cli/flow-extractor.ts`

## Extraction Strategy

### With GitNexus (preferred)

```typescript
// Use GitNexus MCP if available
const flows = await gitnexus_query({ query: "user flow", repo: repoKey });
const processes = flows.processes.map(p => ({
  name: p.name,
  files: p.symbols.map(s => s.filePath),
  priority: inferPriority(p)
}));
```

### Without GitNexus (fallback)

Pattern-based extraction:
```typescript
const FLOW_PATTERNS = {
  auth: ['login', 'signup', 'logout', 'auth', 'session'],
  payment: ['checkout', 'payment', 'cart', 'order'],
  wallet: ['connect', 'wallet', 'sign', 'transaction'],
  crud: ['create', 'update', 'delete', 'list']
};

// Grep for patterns in routes, pages, components
for (const [flowType, patterns] of Object.entries(FLOW_PATTERNS)) {
  const files = await grepPatterns(repoPath, patterns);
  if (files.length > 0) {
    flows.push({ name: flowType, files, priority: 'P1' });
  }
}
```

## Implementation

### cli/flow-extractor.ts

```typescript
interface CriticalFlow {
  name: string;
  files: string[];
  priority: 'P0' | 'P1' | 'P2';
  states: string[];
  dependencies: string[];
}

export async function extractFlows(
  repoPath: string, 
  domain: DomainResult
): Promise<CriticalFlow[]> {
  // Try GitNexus first
  if (await hasGitNexus(repoPath)) {
    return extractViaGitNexus(repoPath, domain);
  }
  
  // Fallback to pattern matching
  return extractViaPatterns(repoPath, domain);
}

async function extractViaGitNexus(repoPath: string, domain: DomainResult): Promise<CriticalFlow[]> {
  const flows: CriticalFlow[] = [];
  
  // Query domain-specific flows
  const queries = getDomainQueries(domain.domain);
  
  for (const query of queries) {
    const result = await gitnexusQuery({ query, repo: getRepoKey(repoPath) });
    
    for (const process of result.processes || []) {
      flows.push({
        name: process.heuristicLabel || process.name,
        files: process.symbols.map(s => s.filePath),
        priority: inferPriority(process),
        states: extractStates(process),
        dependencies: extractDeps(process)
      });
    }
  }
  
  return flows;
}

function getDomainQueries(domain: string): string[] {
  const base = ['authentication', 'main user flow', 'error handling'];
  const domainSpecific = {
    web3: ['wallet connection', 'transaction', 'contract interaction'],
    fintech: ['payment', 'checkout', 'subscription'],
    ecommerce: ['cart', 'checkout', 'order'],
    saas: ['tenant', 'subscription', 'billing']
  };
  return [...base, ...(domainSpecific[domain] || [])];
}
```

## Todo

- [ ] Create cli/flow-extractor.ts
- [ ] Implement GitNexus extraction path
- [ ] Implement pattern fallback path
- [ ] Add domain-specific query templates
- [ ] Extract states from flow analysis
- [ ] Test with/without GitNexus
