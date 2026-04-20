---
phase: 2
title: Domain Detection
status: pending
effort: 1.5h
priority: P0
---

# Phase 2: Domain Detection

Detect project domain (Web3/fintech/SaaS) from dependencies and config files.

## Files to Create

- `.agents/qa-scan/cli/domain-detector.ts`
- `.agents/qa-scan/references/domain-detection.md`

## Domain Detection Rules

| Domain | Deps Signals | Config Signals |
|--------|-------------|----------------|
| **web3** | wagmi, viem, ethers, web3.js, @rainbow-me/rainbowkit | hardhat.config.ts, foundry.toml |
| **fintech** | stripe, plaid, @stripe/stripe-js | STRIPE_SECRET_KEY in .env |
| **e-commerce** | shopify, medusa, saleor | cart, checkout patterns |
| **saas** | @clerk/*, @auth0/*, supabase | multi-tenant patterns |

## Implementation

### cli/domain-detector.ts

```typescript
interface DomainResult {
  domain: 'web3' | 'fintech' | 'ecommerce' | 'saas' | 'generic';
  confidence: number;
  signals: string[];
  capabilities: Capability[];
}

interface Capability {
  name: string;
  type: 'auth' | 'environment' | 'mocking';
  config: Record<string, string>;
}

const DOMAIN_RULES: DomainRule[] = [
  {
    domain: 'web3',
    deps: ['wagmi', 'viem', 'ethers', 'web3', '@rainbow-me/rainbowkit'],
    configs: ['hardhat.config.ts', 'foundry.toml', 'truffle-config.js'],
    capabilities: [
      { name: 'wallet-auth', type: 'auth', config: { mock: 'anvil' } },
      { name: 'tx-simulation', type: 'environment', config: { rpc: 'ANVIL_RPC_URL' } }
    ]
  },
  {
    domain: 'fintech',
    deps: ['stripe', '@stripe/stripe-js', 'plaid'],
    envVars: ['STRIPE_SECRET_KEY', 'PLAID_CLIENT_ID'],
    capabilities: [
      { name: 'payment-sandbox', type: 'environment', config: { mode: 'test' } }
    ]
  },
  // ... more rules
];

export async function detectDomain(repoPath: string): Promise<DomainResult> {
  const deps = await readDeps(repoPath);
  const configs = await scanConfigs(repoPath);
  const envVars = await readEnvExample(repoPath);
  
  let bestMatch: DomainResult = { domain: 'generic', confidence: 0, signals: [], capabilities: [] };
  
  for (const rule of DOMAIN_RULES) {
    const depMatches = rule.deps.filter(d => deps.includes(d));
    const configMatches = rule.configs?.filter(c => configs.includes(c)) || [];
    const envMatches = rule.envVars?.filter(e => envVars.includes(e)) || [];
    
    const signals = [...depMatches, ...configMatches, ...envMatches];
    const confidence = signals.length / (rule.deps.length + (rule.configs?.length || 0));
    
    if (confidence > bestMatch.confidence) {
      bestMatch = {
        domain: rule.domain,
        confidence,
        signals,
        capabilities: rule.capabilities
      };
    }
  }
  
  return bestMatch;
}
```

## Todo

- [ ] Create cli/domain-detector.ts
- [ ] Add Web3 detection rules (wagmi, viem, ethers)
- [ ] Add fintech detection rules (stripe, plaid)
- [ ] Add SaaS detection rules (clerk, auth0, supabase)
- [ ] Create references/domain-detection.md with rule documentation
- [ ] Test detection on sample projects
