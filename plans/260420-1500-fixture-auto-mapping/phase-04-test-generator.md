---
phase: 4
title: Test Generator Update
status: pending
effort: 0.5h
priority: P1
---

# Phase 4: Test Generator Update

Update qa-test-generator agent to read fixture_definitions and auto-inject imports.

## Changes to .claude/agents/qa-test-generator.md

### Add to Input section

```markdown
## Input

- test_scenarios: Scenarios from issue analyzer
- test_matrix: States/actions/branches from flow analyzer
- code_context: Relevant code snippets
- base_url: Test server URL
- issue_id: Issue ID for evidence folder
- project_context: Tech stack, test framework
- fixture_definitions: Required fixtures from test-roadmap.json   # NEW
- required_fixtures: List of fixture names for this flow          # NEW
```

### Add Fixture Injection Rules

```markdown
## Fixture Injection Rules

When `required_fixtures` is provided:

1. **Import fixtures** from fixture_definitions:
   ```typescript
   // Auto-generated based on fixture_definitions
   import { WalletFixture } from '.agents/qa-scan/fixtures/web3';
   import { AnvilClient } from '.agents/qa-scan/fixtures/web3';
   ```

2. **Use merged test** if multiple fixtures:
   ```typescript
   import { test, expect } from '.agents/qa-scan/fixtures/web3';
   // Provides: { page, wallet, anvil }
   ```

3. **Add snapshot isolation** for blockchain tests:
   ```typescript
   let snapshotId: `0x${string}`;
   
   test.beforeAll(async ({ anvil }) => {
     snapshotId = await anvil.snapshot();
   });
   
   test.afterAll(async ({ anvil }) => {
     if (snapshotId) await anvil.revert({ id: snapshotId });
   });
   ```
```

### Update Example Output

```markdown
## Example Output (with fixtures)

```typescript
import { test, expect } from '.agents/qa-scan/fixtures/web3';

let snapshotId: `0x${string}`;

test.beforeAll(async ({ anvil }) => {
  snapshotId = await anvil.snapshot();
});

test.afterAll(async ({ anvil }) => {
  if (snapshotId) await anvil.revert({ id: snapshotId });
});

test('wallet connect flow', async ({ page, wallet }) => {
  await page.goto('/');
  await wallet.connect('alice');
  await expect(page.getByTestId('wallet-address')).toContainText('0xf39');
});
```
```

## Todo

- [ ] Update qa-test-generator.md Input section
- [ ] Add Fixture Injection Rules section
- [ ] Update Example Output with fixture usage
- [ ] Sync to .gemini/agents/qa-test-generator.md
