import { test as base } from "@playwright/test";

export class StripeMock {
  #testKey: string;

  constructor(testKey?: string) {
    this.#testKey = testKey || process.env.STRIPE_TEST_KEY || '';
  }

  async createPaymentIntent(amount: number, currency = 'usd') {
    return {
      id: `pi_test_${Date.now()}`,
      amount,
      currency,
      status: 'requires_payment_method',
    };
  }

  async confirmPayment(paymentIntentId: string) {
    return { status: 'succeeded', id: paymentIntentId };
  }

  async simulateDecline() {
    return { status: 'failed', error: 'card_declined' };
  }

  async simulate3DS() {
    return { status: 'requires_action', action: '3ds_redirect' };
  }
}

export const stripeFixture = base.extend<{ stripe: StripeMock }>({
  stripe: async ({}, use) => {
    await use(new StripeMock());
  },
});

export const test = stripeFixture;
export { expect } from "@playwright/test";
