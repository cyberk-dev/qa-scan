# Phase 3: Dashboard

## Context Links
- [Phase 2](./phase-02-auth-session.md) - Auth required
- Blocked by: Phase 2

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P1 | pending | 20m |

Dashboard with stats cards showing user metrics. Entry point after login.

## Design

```
┌─────────────────────────────────────────────────────┐
│  Dashboard                        [Profile] [Logout]│
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │ Total    │ │ Active   │ │ Admins   │ │ Recent │ │
│  │ Users    │ │ Users    │ │          │ │ Signups│ │
│  │    10    │ │     8    │ │     2    │ │     3  │ │
│  └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│                                                     │
│  Quick Links: [Manage Users] [Settings]             │
└─────────────────────────────────────────────────────┘
```

## Files to Create/Modify

| File | Changes |
|------|---------|
| `test-app/views/dashboard.ts` | NEW - Stats cards view |
| `test-app/views/nav.ts` | NEW - Navigation component |
| `test-app/server.ts` | Add GET /dashboard route |

## Implementation Steps

1. **Create views/nav.ts**
   - Export `nav(currentPath, session)` function
   - Links: Dashboard, Users, Profile
   - Show current user email
   - Logout button

2. **Create views/dashboard.ts**
   - Export `dashboardPage(stats, session)` function
   - 4 stats cards in responsive grid
   - Quick action links

3. **Add route to server.ts**
   - `GET /dashboard` - fetch stats, render

## Stats Computed from Data

```typescript
const stats = {
  totalUsers: users.length,
  activeUsers: users.filter(u => u.status === 'active').length,
  adminCount: users.filter(u => u.role === 'admin').length,
  recentSignups: users.filter(u => isRecent(u.createdAt)).length,
};
```

## Routes (this phase)

| Method | Path | Auth | Handler |
|--------|------|------|---------|
| GET | /dashboard | Yes | Render dashboard |

## Todo List

- [ ] Create `views/nav.ts` navigation component
- [ ] Create `views/dashboard.ts` with stats cards
- [ ] Add GET /dashboard route
- [ ] Wire up stats from data.ts
- [ ] Test dashboard renders after login

## Success Criteria

- Dashboard shows 4 stats cards with real data
- Navigation links work
- Responsive on mobile
- Stats update when user data changes

## Accessibility

- Cards have proper headings
- Stats have aria-labels
- Color contrast meets WCAG AA

## Test Scenarios (for Phase 8)

1. **TC-DASH-001**: Dashboard displays correct user count
2. **TC-DASH-002**: Navigation links are functional

## Next Phase

Phase 4: Users CRUD - main feature
