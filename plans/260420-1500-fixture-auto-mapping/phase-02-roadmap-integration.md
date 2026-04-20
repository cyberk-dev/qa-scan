---
phase: 2
title: Roadmap Integration
status: pending
effort: 1h
priority: P1
---

# Phase 2: Roadmap Integration

Update roadmap-generator.ts to include fixture mappings in output.

## Changes to roadmap-generator.ts

### 1. Update FlowSpec interface

```typescript
export interface FlowSpec {
  name: string;
  files: string[];
  test_priority: 'P0' | 'P1' | 'P2';
  states: string[];
  dependencies: string[];
  suggested_tests: string[];
  required_fixtures: string[];           // NEW
  setup_actions: SetupAction[];          // NEW
}
```

### 2. Update TestRoadmap interface

```typescript
export interface TestRoadmap {
  // ... existing fields
  fixture_definitions: Record<string, FixtureDefinition>;  // NEW
}
```

### 3. Update generateRoadmap function

```typescript
import { getFlowFixtures, getFixtureDefinitions, type SetupAction } from './fixture-registry';

export function generateRoadmap(...): TestRoadmap {
  // ... existing code

  const allFixtures = new Set<string>();
  
  const flowSpecs = flows.map(f => {
    const fixtureMapping = getFlowFixtures(domain.domain, f.name);
    const required_fixtures = fixtureMapping?.fixtures || [];
    const setup_actions = fixtureMapping?.setup_actions || [];
    
    required_fixtures.forEach(fix => allFixtures.add(fix));
    
    return {
      ...f,
      test_priority: f.priority,
      suggested_tests: generateTestSuggestions(f, domain),
      required_fixtures,
      setup_actions,
    };
  });

  return {
    // ... existing fields
    critical_flows: flowSpecs,
    fixture_definitions: getFixtureDefinitions([...allFixtures]),
  };
}
```

## Todo

- [ ] Import fixture-registry in roadmap-generator.ts
- [ ] Add required_fixtures and setup_actions to FlowSpec
- [ ] Add fixture_definitions to TestRoadmap
- [ ] Update generateRoadmap to populate fixture fields
- [ ] Test with `bunx qa-scan analyze --force`
