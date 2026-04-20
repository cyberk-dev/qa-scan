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
        { type: 'inject_mock_wallet' },
      ],
    },
    transaction: {
      fixtures: ['wallet', 'anvil'],
      setup_actions: [{ type: 'start_anvil' }, { type: 'fund_account' }],
    },
    auth: {
      fixtures: ['wallet'],
      setup_actions: [{ type: 'inject_mock_wallet' }],
    },
  },
  fintech: {
    payment: {
      fixtures: ['stripe'],
      setup_actions: [{ type: 'init_stripe_test', config: { key: '$STRIPE_TEST_KEY' } }],
    },
    checkout: {
      fixtures: ['stripe'],
      setup_actions: [{ type: 'init_stripe_test' }],
    },
    cart: {
      fixtures: ['stripe'],
      setup_actions: [],
    },
  },
  saas: {
    auth: {
      fixtures: ['oauth'],
      setup_actions: [{ type: 'init_oauth_mock' }],
    },
    profile: {
      fixtures: ['oauth'],
      setup_actions: [{ type: 'init_oauth_mock' }],
    },
  },
  ecommerce: {
    cart: {
      fixtures: [],
      setup_actions: [],
    },
    checkout: {
      fixtures: ['stripe'],
      setup_actions: [{ type: 'init_stripe_test' }],
    },
  },
  generic: {},
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
