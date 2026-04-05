# QA Report: {issue_id}
**Date:** {date}
**Issue:** {issue_title}
**Repo:** {repo_key}
**Branch:** {branch}

## Generated Test Results

| Scenario | Status | Duration |
|----------|--------|----------|

## Adversarial Verification

### Check: [description of what was verified]
**Command run:**
  [exact command executed]
**Output observed:**
  [actual terminal output — copy-paste, not paraphrased]
**Expected vs Actual:** [comparison]
**Result:** PASS/FAIL

### Check: [adversarial probe description]
**Command run:**
  [exact command]
**Output observed:**
  [output]
**Result:** PASS/FAIL

## Evidence
- Video: `evidence/{issue-id}/video.webm`
- Trace: `evidence/{issue-id}/trace.zip`
- Screenshots: `evidence/{issue-id}/screenshots/`

## Manual Testing Guide
_Only included when VERDICT is PARTIAL_

VERDICT: PASS
