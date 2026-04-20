import type { Page } from "@playwright/test";
import { test as base } from "@playwright/test";
import { TEST_ACCOUNTS, WalletErrors, type TestAccountName } from "./web3-mock";
import type { MockParameters } from "wagmi/connectors";

export class WalletFixture {
  #page: Page;
  address?: `0x${string}`;

  constructor(page: Page) {
    this.#page = page;
  }

  async connect(
    account: TestAccountName = "alice",
    features?: MockParameters["features"]
  ) {
    const acc = TEST_ACCOUNTS[account];
    this.address = acc.address as `0x${string}`;

    await this.#page.addInitScript({
      content: `
        window.__QA_MOCK_WALLET__ = {
          account: "${account}",
          address: "${acc.address}",
          features: ${JSON.stringify(features || {})}
        };
      `,
    });

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

  async connectWithRejection() {
    await this.connect("alice", WalletErrors.userRejected());
  }
}

export const walletFixture = base.extend<{ wallet: WalletFixture }>({
  wallet: async ({ page }, use) => {
    await use(new WalletFixture(page));
  },
});
