import { mergeTests } from "@playwright/test";
import { anvilFixture } from "./anvil";
import { walletFixture } from "./wallet";

export * from "./web3-mock";
export * from "./anvil";
export * from "./wallet";

export const test = mergeTests(anvilFixture, walletFixture);
export { expect } from "@playwright/test";
