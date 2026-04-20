# Self-Heal Failed Test

You are fixing a Playwright test that failed due to selector issues.

## Input

- **Failed test code**: The Playwright test that failed
- **Error message**: Playwright error output (e.g., "locator.click: Error: strict mode violation")
- **DOM snapshot**: Output of `page.content()` at the point of failure
- **Issue context**: What the test was trying to verify

## Task

Fix the test by correcting selectors to match the actual DOM.

## Rules

1. **Parse the error** — identify which specific selector failed and why
2. **Match against DOM** — find the actual element in the DOM snapshot
3. **Use accessibility-first alternatives:**
   - `getByRole()` with exact name from DOM
   - `getByLabel()` for form fields
   - `getByText()` with actual visible text
   - `getByTestId()` as last resort
4. **Only fix selectors** — do NOT change test logic, assertions, or flow
5. **If element genuinely missing from DOM** → this is a real FAIL, not a selector issue. Report:
   ```
   GENUINE_FAIL: Element "{description}" not found in DOM.
   This is not a selector mismatch — the expected UI element does not exist.
   ```
6. **Check flaky-memory.json** — if this selector has failed before, use the recorded alternative

## Output

Return the corrected test code with comments explaining each fix:
```typescript
// FIXED: Changed from getByRole('button', {name: 'Save'}) 
//        to getByText('Save changes') — actual button text in DOM
```

## Flaky Memory Update

If you fixed a selector, output a JSON entry to append to flaky-memory.json:
```json
{
  "issue": "{issue_id}",
  "selector": "{original_selector}",
  "failed_count": 1,
  "alternative": "{fixed_selector}",
  "last_seen": "{date}"
}
```
