# GitNexus Flow Discovery

Use GitNexus MCP tools to find execution flows for test scenarios.

## Available Tools

| Tool | Purpose |
|------|---------|
| `mcp__gitnexus__query` | Semantic code search |
| `mcp__gitnexus__route_map` | API route → handler mapping |
| `mcp__gitnexus__impact` | Trace call chain from function |
| `mcp__gitnexus__context` | 360° view of a symbol |
| `mcp__gitnexus__api_impact` | API-specific impact analysis |

## Flow Discovery Process

### 1. Check GitNexus Availability

```
mcp__gitnexus__list_repos()
```

If error or repo not indexed → fallback to pattern-based scout.

### 2. Query Semantic Match

For each test scenario:
```
mcp__gitnexus__query({query: "login handler redirect"})
```

Returns relevant files/functions ranked by relevance.

### 3. Get Route Mapping (API tests)

```
mcp__gitnexus__route_map()
```

Maps `POST /api/auth/login` → `src/app/api/auth/login/route.ts`

### 4. Trace Execution Flow

```
mcp__gitnexus__impact({target: "loginHandler", direction: "downstream"})
```

Returns call chain: `loginHandler → validateCredentials → createSession → redirect`

### 5. Compile Coverage Targets

From the flow trace, extract:
- **Functions**: All functions in call chain
- **Branches**: Conditional paths (success/failure/edge)
- **Exit points**: Final outcomes (redirect, error, response)

## Output Schema

```json
{
  "files": ["src/app/api/auth/login/route.ts", "src/lib/auth-service.ts"],
  "flows": [
    {
      "scenario": "Valid login redirects",
      "entry": "POST /api/auth/login",
      "chain": ["loginHandler", "validateCredentials", "createSession", "redirect"],
      "exit": "redirect to /dashboard"
    }
  ],
  "coverage_targets": {
    "functions": ["loginHandler", "validateCredentials", "createSession"],
    "branches": ["valid credentials", "invalid credentials", "session exists"],
    "edge_cases": ["missing fields", "expired token", "rate limited"]
  }
}
```

## Fallback Strategy

| Condition | Action |
|-----------|--------|
| Repo not indexed | Use pattern-based Glob/Grep |
| Query returns empty | Widen search, then pattern fallback |
| MCP connection fails | DONE_WITH_CONCERNS, proceed with patterns |

## Integration with qa-code-scout

After pattern-based file search:

1. Check GitNexus available
2. For each test scenario → semantic query
3. For API routes → get route mapping
4. For key functions → trace execution flow
5. Merge results with pattern findings
6. Output enhanced coverage targets

## Example: Login Flow Trace

Input: "TC-LOGIN-001: Valid login redirects to dashboard"

GitNexus trace:
```
POST /api/auth/login
  └── loginHandler (route.ts:15)
        ├── validateCredentials (auth-service.ts:42)
        │     └── bcrypt.compare (external)
        ├── createSession (session-utils.ts:23)
        │     └── signJWT (jwt-utils.ts:10)
        └── NextResponse.redirect (framework)
```

Coverage targets extracted:
- `loginHandler`: entry point (test HTTP 200, 401, 400)
- `validateCredentials`: success + failure branches
- `createSession`: token generation
- Edge cases: invalid credentials, expired session, missing fields

## Status Handling

| Condition | Status |
|-----------|--------|
| GitNexus + patterns found files | DONE |
| GitNexus unavailable, patterns work | DONE_WITH_CONCERNS [observational] |
| GitNexus works, patterns fail | DONE |
| Both fail | BLOCKED |

Follow status protocol: `references/status-protocol.md`
