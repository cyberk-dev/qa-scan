import type { RepoConfig } from './config';
import type { DomainResult, Capability } from './domain-detector';
import type { CriticalFlow } from './flow-extractor';
import { getFlowFixtures, getFixtureDefinitions, type FixtureDefinition, type SetupAction } from './fixture-registry';

export interface TestEnvironment {
  type: string;
  rpc?: string;
  fork_url?: string;
  accounts?: Record<string, { address: string; pkey: string }>;
  fixtures?: string[];
  setup_commands: string[];
  teardown_commands: string[];
}

export interface FlowSpec {
  name: string;
  files: string[];
  test_priority: 'P0' | 'P1' | 'P2';
  states: string[];
  dependencies: string[];
  suggested_tests: string[];
  required_fixtures: string[];
  setup_actions: SetupAction[];
}

export interface TestRoadmap {
  project: string;
  analyzed_at: string;
  commit: string;
  domain: string;
  confidence: number;
  capabilities: Capability[];
  critical_flows: FlowSpec[];
  test_environment: TestEnvironment;
  coverage_gaps: string[];
  fixture_definitions: Record<string, FixtureDefinition>;
}

const WEB3_TEST_ACCOUNTS = {
  alice: {
    pkey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
    address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
  },
  bob: {
    pkey: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',
    address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
  },
};

function getGitHead(repoPath: string): string {
  try {
    const result = Bun.spawnSync(['git', '-C', repoPath, 'rev-parse', 'HEAD']);
    return new TextDecoder().decode(result.stdout).trim();
  } catch {
    return 'unknown';
  }
}

function buildTestEnvironment(domain: DomainResult): TestEnvironment {
  const env: TestEnvironment = {
    type: 'standard',
    setup_commands: [],
    teardown_commands: [],
  };

  for (const cap of domain.capabilities) {
    switch (cap.name) {
      case 'wallet-auth':
        env.type = 'anvil-fork';
        env.rpc = 'http://127.0.0.1:8545';
        env.fork_url = '$MAINNET_RPC';
        env.accounts = WEB3_TEST_ACCOUNTS;
        env.fixtures = ['wallet', 'anvil'];
        env.setup_commands.push('anvil --fork-url $MAINNET_RPC --port 8545 &');
        env.setup_commands.push('sleep 3');
        env.teardown_commands.push('pkill anvil || true');
        break;
      case 'payment-sandbox':
        env.type = 'stripe-test';
        env.setup_commands.push('export STRIPE_SECRET_KEY=$STRIPE_TEST_KEY');
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
    suggestions.push('Test user rejection of signing request');
  }

  if (domain.domain === 'fintech' && flow.name.includes('payment')) {
    suggestions.push('Test payment decline scenarios');
    suggestions.push('Test 3DS authentication flow');
  }

  return suggestions;
}

function identifyCoverageGaps(flows: CriticalFlow[]): string[] {
  const gaps: string[] = [];
  const flowNames = flows.map(f => f.name);

  if (!flowNames.includes('auth')) {
    gaps.push('No authentication flow detected');
  }

  const hasErrorStates = flows.some(f => f.states.includes('error'));
  if (!hasErrorStates) {
    gaps.push('Error state handling not detected');
  }

  return gaps;
}

export function generateRoadmap(
  repo: RepoConfig,
  domain: DomainResult,
  flows: CriticalFlow[],
  workspace: string
): TestRoadmap {
  const repoPath = `${workspace}/${repo.path}`;
  const commit = getGitHead(repoPath);

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
    project: repo.key,
    analyzed_at: new Date().toISOString(),
    commit,
    domain: domain.domain,
    confidence: domain.confidence,
    capabilities: domain.capabilities,
    critical_flows: flowSpecs,
    test_environment: buildTestEnvironment(domain),
    coverage_gaps: identifyCoverageGaps(flows),
    fixture_definitions: getFixtureDefinitions([...allFixtures]),
  };
}
