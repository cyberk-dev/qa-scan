# Phase 1: Server & Data Layer

## Context Links
- [Existing test-app/server.ts](/Users/tunb/Documents/skin-agent-workspace/qa-scan-repo/test-app/server.ts) - Current minimal server
- [playwright.config.ts](/Users/tunb/Documents/skin-agent-workspace/qa-scan-repo/scripts/playwright.config.ts) - baseURL: localhost:3001

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P1 | pending | 30m |

Set up Hono server with in-memory data store. Foundation for all subsequent phases.

## Data Model

```typescript
// Users
interface User {
  id: number;
  name: string;
  email: string;
  role: 'admin' | 'user' | 'viewer';
  status: 'active' | 'inactive';
  createdAt: string;
}

// Stats (computed)
interface Stats {
  totalUsers: number;
  activeUsers: number;
  adminCount: number;
  recentSignups: number;
}

// Session
interface Session {
  userId: number;
  username: string;
  role: string;
}
```

## Seed Data

10 mock users with varied roles/statuses for testing filters and pagination.

## Files to Create

| File | Purpose |
|------|---------|
| `test-app/data.ts` | In-memory store: users[], sessions Map, CRUD functions |
| `test-app/server.ts` | Replace existing - Hono app with routes |

## Implementation Steps

1. **Create data.ts**
   - Define User interface
   - Seed 10 users with varied data
   - Export CRUD functions: getUsers, getUser, createUser, updateUser, deleteUser
   - Export sessions Map for auth
   - Export getStats function

2. **Create server.ts**
   - Import Hono
   - Import data functions
   - Set up cookie middleware for sessions
   - Define routes:
     - `GET /` - redirect to /login or /dashboard
     - `GET /health` - healthcheck for Playwright
   - Start server on port 3001

## Routes Overview (this phase)

| Method | Path | Handler |
|--------|------|---------|
| GET | / | Redirect based on session |
| GET | /health | `{ status: 'ok' }` |

## Todo List

- [ ] Create `test-app/data.ts` with User type and seed data
- [ ] Implement CRUD functions in data.ts
- [ ] Create `test-app/server.ts` with Hono
- [ ] Add session cookie handling
- [ ] Add `/health` endpoint
- [ ] Add npm script `test-app` in package.json

## Success Criteria

- `bun test-app/server.ts` starts without errors
- `curl localhost:3001/health` returns `{"status":"ok"}`
- data.ts exports all CRUD functions

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hono API changes | Low | Low | Use stable v4.x patterns |
| Cookie parsing | Medium | Medium | Use Hono's built-in cookie helper |

## Rollback

Delete new files, restore original server.ts from git.

## Next Phase

Phase 2: Auth & Session - uses sessions Map from data.ts
