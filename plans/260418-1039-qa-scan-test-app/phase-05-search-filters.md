# Phase 5: Search & Filters

## Context Links
- [Phase 4](./phase-04-users-crud.md) - Basic filtering in users list
- Blocked by: Phase 4

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P2 | pending | 20m |

Enhanced search with real-time filtering and URL state persistence.

## Features

1. **Text Search**: Filter by name or email
2. **Role Filter**: Dropdown (All, Admin, User, Viewer)
3. **Status Filter**: Dropdown (All, Active, Inactive)
4. **URL State**: Filters persist in query params
5. **Clear Filters**: Reset button

## Design

```
┌─────────────────────────────────────────────────────┐
│ Search: [john_________]  Role: [Admin▼] Status: [▼]│
│                                        [Clear All]  │
├─────────────────────────────────────────────────────┤
│ Showing 2 of 10 users                               │
└─────────────────────────────────────────────────────┘
```

## Files to Modify

| File | Changes |
|------|---------|
| `test-app/views/users.ts` | Enhanced filter UI |
| `test-app/server.ts` | Filter logic (already partial) |

## Implementation Steps

1. **Enhance filter form in users.ts**
   - Add client-side form submission
   - Show active filter count
   - Clear all button

2. **Filter logic in server.ts**
   ```typescript
   let filtered = users;
   if (search) {
     filtered = filtered.filter(u => 
       u.name.toLowerCase().includes(search.toLowerCase()) ||
       u.email.toLowerCase().includes(search.toLowerCase())
     );
   }
   if (role && role !== 'all') {
     filtered = filtered.filter(u => u.role === role);
   }
   if (status && status !== 'all') {
     filtered = filtered.filter(u => u.status === status);
   }
   ```

3. **Results count**
   - Show "Showing X of Y users"
   - Empty state message when no results

## Query Params

```
/users?search=john&role=admin&status=active
```

## Todo List

- [ ] Add filter count badge
- [ ] Add "Clear All" button
- [ ] Show "Showing X of Y users"
- [ ] Empty state for no results
- [ ] Preserve filters on page navigation

## Success Criteria

- Search filters by name OR email
- Multiple filters combine (AND logic)
- URL reflects current filters
- Clear resets all filters
- Empty state shows helpful message

## Test Scenarios (for Phase 8)

1. **TC-SEARCH-001**: Search filters users by name
2. **TC-SEARCH-002**: Combined filters work correctly

## Next Phase

Phase 6: Profile Settings
