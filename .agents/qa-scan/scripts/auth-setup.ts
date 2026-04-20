/**
 * Playwright Global Setup — Auth Storage State
 *
 * Logs in once via browser, saves cookies/storage state to file.
 * All subsequent test runs reuse this state (no login needed per test).
 *
 * Env vars required:
 *   QA_BASE_URL — app base URL (e.g., http://localhost:3001)
 *   QA_AUTH_EMAIL — test account email
 *   QA_AUTH_PASSWORD — test account password
 */
import { chromium } from '@playwright/test';

async function globalSetup() {
  const baseURL = process.env.QA_BASE_URL || 'http://localhost:3001';
  const email = process.env.QA_AUTH_EMAIL;
  const password = process.env.QA_AUTH_PASSWORD;

  if (!email || !password) {
    console.log('⚠ QA_AUTH_EMAIL/PASSWORD not set — skipping auth setup');
    return;
  }

  console.log(`→ Logging in to ${baseURL}/login...`);
  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.goto(`${baseURL}/login`);
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill(password);
  await page.getByRole('button', { name: /login|sign in/i }).click();

  // Wait for successful redirect (adjust URL pattern as needed)
  await page.waitForURL('**/dashboard', { timeout: 15000 });

  // Save storage state (cookies + localStorage)
  await page.context().storageState({ path: './auth-state.json' });
  console.log('✓ Auth state saved to auth-state.json');

  await browser.close();
}

export default globalSetup;
