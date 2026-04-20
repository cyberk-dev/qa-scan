# Phase 2: Auth & Session

## Context Links
- [Phase 1](./phase-01-server-data-layer.md) - Server foundation
- Blocked by: Phase 1

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P1 | pending | 20m |

Mock authentication with session cookies. No real auth - just cookie-based session for E2E testing.

## Auth Flow

```
1. GET /login → render login form
2. POST /login → validate credentials → set session cookie → redirect /dashboard
3. GET /logout → clear cookie → redirect /login
4. Middleware: check session cookie on protected routes
```

## Mock Credentials

```typescript
const MOCK_USERS = {
  'admin@test.com': { password: 'admin123', role: 'admin' },
  'user@test.com': { password: 'user123', role: 'user' },
};
```

## Files to Modify/Create

| File | Changes |
|------|---------|
| `test-app/views/layout.ts` | NEW - HTML wrapper with Tailwind CDN |
| `test-app/views/login.ts` | NEW - Login form view |
| `test-app/server.ts` | Add auth routes, middleware |

## Implementation Steps

1. **Create views/layout.ts**
   - Export `layout(title, content, scripts?)` function
   - Include Tailwind CDN via `<script src="https://cdn.tailwindcss.com">`
   - Basic responsive wrapper

2. **Create views/login.ts**
   - Export `loginPage(error?)` function
   - Form with email/password fields
   - Error message display
   - Tailwind styling

3. **Add auth routes to server.ts**
   - `GET /login` - render login page
   - `POST /login` - validate, set cookie, redirect
   - `GET /logout` - clear cookie, redirect
   - Auth middleware for `/dashboard/*`, `/users/*`, `/profile/*`

## Routes (this phase)

| Method | Path | Auth | Handler |
|--------|------|------|---------|
| GET | /login | No | Render login form |
| POST | /login | No | Validate credentials |
| GET | /logout | No | Clear session |

## Session Cookie

```typescript
// Set on login
setCookie(c, 'session', JSON.stringify({ userId, email, role }), {
  path: '/',
  httpOnly: true,
  maxAge: 86400, // 24h
});

// Check in middleware
const session = getCookie(c, 'session');
if (!session) return c.redirect('/login');
```

## Todo List

- [ ] Create `test-app/views/` directory
- [ ] Create `views/layout.ts` with Tailwind CDN
- [ ] Create `views/login.ts` with form
- [ ] Add GET /login route
- [ ] Add POST /login with validation
- [ ] Add GET /logout route
- [ ] Add auth middleware for protected routes
- [ ] Test login flow manually

## Success Criteria

- Login page renders at `/login`
- Invalid credentials show error message
- Valid credentials set cookie and redirect to `/dashboard`
- Protected routes redirect to `/login` without session

## Edge Cases

| Case | Expected |
|------|----------|
| Empty credentials | Show "Email and password required" |
| Wrong password | Show "Invalid credentials" |
| Already logged in, visit /login | Redirect to /dashboard |

## Test Scenarios (for Phase 8)

1. **TC-LOGIN-001**: Valid login redirects to dashboard
2. **TC-LOGIN-002**: Invalid password shows error
3. **TC-LOGIN-003**: Logout clears session

## Next Phase

Phase 3: Dashboard - requires active session
