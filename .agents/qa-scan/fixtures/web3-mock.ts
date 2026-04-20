import { createConfig, http } from "wagmi";
import { mock, type MockParameters } from "wagmi/connectors";
import { foundry, mainnet } from "wagmi/chains";

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

export type TestAccountName = keyof typeof TEST_ACCOUNTS;

export function createMockWagmiConfig(
  accountName: TestAccountName,
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
        accounts: [account.address as `0x${string}`],
        features: options?.features,
      }),
    ],
    transports: {
      [mainnet.id]: http(rpcUrl),
      [foundry.id]: http(rpcUrl),
    },
  });
}

export const WalletErrors = {
  userRejected: () => ({ connectError: new Error("User rejected request") }),
  signFailed: () => ({ signMessageError: new Error("Signing failed") }),
  networkError: () => ({ switchChainError: new Error("Network switch failed") }),
};
