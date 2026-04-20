import type { Page } from "@playwright/test";
import { test as base } from "@playwright/test";

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

  async simulateSessionExpiry() {
    await this.#page.evaluate(() => {
      (window as any).__SESSION_EXPIRED__ = true;
    });
  }
}

export const oauthFixture = base.extend<{ oauth: OAuthMock }>({
  oauth: async ({ page }, use) => {
    await use(new OAuthMock(page));
  },
});

export const test = oauthFixture;
export { expect } from "@playwright/test";
