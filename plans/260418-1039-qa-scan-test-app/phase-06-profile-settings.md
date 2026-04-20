# Phase 6: Profile Settings

## Context Links
- [Phase 2](./phase-02-auth-session.md) - Session for current user
- Blocked by: Phase 1 (can run parallel to Phase 3-5)

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P2 | pending | 15m |

User profile settings page. Update name, email, preferences.

## Design

```
┌─────────────────────────────────────────────────────┐
│  Profile Settings                                   │
├─────────────────────────────────────────────────────┤
│  Account Information                                │
│  ───────────────────                                │
│  Name:  [Current Name______]                        │
│  Email: [current@email.com_]                        │
│                                                     │
│  Preferences                                        │
│  ───────────                                        │
│  Theme:        [Light ▼]                            │
│  Notifications [✓] Email  [✓] Browser               │
│                                                     │
│  [Save Changes]                                     │
│                                                     │
│  ─────────────────────────────────────              │
│  Danger Zone                                        │
│  [Delete Account]                                   │
└─────────────────────────────────────────────────────┘
```

## Files to Create/Modify

| File | Changes |
|------|---------|
| `test-app/views/profile.ts` | NEW - Profile form view |
| `test-app/server.ts` | Add profile routes |
| `test-app/data.ts` | Add preferences to User type |

## Routes (this phase)

| Method | Path | Auth | Handler |
|--------|------|------|---------|
| GET | /profile | Yes | Render profile form |
| POST | /profile | Yes | Update profile |
| POST | /profile/delete | Yes | Delete account |

## Implementation Steps

1. **Extend User type in data.ts**
   ```typescript
   interface User {
     // ... existing
     preferences?: {
       theme: 'light' | 'dark';
       emailNotifications: boolean;
       browserNotifications: boolean;
     };
   }
   ```

2. **Create views/profile.ts**
   - `profilePage(user, errors?, success?, session)` function
   - Account info section
   - Preferences section
   - Danger zone (delete account)

3. **Add routes to server.ts**
   - GET /profile - load current user, render
   - POST /profile - validate, update, show success toast
   - POST /profile/delete - confirm, delete, logout

## Todo List

- [ ] Add preferences to User type
- [ ] Create `views/profile.ts`
- [ ] Add GET /profile route
- [ ] Add POST /profile route
- [ ] Add POST /profile/delete route
- [ ] Show success message after save

## Success Criteria

- Profile loads current user data
- Changes save correctly
- Success toast appears
- Delete account works (logs out)

## Test Scenarios (for Phase 8)

1. **TC-PROFILE-001**: Update profile successfully
2. **TC-PROFILE-002**: Delete account flow

## Next Phase

Phase 7: Modals & Toasts
