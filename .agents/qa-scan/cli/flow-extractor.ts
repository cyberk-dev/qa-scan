import { readdirSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
import type { DomainResult } from './domain-detector';

export interface CriticalFlow {
  name: string;
  files: string[];
  priority: 'P0' | 'P1' | 'P2';
  states: string[];
  dependencies: string[];
}

const FLOW_PATTERNS: Record<string, string[]> = {
  auth: ['login', 'signup', 'logout', 'auth', 'session', 'signin'],
  payment: ['checkout', 'payment', 'cart', 'order', 'billing'],
  wallet: ['connect', 'wallet', 'sign', 'transaction', 'web3'],
  crud: ['create', 'update', 'delete', 'list', 'edit'],
  profile: ['profile', 'settings', 'account', 'user'],
};

const DOMAIN_QUERIES: Record<string, string[]> = {
  web3: ['wallet connection', 'transaction', 'contract interaction', 'sign message'],
  fintech: ['payment', 'checkout', 'subscription', 'billing'],
  ecommerce: ['cart', 'checkout', 'order', 'product'],
  saas: ['tenant', 'subscription', 'billing', 'onboarding'],
  generic: ['authentication', 'main flow', 'error handling'],
};

async function grepPatterns(repoPath: string, patterns: string[]): Promise<string[]> {
  const searchDirs = ['src', 'app', 'pages', 'components', 'features', 'lib'];
  const files: string[] = [];

  for (const dir of searchDirs) {
    const dirPath = join(repoPath, dir);
    if (!existsSync(dirPath)) continue;

    try {
      const entries = readdirSync(dirPath, { recursive: true, withFileTypes: true });
      for (const entry of entries) {
        if (!entry.isFile()) continue;
        if (!/\.(tsx?|jsx?)$/.test(entry.name)) continue;

        const filePath = join(entry.parentPath || entry.path, entry.name);
        const relativePath = filePath.replace(repoPath + '/', '');

        const matchesPattern = patterns.some(p =>
          relativePath.toLowerCase().includes(p.toLowerCase())
        );

        if (matchesPattern) {
          files.push(relativePath);
        }
      }
    } catch {
      // Skip unreadable directories
    }
  }

  return files;
}

function inferPriority(flowName: string, domain: string): 'P0' | 'P1' | 'P2' {
  const p0Flows = ['auth', 'wallet', 'payment', 'checkout'];
  const p1Flows = ['profile', 'crud', 'cart'];

  if (p0Flows.some(f => flowName.includes(f))) return 'P0';
  if (p1Flows.some(f => flowName.includes(f))) return 'P1';
  return 'P2';
}

export async function extractFlows(repoPath: string, domain: DomainResult): Promise<CriticalFlow[]> {
  const flows: CriticalFlow[] = [];
  const queries = DOMAIN_QUERIES[domain.domain] || DOMAIN_QUERIES.generic;

  // Pattern-based extraction
  for (const [flowType, patterns] of Object.entries(FLOW_PATTERNS)) {
    const files = await grepPatterns(repoPath, patterns);

    if (files.length > 0) {
      flows.push({
        name: flowType,
        files: files.slice(0, 10), // Limit to 10 most relevant
        priority: inferPriority(flowType, domain.domain),
        states: inferStates(flowType),
        dependencies: inferDependencies(flowType, flows),
      });
    }
  }

  // Sort by priority
  flows.sort((a, b) => a.priority.localeCompare(b.priority));

  return flows;
}

function inferStates(flowType: string): string[] {
  const stateMap: Record<string, string[]> = {
    auth: ['logged-out', 'logging-in', 'logged-in', 'error'],
    wallet: ['disconnected', 'connecting', 'connected', 'signing', 'error'],
    payment: ['empty', 'processing', 'success', 'failed'],
    cart: ['empty', 'has-items', 'checkout'],
    crud: ['loading', 'success', 'error', 'empty'],
    profile: ['viewing', 'editing', 'saving', 'error'],
  };
  return stateMap[flowType] || ['idle', 'loading', 'success', 'error'];
}

function inferDependencies(flowType: string, existingFlows: CriticalFlow[]): string[] {
  const depMap: Record<string, string[]> = {
    payment: ['auth', 'cart'],
    cart: ['auth'],
    profile: ['auth'],
    wallet: [],
    auth: [],
    crud: ['auth'],
  };
  return depMap[flowType]?.filter(d => existingFlows.some(f => f.name === d)) || [];
}
