# Test App — QA Scan E2E Testing

Dummy app for testing the QA Scan pipeline end-to-end.

## Quick Test

```bash
# 1. Start test app
bun test-app/server.ts &

# 2. Copy test config
cp test-app/qa.config.test.yaml config/qa.config.yaml

# 3. Run QA Scan with mock issue
# In Claude Code:
#   /qa-scan TEST-001 --repo test-app
#   (paste test-app/mock-issue.json content when asked for issue details)

# 4. Check results
cat evidence/TEST-001/report.md
```

## What the test app has

- **Page:** Product detail with ingredients list, buttons, status messages
- **API:** `/api/products/123` (product data), `/api/products/123/analyze` (AI analysis)
- **Accessibility:** Proper roles, labels, aria attributes (testable with getByRole)
- **Async behavior:** "Analyze" button has 1s loading state

## Mock Issue

`test-app/mock-issue.json` — simulates a Linear issue about "ingredient display bug".
