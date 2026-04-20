# MCP Diagnostics

Systematic debugging for MCP failures. Follow phases in order - NO WORKAROUNDS WITHOUT ROOT CAUSE FIRST.

## Core Principle

```
NO WORKAROUNDS WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If haven't completed Phase 1, cannot offer "paste manually" or "skip step" options.

## Phase 1: Root Cause Investigation

Run ALL checks before proposing any fix:

### Linear MCP

| Check | Command | Expected | Diagnosis |
|-------|---------|----------|-----------|
| MCP responding | `mcp__linear__list_teams()` | Returns teams | MCP working |
| API key present | `echo $LINEAR_API_KEY \| wc -c` | > 10 chars | Key set |
| Network to Linear | `curl -s -o /dev/null -w "%{http_code}" https://api.linear.app` | 200 or 401 | Network OK |
| MCP process | `pgrep -f "linear"` | PID found | Process running |

### GitNexus MCP

| Check | Command | Expected | Diagnosis |
|-------|---------|----------|-----------|
| MCP responding | `mcp__gitnexus__list_repos()` | Returns repos | MCP working |
| Index exists | `ls .gitnexus/` | Files present | Index built |
| Index fresh | Check `.gitnexus/meta.json` timestamp | < 24h old | Index current |

### Playwright

| Check | Command | Expected | Diagnosis |
|-------|---------|----------|-----------|
| Installed | `npx playwright --version` | Version string | Playwright OK |
| Browsers | `ls ~/Library/Caches/ms-playwright/` | chromium-* dir | Browsers OK |
| Can run | `npx playwright test --list` | Lists tests | Runner OK |

## Phase 2: Pattern Analysis

After identifying failing check:

1. **What worked before?** - Check evidence/logs for last successful run
2. **What changed?** - Recent commits, env changes, system updates
3. **Similar issues?** - Search hotspot-memory.json for same error pattern

## Phase 3: Auto-Fix Attempts

ONE fix at a time. Verify after each.

### Linear MCP Fixes

| Root Cause | Auto-Fix | Verify |
|------------|----------|--------|
| MCP not responding | Restart: `claude mcp restart linear` | Re-run list_teams |
| API key missing | Prompt user to set | Check env again |
| Network blocked | Cannot auto-fix | Escalate with diagnosis |

### GitNexus Fixes

| Root Cause | Auto-Fix | Verify |
|------------|----------|--------|
| Index missing | Run `npx gitnexus analyze` | Check .gitnexus/ |
| Index stale | Run `npx gitnexus analyze` | Check meta.json |
| MCP not responding | Check MCP config | Re-run list_repos |

### Playwright Fixes

| Root Cause | Auto-Fix | Verify |
|------------|----------|--------|
| Not installed | `bun install && npx playwright install chromium` | Check version |
| Browsers missing | `npx playwright install chromium` | Check cache dir |
| Permission error | Cannot auto-fix (sandbox) | Escalate with diagnosis |

## Phase 4: Escalation with Context

After 3 auto-fix attempts OR unfixable issue:

```markdown
## MCP Diagnostic Report

**Tool:** Linear MCP
**Status:** FAILED

### Root Cause Investigation
- MCP responding: ❌ No response
- API key present: ✓ Set (40 chars)
- Network to Linear: ✓ 200 OK
- MCP process: ❌ Not found

### Diagnosis
Linear MCP process not running. API key and network OK.

### Auto-Fix Attempts
1. `claude mcp restart linear` → Failed: command not found
2. Manual restart prompt → User skipped

### Recommended Action
Start Linear MCP manually:
```bash
claude mcp add linear
```

### Options
[1] I'll fix it manually (with diagnosis above)
[2] Skip Linear, paste issue details manually
[3] Abort scan
```

## Red Flags

STOP if thinking:
- "Just skip and paste manually" → NO, investigate first
- "It's probably the API key" → Verify, don't guess
- "Quick restart should fix it" → ONE fix, then verify
- "Let user figure it out" → Provide diagnosis

## Integration with Orchestrator

Orchestrator calls diagnostics before offering workarounds:

```python
def handle_preflight_fail(tool_name, error):
    # Phase 1: Investigate
    diagnosis = run_diagnostics(tool_name)
    
    # Phase 2: Pattern check
    similar = check_hotspot_memory(error)
    
    # Phase 3: Auto-fix (max 3 attempts)
    for attempt in range(3):
        fix = get_auto_fix(diagnosis.root_cause)
        if fix:
            result = apply_fix(fix)
            if verify_fix(tool_name):
                return SUCCESS
    
    # Phase 4: Escalate with context
    return escalate_with_diagnosis(diagnosis)
```
