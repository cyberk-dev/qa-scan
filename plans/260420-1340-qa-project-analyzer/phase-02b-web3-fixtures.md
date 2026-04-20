---
phase: 2b
title: Web3 Test Fixtures
status: pending
effort: 2h
priority: P1
research: ../reports/researcher-260420-1403-web3-e2e-testing.md
---

# Phase 2b: Web3 Test Fixtures

Generate Playwright fixtures for Web3 dApps using Wagmi mock connector + Anvil fork.

## Context

When domain detection identifies Web3 (wagmi, viem, ethers), generate:
1. Mock wallet fixture (no real MetaMask needed)
2. Anvil fixture (local fork for tx simulation)
3. Setup/teardown scripts

## Files to Create

- `.agents/qa-scan/fixtures/web3-mock.ts` - Wagmi mock connector factory
- `.agents/qa-scan/fixtures/anvil.ts` - Anvil test client
- `.agents/qa-scan/fixtures/wallet.ts` - Wallet fixture for tests
- `.agents/qa-scan/references/web3-testing.md` - Documentation

## Implementation

### 1. fixtures/web3-mock.ts

```typescript
import { createConfig, http } from "wagmi";
import { mock, type MockParameters } from "wagmi/connectors";
import { foundry, mainnet } from "wagmi/chains";
import { privateKeyToAccount } from "viem/accounts";

// Anvil default test accounts
export const TEST_ACCOUNTS = {
  alice: {
    pkey: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  },
  bob: {
    pkey: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  },
} as const;

export function createMockWagmiConfig(
  accountName: keyof typeof TEST_ACCOUNTS,
  options?: {
    rpcUrl?: string;
    features?: MockParameters["features"];
  }
) {
  const account = TEST_ACCOUNTS[accountName];
  const rpcUrl = options?.rpcUrl || "http://127.0.0.1:8545";
  
  return createConfig({
    chains: [mainnet, foundry],
    connectors: [
      mock({
        accounts: [account.address],
        features: options?.features,
      }),
    ],
    transports: {
      [mainnet.id]: http(rpcUrl),
      [foundry.id]: http(rpcUrl),
    },
  });
}

// Error simulation helpers
export const WalletErrors = {
  userRejected: () => ({ connectError: new Error("User rejected request") }),
  signFailed: () => ({ signMessageError: new Error("Signing failed") }),
  networkError: () => ({ switchChainError: new Error("Network switch failed") }),
};
```

### 2. fixtures/anvil.ts

```typescript
import { createTestClient, http, publicActions, walletActions, parseEther } from "viem";
import { foundry } from "viem/chains";
import type { Page } from "@playwright/test";
import { test as base } from "@playwright/test";

export function createAnvilClient(rpcUrl = "http://127.0.0.1:8545") {
  return createTestClient({
    chain: foundry,
    mode: "anvil",
    transport: http(rpcUrl),
  })
    .extend(publicActions)
    .extend(walletActions)
    .extend((client) => ({
      // Helper: fund account
      async fundAccount(address: `0x${string}`, amount = "100") {
        await client.setBalance({
          address,
          value: parseEther(amount),
        });
      },
      // Helper: sync time
      async syncTime(date: Date) {
        await client.setNextBlockTimestamp({
          timestamp: BigInt(Math.round(date.getTime() / 1000)),
        });
        return client.mine({ blocks: 1 });
      },
      // Helper: impersonate account
      async impersonate(address: `0x${string}`) {
        await client.impersonateAccount({ address });
        return async () => {
          await client.stopImpersonatingAccount({ address });
        };
      },
    }));
}

export type AnvilClient = ReturnType<typeof createAnvilClient>;

export const anvilFixture = base.extend<{ anvil: AnvilClient }>({
  anvil: async ({}, use) => {
    const client = createAnvilClient();
    await use(client);
  },
});
```

### 3. fixtures/wallet.ts

```typescript
import type { Page } from "@playwright/test";
import { test as base } from "@playwright/test";
import { TEST_ACCOUNTS, WalletErrors } from "./web3-mock";
import type { MockParameters } from "wagmi/connectors";

export class WalletFixture {
  #page: Page;
  address?: `0x${string}`;

  constructor(page: Page) {
    this.#page = page;
  }

  async connect(
    account: keyof typeof TEST_ACCOUNTS = "alice",
    features?: MockParameters["features"]
  ) {
    const acc = TEST_ACCOUNTS[account];
    this.address = acc.address;

    // Inject config into page before app loads
    await this.#page.addInitScript({
      content: `
        window.__QA_MOCK_WALLET__ = {
          account: "${account}",
          address: "${acc.address}",
          features: ${JSON.stringify(features || {})}
        };
      `,
    });

    // Wait for app to read config and auto-connect
    await this.#page.waitForFunction(
      () => (window as any).__WALLET_CONNECTED__,
      { timeout: 10000 }
    );
  }

  async disconnect() {
    await this.#page.evaluate(() => {
      (window as any).__DISCONNECT_WALLET__?.();
    });
  }

  // Simulate rejection
  async connectWithRejection() {
    await this.connect("alice", WalletErrors.userRejected());
  }
}

export const walletFixture = base.extend<{ wallet: WalletFixture }>({
  wallet: async ({ page }, use) => {
    await use(new WalletFixture(page));
  },
});
```

### 4. Combined Fixture Export

```typescript
// fixtures/web3.ts
import { mergeTests } from "@playwright/test";
import { anvilFixture } from "./anvil";
import { walletFixture } from "./wallet";

export * from "./web3-mock";
export * from "./anvil";
export * from "./wallet";

export const test = mergeTests(anvilFixture, walletFixture);
export { expect } from "@playwright/test";
```

### 5. Roadmap Generator Integration

Update `roadmap-generator.ts` to include fixtures when Web3 detected:

```typescript
if (domain.domain === "web3") {
  roadmap.test_environment = {
    type: "anvil-fork",
    rpc: "http://127.0.0.1:8545",
    fork_url: "$MAINNET_RPC",
    accounts: TEST_ACCOUNTS,
    fixtures: ["wallet", "anvil"],
    setup_commands: [
      "anvil --fork-url $MAINNET_RPC --port 8545 &",
      "sleep 3",
    ],
    teardown_commands: ["pkill anvil || true"],
  };
  
  roadmap.test_config = {
    fullyParallel: false,  // Sequential for blockchain state
    snapshot_restore: true,
  };
}
```

## Test Generator Enhancement

When generating tests for Web3 projects, include:

```typescript
// Auto-added imports for Web3 tests
import { test, expect } from ".agents/qa-scan/fixtures/web3";

let snapshotId: \`0x\${string}\`;

test.beforeAll(async ({ anvil }) => {
  snapshotId = await anvil.snapshot();
});

test.afterAll(async ({ anvil }) => {
  if (snapshotId) await anvil.revert({ id: snapshotId });
});

test("wallet connect", async ({ page, wallet }) => {
  await page.goto("/");
  await wallet.connect("alice");
  await expect(page.getByTestId("wallet-address")).toContainText("0xf39");
});
```

## Todo

- [ ] Create fixtures/web3-mock.ts with mock config factory
- [ ] Create fixtures/anvil.ts with Anvil client helpers
- [ ] Create fixtures/wallet.ts with WalletFixture class
- [ ] Create fixtures/web3.ts with merged exports
- [ ] Update roadmap-generator.ts for Web3 environment
- [ ] Create references/web3-testing.md documentation
- [ ] Test fixtures with sample Web3 app
