---
title: "QA Scan Test Web App"
description: "Demo web app to dogfood qa-scan E2E testing pipeline with auth, CRUD, modals"
status: in_progress
priority: P1
effort: 2.5h
branch: main
tags: [test-app, hono, e2e, qa-scan]
created: 2026-04-18
---

# QA Scan Test Web App

Demo app for dogfooding the qa-scan E2E testing pipeline.

## Phases

| # | Phase | Status | Effort | Files |
|---|-------|--------|--------|-------|
| 1 | [Server & Data Layer](./phase-01-server-data-layer.md) | ✅ done | 30m | server.ts, data.ts |
| 2 | [Auth & Session](./phase-02-auth-session.md) | ✅ done | 20m | views/login.ts, middleware |
| 3 | [Dashboard](./phase-03-dashboard.md) | ✅ done | 20m | views/dashboard.ts |
| 4 | [Users CRUD](./phase-04-users-crud.md) | ✅ done | 40m | views/users.ts, routes |
| 5 | [Search & Filters](./phase-05-search-filters.md) | ✅ done | 20m | search logic |
| 6 | [Profile Settings](./phase-06-profile-settings.md) | ✅ done | 15m | views/profile.ts |
| 7 | [Modals & Toasts](./phase-07-modals-toasts.md) | ✅ done | 15m | components |
| 8 | [Linear Issues](./phase-08-linear-issues.md) | ✅ done | 10m | 8 mock issues |

## Key Dependencies

```
Phase 1 ─┬─> Phase 2 ─┬─> Phase 3
         │            └─> Phase 4 ─┬─> Phase 5
         │                         └─> Phase 7
         └─> Phase 6
Phase 8: independent (documentation)
```

## Architecture

```
test-app/
├── server.ts           # Hono app entry, all routes
├── data.ts             # In-memory mock data store
├── views/
│   ├── layout.ts       # HTML wrapper with Tailwind CDN
│   ├── login.ts        # Login form
│   ├── dashboard.ts    # Stats cards
│   ├── users.ts        # CRUD table + forms
│   └── profile.ts      # Settings form
└── package.json        # start script
```

## Constraints

- Port: 3001 (matches playwright.config.ts baseURL)
- No build step: Tailwind CDN only
- Single server.ts file with modular view functions
- Keep under 200 lines per file

## Success Criteria

- [ ] `npm run test-app` starts server on :3001
- [ ] Login → Dashboard → Users CRUD flow works
- [ ] 8 Linear issues created with test scenarios
- [ ] All routes accessible for Playwright tests
