import { createTestClient, http, publicActions, walletActions, parseEther } from "viem";
import { foundry } from "viem/chains";
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
      async fundAccount(address: `0x${string}`, amount = "100") {
        await client.setBalance({
          address,
          value: parseEther(amount),
        });
      },
      async syncTime(date: Date) {
        await client.setNextBlockTimestamp({
          timestamp: BigInt(Math.round(date.getTime() / 1000)),
        });
        return client.mine({ blocks: 1 });
      },
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
