# Web3 E2E Testing Guide

QA-scan provides fixtures for testing Web3 dApps without real wallets or mainnet.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Playwright Test                                      │
├─────────────────────────────────────────────────────┤
│ fixtures/web3.ts                                     │
│   ├── WalletFixture (mock wallet inject)            │
│   └── AnvilClient (blockchain state control)        │
├─────────────────────────────────────────────────────┤
│ wagmi mock connector ←→ Anvil (local fork)          │
└─────────────────────────────────────────────────────┘
```

## Test Accounts

Pre-funded Anvil accounts (10,000 ETH each):

| Name | Address | Use |
|------|---------|-----|
| alice | 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 | Primary test user |
| bob | 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 | Secondary user |

## Usage

```typescript
import { test, expect } from ".agents/qa-scan/fixtures/web3";

test("wallet connect flow", async ({ page, wallet, anvil }) => {
  // Snapshot for isolation
  const snapshotId = await anvil.snapshot();
  
  try {
    await page.goto("/");
    await wallet.connect("alice");
    await expect(page.getByTestId("wallet-address")).toContainText("0xf39");
  } finally {
    await anvil.revert({ id: snapshotId });
  }
});
```

## Fixtures

### WalletFixture

- `connect(account?, features?)` - Inject mock wallet and auto-connect
- `disconnect()` - Trigger disconnect
- `connectWithRejection()` - Simulate user rejection

### AnvilClient

- `fundAccount(address, amount)` - Set ETH balance
- `syncTime(date)` - Set block timestamp
- `impersonate(address)` - Impersonate any address
- `snapshot()` / `revert({id})` - State isolation

## Error Simulation

```typescript
import { WalletErrors } from ".agents/qa-scan/fixtures/web3";

// User rejects connection
await wallet.connect("alice", WalletErrors.userRejected());

// Signing fails
await wallet.connect("alice", WalletErrors.signFailed());

// Network switch fails
await wallet.connect("alice", WalletErrors.networkError());
```

## Setup

Start Anvil before tests:

```bash
anvil --fork-url $MAINNET_RPC --port 8545 &
```

Or use the auto-generated setup script from `bunx qa-scan analyze`.

## App Integration

Your app must check for mock wallet config:

```typescript
// In your WagmiProvider setup
if (typeof window !== "undefined" && window.__QA_MOCK_WALLET__) {
  const { address, features } = window.__QA_MOCK_WALLET__;
  // Use mock connector with provided config
  window.__WALLET_CONNECTED__ = true;
}
```
