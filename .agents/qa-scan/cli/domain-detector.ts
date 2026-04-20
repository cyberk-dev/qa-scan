import { existsSync, readFileSync, readdirSync } from 'fs';
import { join } from 'path';

export interface Capability {
  name: string;
  type: 'auth' | 'environment' | 'mocking';
  config: Record<string, string>;
}

export interface DomainResult {
  domain: 'web3' | 'fintech' | 'ecommerce' | 'saas' | 'generic';
  confidence: number;
  signals: string[];
  capabilities: Capability[];
}

interface DomainRule {
  domain: DomainResult['domain'];
  deps: string[];
  configs?: string[];
  envVars?: string[];
  capabilities: Capability[];
}

const DOMAIN_RULES: DomainRule[] = [
  {
    domain: 'web3',
    deps: ['wagmi', 'viem', 'ethers', 'web3', '@rainbow-me/rainbowkit', '@web3modal/wagmi'],
    configs: ['hardhat.config.ts', 'hardhat.config.js', 'foundry.toml', 'truffle-config.js'],
    capabilities: [
      { name: 'wallet-auth', type: 'auth', config: { mock: 'anvil' } },
      { name: 'tx-simulation', type: 'environment', config: { rpc: 'ANVIL_RPC_URL' } },
    ],
  },
  {
    domain: 'fintech',
    deps: ['stripe', '@stripe/stripe-js', 'plaid', '@plaid/link'],
    envVars: ['STRIPE_SECRET_KEY', 'PLAID_CLIENT_ID'],
    capabilities: [
      { name: 'payment-sandbox', type: 'environment', config: { mode: 'test' } },
    ],
  },
  {
    domain: 'ecommerce',
    deps: ['@shopify/hydrogen', '@medusajs/medusa', 'saleor'],
    capabilities: [
      { name: 'cart-mock', type: 'mocking', config: {} },
    ],
  },
  {
    domain: 'saas',
    deps: ['@clerk/nextjs', '@auth0/nextjs-auth0', '@supabase/supabase-js', 'next-auth'],
    capabilities: [
      { name: 'oauth-mock', type: 'auth', config: { provider: 'mock' } },
    ],
  },
];

async function readDeps(repoPath: string): Promise<string[]> {
  const pkgPath = join(repoPath, 'package.json');
  if (!existsSync(pkgPath)) return [];

  const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
  return [
    ...Object.keys(pkg.dependencies || {}),
    ...Object.keys(pkg.devDependencies || {}),
  ];
}

function scanConfigs(repoPath: string): string[] {
  try {
    return readdirSync(repoPath).filter(f =>
      f.includes('hardhat') || f.includes('foundry') || f.includes('truffle')
    );
  } catch {
    return [];
  }
}

function readEnvExample(repoPath: string): string[] {
  const envFiles = ['.env.example', '.env.local.example', '.env.sample'];
  for (const file of envFiles) {
    const path = join(repoPath, file);
    if (existsSync(path)) {
      const content = readFileSync(path, 'utf-8');
      return content.split('\n').map(l => l.split('=')[0]).filter(Boolean);
    }
  }
  return [];
}

export async function detectDomain(repoPath: string): Promise<DomainResult> {
  const deps = await readDeps(repoPath);
  const configs = scanConfigs(repoPath);
  const envVars = readEnvExample(repoPath);

  let bestMatch: DomainResult = { domain: 'generic', confidence: 0, signals: [], capabilities: [] };

  for (const rule of DOMAIN_RULES) {
    const depMatches = rule.deps.filter(d => deps.some(dep => dep.includes(d) || d.includes(dep)));
    const configMatches = rule.configs?.filter(c => configs.includes(c)) || [];
    const envMatches = rule.envVars?.filter(e => envVars.includes(e)) || [];

    const signals = [...depMatches, ...configMatches, ...envMatches];
    const totalPossible = rule.deps.length + (rule.configs?.length || 0) + (rule.envVars?.length || 0);
    const confidence = totalPossible > 0 ? signals.length / totalPossible : 0;

    if (confidence > bestMatch.confidence && signals.length > 0) {
      bestMatch = {
        domain: rule.domain,
        confidence: Math.min(confidence * 2, 1), // boost confidence
        signals,
        capabilities: rule.capabilities,
      };
    }
  }

  return bestMatch;
}
