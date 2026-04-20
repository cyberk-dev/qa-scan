# Status Protocol

All qa-scan sub-agents MUST end their response with this status block.

## Status Types

| Status | Meaning |
|--------|---------|
| `DONE` | Task completed successfully |
| `DONE_WITH_CONCERNS` | Completed but flagged issues |
| `BLOCKED` | Cannot proceed, needs intervention |
| `NEEDS_CONTEXT` | Missing info, needs user input |

## Response Format (MANDATORY)

Output data in body, then end with:

```markdown
---
**Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
**Summary:** [1-2 sentence summary]
**Concerns/Blockers:** [if applicable]
---
```

## Concern Classification

When returning `DONE_WITH_CONCERNS`, tag concern type:

| Type | Examples | Orchestrator Action |
|------|----------|---------------------|
| `[observational]` | File growth, tech debt, style | Log, proceed |
| `[correctness]` | Logic errors, missing coverage, wrong data | Pause, review |

Format: `**Concerns/Blockers:** [observational] Low confidence in...`

## Status Thresholds by Agent

| Agent | Condition | Status |
|-------|-----------|--------|
| qa-issue-analyzer | confidence < 0.5 | NEEDS_CONTEXT |
| qa-issue-analyzer | confidence 0.5-0.7 | DONE_WITH_CONCERNS |
| qa-issue-analyzer | confidence >= 0.7 | DONE |
| qa-code-scout | 0 files found | DONE_WITH_CONCERNS |
| qa-code-scout | files found | DONE |
| qa-flow-analyzer | no testable states | DONE_WITH_CONCERNS |
| qa-test-generator | cannot generate | BLOCKED |
| qa-test-runner | test fail 3x | BLOCKED |
| qa-test-runner | test pass | DONE |
| qa-coverage-verifier | coverage < 50% | DONE_WITH_CONCERNS |
| qa-coverage-verifier | coverage >= 50% | DONE |
| qa-report-synthesizer | report generated | DONE |

## Parse Failure Handling

If orchestrator cannot parse status block from agent response:
- Treat as `BLOCKED` with message: "Agent output malformed or truncated"
- Escalate to user immediately
- Do NOT retry - parsing failure indicates crash

## Example Responses

### DONE
```markdown
Found 5 relevant files for login feature.

**Files:**
- src/app/api/auth/login/route.ts
- src/lib/auth-service.ts
- src/components/login-form.tsx
- src/hooks/use-auth.ts
- tests/auth.test.ts

---
**Status:** DONE
**Summary:** Located 5 files related to login feature authentication flow.
**Concerns/Blockers:** None
---
```

### DONE_WITH_CONCERNS
```markdown
Found 2 files but confidence is moderate.

**Files:**
- src/app/api/auth/login/route.ts
- src/lib/auth.ts

---
**Status:** DONE_WITH_CONCERNS
**Summary:** Found 2 files for login feature with moderate confidence.
**Concerns/Blockers:** [observational] Low file count - may be missing helper modules.
---
```

### NEEDS_CONTEXT
```markdown
Issue description too vague to extract test scenarios.

**Issue:** "Fix the bug"
**Missing:** Feature area, expected behavior, reproduction steps

---
**Status:** NEEDS_CONTEXT
**Summary:** Cannot extract test requirements from vague issue description.
**Concerns/Blockers:** Need clarification on: What feature? What bug? Expected behavior?
---
```

### BLOCKED
```markdown
Test server not responding after 3 attempts.

**Attempts:**
1. curl localhost:3000 - timeout
2. curl localhost:3000 - connection refused
3. curl localhost:3000 - connection refused

---
**Status:** BLOCKED
**Summary:** Cannot run tests - dev server unreachable.
**Concerns/Blockers:** Server at localhost:3000 not responding. User must start server manually.
---
```
