# Synthesize QA Report

You are synthesizing a final QA report from test execution and coverage verification results.

## Input

- **issue_id**: The issue being tested
- **issue_title**: Brief description
- **test_results**: Pass/fail status from Playwright execution (Step 4)
- **coverage_results**: Coverage report from coverage-verifier (Step 5) — includes coverage %, gaps list, independent verification checks
- **test_matrix**: Test matrix from flow-analyzer (Step 2b) — states[], actions[], coverage_summary
- **evidence_paths**: Paths to video, trace, screenshots

## Output

A structured markdown report saved to `evidence/{issue-id}/report.md`.

## Report Structure

```markdown
# QA Report: {issue_id}
**Date:** {YYYY-MM-DD}
**Issue:** {issue_title}
**Repo:** {repo_key}

## Generated Test Results

| Scenario | Status | Duration |
|----------|--------|----------|
| {scenario_name} | PASS/FAIL | {Xs} |

## Coverage Analysis

**Coverage:** {X}/{Y} states/actions tested = {Z}%

| State/Action | Source | Tested | Verified | Result |
|-------------|--------|--------|----------|--------|
| {name} | matrix/issue | ✓/✗ | ✓/✗/- | COVERED/GAP |

### Gaps (untested states)
{List uncovered states/actions from coverage-verifier}

### Independent Verification Checks
{Copy structured checks from coverage-verifier verbatim}

### Check: {state name}
**Command run:**
  {exact command}
**Output observed:**
  {terminal output}
**Expected vs Actual:** {comparison}
**Result:** COVERED/GAP

## Evidence
- Video: `evidence/{issue-id}/video.webm`
- Trace: `evidence/{issue-id}/trace.zip`
- Screenshots: `evidence/{issue-id}/screenshots/`

## Manual Testing Guide
{Only include if VERDICT is PARTIAL — list what could not be automated}

VERDICT: {PASS|FAIL|PARTIAL}
```

## Visual Verification (if vision enabled)

If AI Vision analysis was performed on screenshots, include results:

### Visual Check: {screenshot_name}
**Screenshot:** `evidence/{issue-id}/screenshots/{filename}`
**Expected:** {expected_behavior}
**AI Vision Assessment:**
  - Element visible: {PASS/FAIL} — {detail}
  - Data correctness: {PASS/FAIL} — {detail}
  - Layout integrity: {PASS/FAIL} — {detail}
  - Loading states: {PASS/FAIL} — {detail}
**Confidence:** {score}
**Issues found:** {list or "None"}

Vision results contribute to the overall VERDICT:
- Any vision check with confidence < 0.5 → contributes to FAIL
- Vision issues are informational if confidence > 0.7 and no functional failure

## Verdict Rules

- **VERDICT: PASS** — All generated tests pass AND coverage ≥ 80% with critical states verified. No ambiguity.
- **VERDICT: FAIL** — Any test fails OR coverage < 50% OR critical states (error, auth) unverified. Include:
  - Which check failed
  - Reproduction steps
  - Expected vs actual behavior
  - Severity assessment (critical/major/minor)
- **VERDICT: PARTIAL** — Environmental limitation ONLY:
  - Server couldn't start
  - Browser tool unavailable
  - Auth required but not configured
  - List what WAS verified and what WASN'T

**Important:** PARTIAL is NOT for "I'm unsure." If you can run the check, decide PASS or FAIL.

## Rules

1. **Preserve all evidence** — never summarize away command outputs
2. **VERDICT must be the LAST line** — parsed programmatically by caller
3. **Use exact VERDICT format** — `VERDICT: PASS` (no bold, no extra text on that line)
4. **Manual guide only for PARTIAL** — if PASS or FAIL, no manual guide needed
5. **Include reproduction steps for FAIL** — another developer must be able to reproduce
