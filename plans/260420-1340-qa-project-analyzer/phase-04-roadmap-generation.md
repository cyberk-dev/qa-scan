---
phase: 4
title: Roadmap Generation
status: pending
effort: 1h
priority: P0
---

# Phase 4: Roadmap Generation

Generate test-roadmap.json from domain + flows analysis.

## Files to Create

- `.agents/qa-scan/cli/roadmap-generator.ts`

## Output Schema

```typescript
interface TestRoadmap {
  project: string;
  analyzed_at: string;  // ISO timestamp
  commit: string;       // Git HEAD
  domain: string;
  confidence: number;
  capabilities: Capability[];
  critical_flows: FlowSpec[];
  test_environment: TestEnvironment;
  coverage_gaps: string[];
}

interface FlowSpec {
  name: string;
  files: string[];
  test_priority: 'P0' | 'P1' | 'P2';
  states: string[];
  dependencies: string[];
  suggested_tests: string[];
}

interface TestEnvironment {
  auth: AuthConfig;
  network?: NetworkConfig;
  mocking?: MockConfig;
  setup_commands: string[];
  teardown_commands: string[];
}
```

## Implementation

### cli/roadmap-generator.ts

```typescript
export function generateRoadmap(
  repo: RepoConfig,
  domain: DomainResult,
  flows: CriticalFlow[]
): TestRoadmap {
  const commit = getGitHead(repo.path);
  
  return {
    project: repo.path,
    analyzed_at: new Date().toISOString(),
    commit,
    domain: domain.domain,
    confidence: domain.confidence,
    capabilities: domain.capabilities,
    critical_flows: flows.map(f => ({
      ...f,
      suggested_tests: generateTestSuggestions(f, domain)
    })),
    test_environment: buildTestEnvironment(domain),
    coverage_gaps: identifyCoverageGaps(flows)
  };
}

function buildTestEnvironment(domain: DomainResult): TestEnvironment {
  const env: TestEnvironment = {
    auth: { type: 'session', mock: false },
    setup_commands: [],
    teardown_commands: []
  };
  
  for (const cap of domain.capabilities) {
    switch (cap.name) {
      case 'wallet-auth':
        env.auth = { type: 'wallet-signing', mock: true, provider: 'anvil' };
        env.setup_commands.push('anvil --fork-url $MAINNET_RPC &');
        env.setup_commands.push('sleep 3');
        env.teardown_commands.push('pkill anvil');
        break;
      case 'payment-sandbox':
        env.mocking = { payments: 'stripe-test-mode' };
        break;
    }
  }
  
  return env;
}

function generateTestSuggestions(flow: CriticalFlow, domain: DomainResult): string[] {
  const suggestions: string[] = [];
  
  for (const state of flow.states) {
    suggestions.push(`Test ${flow.name} in ${state} state`);
  }
  
  if (domain.domain === 'web3' && flow.name.includes('wallet')) {
    suggestions.push('Test wallet disconnection mid-flow');
    suggestions.push('Test network switch during transaction');
  }
  
  return suggestions;
}
```

## Todo

- [ ] Create cli/roadmap-generator.ts
- [ ] Implement TestRoadmap schema
- [ ] Build test environment config from capabilities
- [ ] Generate test suggestions per flow
- [ ] Identify coverage gaps
- [ ] Write to cache directory
