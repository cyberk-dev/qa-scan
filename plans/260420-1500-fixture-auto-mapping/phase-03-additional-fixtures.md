---
phase: 3
title: Additional Fixtures
status: pending
effort: 0.5h
priority: P2
---

# Phase 3: Additional Fixtures

Create Fintech and SaaS fixture templates.

## File: fixtures/fintech.ts

```typescript
import { test as base } from "@playwright/test";

export class StripeMock {
  #testKey: string;

  constructor(testKey?: string) {
    this.#testKey = testKey || process.env.STRIPE_TEST_KEY || '';
  }

  async createPaymentIntent(amount: number, currency = 'usd') {
    // Mock Stripe PaymentIntent for testing
    return {
      id: `pi_test_${Date.now()}`,
      amount,
      currency,
      status: 'requires_payment_method',
    };
  }

  async confirmPayment(paymentIntentId: string) {
    return { status: 'succeeded' };
  }

  async simulateDecline() {
    return { status: 'failed', error: 'card_declined' };
  }
}

export const stripeFixture = base.extend<{ stripe: StripeMock }>({
  stripe: async ({}, use) => {
    await use(new StripeMock());
  },
});
```

## File: fixtures/saas.ts

```typescript
import { test as base } from "@playwright/test";
import type { Page } from "@playwright/test";

export class OAuthMock {
  #page: Page;

  constructor(page: Page) {
    this.#page = page;
  }

  async injectMockUser(user: { id: string; email: string; name: string }) {
    await this.#page.addInitScript({
      content: `
        window.__QA_MOCK_USER__ = ${JSON.stringify(user)};
        window.__OAUTH_AUTHENTICATED__ = true;
      `,
    });
  }

  async simulateLogout() {
    await this.#page.evaluate(() => {
      (window as any).__OAUTH_AUTHENTICATED__ = false;
      (window as any).__LOGOUT__?.();
    });
  }
}

export const oauthFixture = base.extend<{ oauth: OAuthMock }>({
  oauth: async ({ page }, use) => {
    await use(new OAuthMock(page));
  },
});
```

## Todo

- [ ] Create fixtures/fintech.ts with StripeMock
- [ ] Create fixtures/saas.ts with OAuthMock
- [ ] Export from fixtures/index.ts (optional)
