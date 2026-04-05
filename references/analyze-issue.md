# Analyze Issue → Test Requirements

You are analyzing a QA issue to extract testable requirements.

## Input

You will receive:
- **Issue title**: Brief description of the change/fix
- **Issue description**: Detailed description (may include markdown, images, steps to reproduce)
- **Labels**: Issue labels/tags (e.g., "bug", "feature", "frontend")

## Issue Source Formats

### Linear Issues
- **Identifier:** `SKIN-101` or `https://linear.app/cyberk/issue/SKIN-101`
- **Data:** title, description (markdown), labels, assignee, branch name
- **Fetch:** Linear MCP `getIssue` or Linear API

### GitHub Issues
- **Identifier:** `#42`, `cyberk-dev/repo#42`, or `https://github.com/org/repo/issues/42`
- **Data:** title, body (markdown), labels, linked PRs, milestone
- **Fetch:** `gh issue view 42 --repo org/repo --json title,body,labels,milestone`

### Parsing Rules
- If description contains "Steps to Reproduce" → extract each step as a test scenario
- If description contains screenshots/images → note as visual reference (cannot test automatically)
- If linked PR exists → use PR diff to narrow feature_area
- Labels like "bug", "regression" → set priority to "high"
- Labels like "enhancement", "feature" → focus on happy-path testing

## Task

Extract structured test requirements from the issue.

## Output Format (JSON)

```json
{
  "feature_area": "Product Detail",
  "test_scenarios": [
    {
      "name": "Verify beneficial ingredients display correctly",
      "user_action": "Navigate to product detail page for product ID 123",
      "expected_result": "Beneficial ingredients list shows 5 items from KG service",
      "priority": "high"
    }
  ],
  "input_variables": {
    "productId": "123",
    "userId": "test-user-1"
  },
  "expected_behavior": "Product detail page shows correct ingredient analysis with beneficial/harmful categorization",
  "confidence": 0.85
}
```

## Rules

1. **Extract concrete user actions** — not vague requirements. "User clicks X and sees Y" not "Feature should work correctly"
2. **Each scenario = 1 testable user flow** — single action → single assertion
3. **Identify input variables** — what test data is needed (IDs, URLs, user credentials)
4. **Rate confidence 0-1:**
   - 0.9-1.0: Clear steps to reproduce, specific expected behavior
   - 0.5-0.9: General description, some ambiguity
   - <0.5: Vague, no clear test criteria → flag for human review
5. **Priority per scenario:** high (core flow), medium (edge case), low (cosmetic)
6. **If issue is a bug fix:** extract BOTH the bug reproduction AND the expected fix behavior
