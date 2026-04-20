---
phase: 1
title: Fixture Registry
status: pending
effort: 1h
priority: P1
---

# Phase 1: Fixture Registry

Create centralized domain → flow → fixtures mapping.

## File: cli/fixture-registry.ts

```typescript
export interface FixtureDefinition {
  import: string;
  class: string;
  singleton?: boolean;
}

export interface SetupAction {
  type: string;
  config?: Record<string, string>;
}

export interface FlowFixtureMapping {
  fixtures: string[];
  setup_actions: SetupAction[];
}

export const FIXTURE_DEFINITIONS: Record<string, FixtureDefinition> = {
  wallet: { import: 'fixtures/web3', class: 'WalletFixture' },
  anvil: { import: 'fixtures/web3', class: 'AnvilClient', singleton: true },
  stripe: { import: 'fixtures/fintech', class: 'StripeMock' },
  oauth: { import: 'fixtures/saas', class: 'OAuthMock' },
};

export const DOMAIN_FLOW_FIXTURES: Record<string, Record<string, FlowFixtureMapping>> = {
  web3: {
    wallet: {
      fixtures: ['wallet', 'anvil'],
      setup_actions: [
        { type: 'start_anvil', config: { fork_url: '$MAINNET_RPC' } },
        { type: 'inject_mock_wallet' }
      ]
    },
    transaction: {
      fixtures: ['wallet', 'anvil'],
      setup_actions: [{ type: 'start_anvil' }, { type: 'fund_account' }]
    }
  },
  fintech: {
    payment: {
      fixtures: ['stripe'],
      setup_actions: [{ type: 'init_stripe_test', config: { key: '$STRIPE_TEST_KEY' } }]
    },
    checkout: {
      fixtures: ['stripe'],
      setup_actions: [{ type: 'init_stripe_test' }]
    }
  },
  saas: {
    auth: {
      fixtures: ['oauth'],
      setup_actions: [{ type: 'init_oauth_mock' }]
    }
  }
};

export function getFlowFixtures(domain: string, flowName: string): FlowFixtureMapping | null {
  return DOMAIN_FLOW_FIXTURES[domain]?.[flowName] || null;
}

export function getFixtureDefinitions(fixtureNames: string[]): Record<string, FixtureDefinition> {
  const result: Record<string, FixtureDefinition> = {};
  for (const name of fixtureNames) {
    if (FIXTURE_DEFINITIONS[name]) {
      result[name] = FIXTURE_DEFINITIONS[name];
    }
  }
  return result;
}
```

## Todo

- [ ] Create cli/fixture-registry.ts with types
- [ ] Define FIXTURE_DEFINITIONS for all fixture classes
- [ ] Define DOMAIN_FLOW_FIXTURES mapping
- [ ] Export helper functions
