# Phase 8: Linear Issues

## Context Links
- All phases - extracting test scenarios
- Independent - can be done anytime

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P2 | pending | 10m |

Create 8 Linear issues for E2E test cases. These issues will be used to test the qa-scan pipeline itself.

## Issues to Create

### Issue 1: TC-LOGIN-001
**Title:** Valid login redirects to dashboard  
**Description:**
```
As a user, when I enter valid credentials on the login page,
I should be redirected to the dashboard.

Test Steps:
1. Navigate to /login
2. Enter email: admin@test.com
3. Enter password: admin123
4. Click "Sign In"
5. Verify redirected to /dashboard
6. Verify dashboard displays username

Expected: User sees dashboard with their email in nav
```

### Issue 2: TC-LOGIN-002
**Title:** Invalid password shows error message  
**Description:**
```
As a user, when I enter wrong password,
I should see an error message.

Test Steps:
1. Navigate to /login
2. Enter email: admin@test.com
3. Enter password: wrongpassword
4. Click "Sign In"
5. Verify error message displays
6. Verify still on login page

Expected: Error "Invalid credentials" shown
```

### Issue 3: TC-USER-001
**Title:** Create new user successfully  
**Description:**
```
As an admin, I can create a new user.

Precondition: Logged in as admin

Test Steps:
1. Navigate to /users
2. Click "Add User"
3. Fill form: name="Test User", email="test@new.com", role="user"
4. Click "Save User"
5. Verify redirected to /users
6. Verify new user appears in list

Expected: User created and visible in list
```

### Issue 4: TC-USER-002
**Title:** Edit existing user  
**Description:**
```
As an admin, I can edit an existing user's details.

Precondition: Logged in as admin, users exist

Test Steps:
1. Navigate to /users
2. Click edit on first user
3. Change name to "Updated Name"
4. Click "Save User"
5. Verify redirected to /users
6. Verify name changed in list

Expected: User name updated in list
```

### Issue 5: TC-USER-003
**Title:** Delete user with confirmation  
**Description:**
```
As an admin, I can delete a user after confirming.

Precondition: Logged in as admin, multiple users exist

Test Steps:
1. Navigate to /users
2. Click delete on a user
3. Verify confirmation modal appears
4. Click "Confirm" in modal
5. Verify user removed from list
6. Verify success toast appears

Expected: User deleted, toast confirms action
```

### Issue 6: TC-SEARCH-001
**Title:** Search filters users by name  
**Description:**
```
As a user, I can search for users by name.

Precondition: Logged in, users with different names exist

Test Steps:
1. Navigate to /users
2. Enter "John" in search field
3. Verify list filters to show only matching users
4. Verify result count updates

Expected: Only users with "John" in name shown
```

### Issue 7: TC-PROFILE-001
**Title:** Update profile successfully  
**Description:**
```
As a user, I can update my profile settings.

Precondition: Logged in

Test Steps:
1. Navigate to /profile
2. Change name to "New Name"
3. Toggle a preference
4. Click "Save Changes"
5. Verify success message
6. Refresh page
7. Verify changes persisted

Expected: Profile updated, success toast shown
```

### Issue 8: TC-MODAL-001
**Title:** Confirm delete modal appears and can be cancelled  
**Description:**
```
As a user, when I click delete, a confirmation modal appears.
I can cancel without deleting.

Precondition: Logged in as admin, users exist

Test Steps:
1. Navigate to /users
2. Click delete on a user
3. Verify modal appears with user name
4. Click "Cancel"
5. Verify modal closes
6. Verify user still in list

Expected: Modal cancellable, no deletion occurs
```

## Linear Project

Create issues under project key: `TEST` (or configured key in qa.config.yaml)

## Label

Add label: `qa-candidate` to all issues

## Todo List

- [ ] Create issue TC-LOGIN-001
- [ ] Create issue TC-LOGIN-002
- [ ] Create issue TC-USER-001
- [ ] Create issue TC-USER-002
- [ ] Create issue TC-USER-003
- [ ] Create issue TC-SEARCH-001
- [ ] Create issue TC-PROFILE-001
- [ ] Create issue TC-MODAL-001
- [ ] Add `qa-candidate` label to all

## CLI Commands

```bash
# Example Linear CLI (if available)
linear issue create \
  --title "Valid login redirects to dashboard" \
  --description "..." \
  --label qa-candidate \
  --project TEST
```

Or use Linear web UI / API.

## Alternative: Mock Issues

If Linear not available, create `test-app/mock-issues/` folder with JSON files:

```
test-app/mock-issues/
├── TC-LOGIN-001.json
├── TC-LOGIN-002.json
├── TC-USER-001.json
...
```

## Success Criteria

- 8 issues created in Linear (or mock files)
- Each issue has clear test steps
- Issues labeled for qa-scan pickup
