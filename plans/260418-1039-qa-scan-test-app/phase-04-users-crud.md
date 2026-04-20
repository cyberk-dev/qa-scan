# Phase 4: Users CRUD

## Context Links
- [Phase 1](./phase-01-server-data-layer.md) - Data layer with CRUD functions
- [Phase 2](./phase-02-auth-session.md) - Auth middleware
- Blocked by: Phase 2

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P1 | pending | 40m |

Full CRUD operations for users: list, create, edit, delete. Core feature for E2E testing.

## Design

### Users List
```
┌─────────────────────────────────────────────────────┐
│  Users                               [+ Add User]   │
├─────────────────────────────────────────────────────┤
│  Search: [__________]  Role: [All▼]  Status: [All▼] │
├─────────────────────────────────────────────────────┤
│  Name          Email              Role    Status    │
│  ─────────────────────────────────────────────────  │
│  John Doe      john@test.com      admin   active  ⋮│
│  Jane Smith    jane@test.com      user    active  ⋮│
│  ...                                                │
└─────────────────────────────────────────────────────┘
```

### Add/Edit Form
```
┌─────────────────────────────────────────────────────┐
│  Add User / Edit User                               │
├─────────────────────────────────────────────────────┤
│  Name:   [__________________]                       │
│  Email:  [__________________]                       │
│  Role:   [Admin ▼]                                  │
│  Status: [Active ▼]                                 │
│                                                     │
│  [Cancel]                            [Save User]    │
└─────────────────────────────────────────────────────┘
```

## Files to Create/Modify

| File | Changes |
|------|---------|
| `test-app/views/users.ts` | NEW - List + form views |
| `test-app/server.ts` | Add CRUD routes |

## Routes (this phase)

| Method | Path | Auth | Handler |
|--------|------|------|---------|
| GET | /users | Yes | List users with filters |
| GET | /users/new | Yes | Add user form |
| POST | /users | Yes | Create user |
| GET | /users/:id/edit | Yes | Edit form |
| POST | /users/:id | Yes | Update user |
| POST | /users/:id/delete | Yes | Delete user |

## Implementation Steps

1. **Create views/users.ts**
   - `usersListPage(users, filters, session)` - table with actions
   - `userFormPage(user?, errors?, session)` - add/edit form
   - Include filter form (search, role, status)

2. **Add routes to server.ts**
   - GET /users - apply filters, render list
   - GET /users/new - empty form
   - POST /users - validate, create, redirect
   - GET /users/:id/edit - prefilled form
   - POST /users/:id - validate, update, redirect
   - POST /users/:id/delete - delete, redirect

3. **Validation**
   - Required: name, email
   - Email format check
   - Unique email check

## Data Flow

```
GET /users?search=john&role=admin
  ↓
Filter users from data.ts
  ↓
Render usersListPage(filteredUsers, filters, session)
```

```
POST /users { name, email, role, status }
  ↓
Validate inputs
  ↓
If errors → render form with errors
  ↓
If valid → createUser(data) → redirect /users with toast
```

## Todo List

- [ ] Create `views/users.ts` with list and form
- [ ] Add GET /users route with filtering
- [ ] Add GET /users/new route
- [ ] Add POST /users route with validation
- [ ] Add GET /users/:id/edit route
- [ ] Add POST /users/:id route
- [ ] Add POST /users/:id/delete route
- [ ] Add action menu (edit/delete) per row
- [ ] Test full CRUD flow

## Success Criteria

- Users list shows all users
- Filters work (search, role, status)
- Add user creates new record
- Edit user updates record
- Delete user removes record
- Validation errors display correctly

## Edge Cases

| Case | Expected |
|------|----------|
| Duplicate email | Show "Email already exists" |
| Delete self | Show "Cannot delete yourself" |
| Edit non-existent user | 404 page |
| Empty search results | Show "No users found" message |

## Test Scenarios (for Phase 8)

1. **TC-USER-001**: Create new user successfully
2. **TC-USER-002**: Edit existing user
3. **TC-USER-003**: Delete user with confirmation
4. **TC-USER-004**: Validation prevents invalid submission

## Next Phase

Phase 5: Search & Filters - enhance filtering
