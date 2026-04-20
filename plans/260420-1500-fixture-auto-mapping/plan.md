---
title: "Flow → Fixture Auto-Mapping"
description: "Enhance analyze to auto-map detected flows to required fixtures for test generation"
status: completed
priority: P1
effort: 3h
branch: main
tags: [qa-scan, fixtures, analyzer]
created: 2026-04-20
---

# Flow → Fixture Auto-Mapping

Enhance qa-scan analyze to automatically map detected flows to required fixtures.

## Problem

Current analyze detects flows but doesn't tell test-generator which fixtures to use. Test generator has no way to know a "wallet" flow needs WalletFixture + AnvilClient.

## Solution

1. Create fixture registry with domain → flow → fixtures mapping
2. Enhance FlowSpec to include `required_fixtures` and `setup_actions`
3. Add `fixture_definitions` to test-roadmap.json
4. Update qa-test-generator to auto-inject imports + setup/teardown

## Output Structure

```json
{
  "critical_flows": [{
    "name": "wallet",
    "required_fixtures": ["wallet", "anvil"],
    "setup_actions": [
      { "type": "start_anvil", "config": { "fork_url": "$MAINNET_RPC" } }
    ]
  }],
  "fixture_definitions": {
    "wallet": { "import": "fixtures/web3", "class": "WalletFixture" },
    "stripe": { "import": "fixtures/fintech", "class": "StripeMock" }
  }
}
```

## Phases

| # | Phase | Effort | Files |
|---|-------|--------|-------|
| 1 | [Fixture Registry](./phase-01-fixture-registry.md) | 1h | cli/fixture-registry.ts |
| 2 | [Roadmap Integration](./phase-02-roadmap-integration.md) | 1h | cli/roadmap-generator.ts, types |
| 3 | [Additional Fixtures](./phase-03-additional-fixtures.md) | 0.5h | fixtures/fintech.ts, fixtures/saas.ts |
| 4 | [Test Generator Update](./phase-04-test-generator.md) | 0.5h | qa-test-generator.md agent |

## Success Criteria

- [x] `bunx qa-scan analyze` outputs `required_fixtures` per flow
- [x] `fixture_definitions` included in test-roadmap.json
- [x] Fintech/SaaS fixtures created
- [x] qa-test-generator reads fixture_definitions and auto-injects imports
