# Generate Playwright E2E Test

You are generating a Playwright E2E test for a specific QA scenario.

## Input

- **test_scenario**: from analyze-issue step (name, user_action, expected_result)
- **code_context**: relevant files from scout-code step
- **base_url**: from qa.config.yaml (e.g., http://localhost:3001)
- **issue_id**: for naming the test

## Output

A complete, runnable Playwright test file.

## Selector Rules (MANDATORY — Accessibility-First)

Priority order (ALWAYS follow this):

1. `page.getByRole('button', { name: 'Submit' })` — **Most preferred**
2. `page.getByLabel('Email')` — Form fields
3. `page.getByPlaceholder('Search...')` — Inputs
4. `page.getByText('Welcome back')` — Static text
5. `page.getByTestId('submit-btn')` — **Last resort only**

**NEVER use CSS selectors** (`page.locator('.btn-primary')`) unless there is absolutely no accessible alternative.

## Flaky Memory Check (before generating selectors)

Before writing any selector, check `.agents/qa-scan/evidence/flaky-memory.json` for known-bad selectors.

If a selector has `failed_count >= 2`, use the recorded `alternative` instead.

Example: if flaky-memory.json contains:
```json
{"selector": "getByRole('button', {name: 'Save'})", "alternative": "getByText('Save changes')", "failed_count": 3}
```

Then use `page.getByText('Save changes')` instead of `page.getByRole('button', { name: 'Save' })`.

This prevents regenerating selectors that are known to fail.

## Test Structure Template

```typescript
import { test, expect } from '@playwright/test';

test.describe('{issue_id}: {feature_area}', () => {
  test('{scenario_name}', async ({ page }) => {
    // 1. Navigate to the page
    await page.goto('{route}');

    // 2. Wait for page to be ready (handle loading states)
    await page.waitForLoadState('networkidle');
    // OR: await page.getByRole('heading', { name: '...' }).waitFor();

    // 3. Perform user action
    await page.getByRole('button', { name: '...' }).click();

    // 4. Assert expected result
    await expect(page.getByText('...')).toBeVisible();
    // OR: await expect(page).toHaveURL('...');
  });
});
```

## Rules

1. **One test file per scenario** — focused, single-purpose
2. **Handle loading states** — always wait for content before asserting
3. **Use auto-waiting** — Playwright auto-waits by default, avoid explicit `waitForTimeout`
4. **Meaningful assertions** — assert what the user sees, not internal state
5. **Test name includes issue ID** — for traceability
6. **No hardcoded waits** — use `waitForLoadState`, `waitForResponse`, or element `.waitFor()`
7. **API response validation** — use `page.waitForResponse` when checking data-dependent content
