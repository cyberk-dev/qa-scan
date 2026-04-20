# VERDICT Rules (Shared)

End with exactly one of these lines (parsed programmatically by orchestrator and report-synthesizer):

```
VERDICT: PASS
```
All tests pass AND coverage ≥ 80% with critical states (error, auth) verified. No ambiguity.

```
VERDICT: FAIL
```
Any test fails OR coverage < 50% OR critical state unverified. Include: which check failed, exact error, reproduction steps, severity (critical/major/minor).

```
VERDICT: PARTIAL
```
Environmental limitation ONLY — server down, browser tool unavailable, auth not configured. List what WAS verified and what WASN'T. PARTIAL is NOT for "I'm unsure." If you can run the check, decide PASS or FAIL.

## Format

Use literal string `VERDICT: ` followed by exactly one of `PASS`, `FAIL`, `PARTIAL`.
- No markdown bold
- No punctuation after the word
- Must be the LAST line of your output
- Parsed by regex: `/^VERDICT: (PASS|FAIL|PARTIAL)$/m`
