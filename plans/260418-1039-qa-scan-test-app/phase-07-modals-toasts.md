# Phase 7: Modals & Toasts

## Context Links
- [Phase 4](./phase-04-users-crud.md) - Delete confirmation needed
- [Phase 6](./phase-06-profile-settings.md) - Success messages needed
- Blocked by: Phase 4

## Overview
| Priority | Status | Effort |
|----------|--------|--------|
| P2 | pending | 15m |

Reusable UI components: confirmation modals and toast notifications.

## Components

### Confirmation Modal
```
┌─────────────────────────────────────┐
│  Delete User?                    ✕ │
├─────────────────────────────────────┤
│                                     │
│  Are you sure you want to delete    │
│  "John Doe"? This cannot be undone. │
│                                     │
│         [Cancel]  [Delete]          │
└─────────────────────────────────────┘
```

### Toast Notification
```
┌──────────────────────────────────┐
│ ✓ User created successfully   ✕ │
└──────────────────────────────────┘
```

## Files to Create/Modify

| File | Changes |
|------|---------|
| `test-app/views/components.ts` | NEW - Modal and toast markup |
| `test-app/views/layout.ts` | Add toast container, modal styles |

## Implementation (Vanilla JS)

### Modal
```html
<dialog id="confirm-modal" class="modal">
  <h3 id="modal-title">Confirm</h3>
  <p id="modal-message">Are you sure?</p>
  <form method="dialog">
    <button value="cancel">Cancel</button>
    <button value="confirm" class="danger">Confirm</button>
  </form>
</dialog>

<script>
function confirmDelete(userId, userName) {
  const dialog = document.getElementById('confirm-modal');
  document.getElementById('modal-title').textContent = 'Delete User?';
  document.getElementById('modal-message').textContent = 
    `Are you sure you want to delete "${userName}"?`;
  dialog.showModal();
  dialog.onclose = () => {
    if (dialog.returnValue === 'confirm') {
      document.getElementById(`delete-form-${userId}`).submit();
    }
  };
}
</script>
```

### Toast
```html
<div id="toast-container" class="fixed top-4 right-4 z-50">
  <!-- Toasts inserted here -->
</div>

<script>
function showToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `${message} <button onclick="this.parentElement.remove()">✕</button>`;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 5000);
}

// Show toast from URL param
const params = new URLSearchParams(location.search);
if (params.get('toast')) {
  showToast(params.get('toast'), params.get('type') || 'success');
  history.replaceState({}, '', location.pathname);
}
</script>
```

## Integration Points

| Action | Modal/Toast |
|--------|-------------|
| Delete user | Confirmation modal |
| User created | Success toast |
| User updated | Success toast |
| User deleted | Success toast |
| Profile saved | Success toast |
| Login failed | Error toast |

## Todo List

- [ ] Create `views/components.ts` with modal/toast HTML
- [ ] Add modal styles to layout
- [ ] Add toast container to layout
- [ ] Wire delete buttons to confirmation modal
- [ ] Add toast params to redirects
- [ ] Test modal dismiss (cancel, confirm, escape, backdrop)

## Success Criteria

- Delete shows confirmation modal
- Cancel dismisses without action
- Confirm submits delete form
- Toast appears and auto-dismisses
- Toast can be manually dismissed
- Escape key closes modal

## Accessibility

- Modal traps focus
- Modal has aria-labelledby
- Toast has role="alert"
- Close buttons have aria-label

## Test Scenarios (for Phase 8)

1. **TC-MODAL-001**: Confirm delete modal appears and works
2. **TC-TOAST-001**: Success toast appears after action

## Next Phase

Phase 8: Linear Issues - document all test scenarios
