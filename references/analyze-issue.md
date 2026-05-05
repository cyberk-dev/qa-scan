# Analyze Issue → Test Requirements

You are analyzing a QA issue to extract testable requirements.

## Input

You will receive:
- **Issue title**: Brief description of the change/fix
- **Issue description**: Detailed description (may include markdown, images, steps to reproduce)
- **Labels**: Issue labels/tags (e.g., "bug", "feature", "frontend")
- **Comments** (CRITICAL — fetch always): All comments on the issue. QA intent is frequently posted here AFTER ticket creation: "Test edge case X", "Also verify Y on staging", "Reproduces only when Z". Missing comments = missing test scenarios.

## Issue Source Formats

### Linear Issues
- **Identifier:** `SKIN-101` or `https://linear.app/cyberk/issue/SKIN-101`
- **Data:** title, description (markdown), labels, assignee, branch name, **comments**
- **Fetch:**
  1. Linear MCP `linear.get_issue({id: "SKIN-101"})` → issue body + metadata
  2. Linear MCP `linear.list_comments({issueId})` → ALL comments (DON'T skip — most QA intent lives here)

### GitHub Issues
- **Identifier:** `#42`, `cyberk-dev/repo#42`, or `https://github.com/org/repo/issues/42`
- **Data:** title, body (markdown), labels, linked PRs, milestone, **comments**
- **Fetch:** `gh issue view 42 --repo org/repo --json title,body,labels,milestone,comments`

### Parsing Rules
- If description contains "Steps to Reproduce" → extract each step as a test scenario
- If description contains screenshots/images → note as visual reference (cannot test automatically)
- If linked PR exists → use PR diff to narrow feature_area
- Labels like "bug", "regression" → set priority to "high"
- Labels like "enhancement", "feature" → focus on happy-path testing

## Comment Intent Extraction (MANDATORY)

After fetching all comments, scan each for QA-relevant intent. Look for:

### Trigger keywords (case-insensitive)
- `test:`, `verify:`, `qa:`, `scenario:`, `check:`, `repro:`
- `edge case`, `regression`, `also test`, `make sure`, `please verify`
- `acceptance`, `ac:`, `criteria`
- Imperative phrases: "Test that...", "Verify that...", "Make sure..."

### What to extract
For each matching comment line, capture:
- `author`: Comment author name (from MCP response)
- `comment_id`: Linear/GitHub comment id (for traceability)
- `scenario`: The extracted test intent text (1-2 sentences)
- `confidence`: How clearly testable this is (0-1)

### Skip
- Pure status updates ("Started working on this", "Done")
- Praise/discussion ("Looks good", "Thanks")
- Internal coordination ("@user can you check")

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
      "priority": "high",
      "source": "description"
    },
    {
      "name": "Test edge case: empty ingredient list shows fallback message",
      "user_action": "Navigate to product 999 (no ingredients)",
      "expected_result": "Empty state message visible, no JS error",
      "priority": "medium",
      "source": "comment:abc123"
    }
  ],
  "comments_findings": [
    {
      "author": "Hung Nguyen",
      "comment_id": "abc123",
      "scenario": "Also test that empty ingredient list shows fallback message — found regression on staging.",
      "confidence": 0.9
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

**Schema additions:**
- `test_scenarios[].source`: `"description" | "comment:{id}" | "label" | "title"` — traces where each scenario came from. Reviewers see which comments contributed.
- `comments_findings[]`: All raw QA-intent extractions from comments, for audit. Each finding may produce 0..N entries in `test_scenarios[]`.

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
