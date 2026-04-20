# Test App — QA Scan E2E Testing

Demo web app for dogfooding the QA Scan E2E testing pipeline.

## Quick Start

```bash
# Start test app on port 3001
npm run test-app
# or
bun run test-app/server.ts
```

Open http://localhost:3001

## Demo Accounts

| Email | Password | Role |
|-------|----------|------|
| alice@example.com | admin123 | Admin |
| bob@example.com | user123 | User |
| carol@example.com | viewer123 | Viewer |

## Features

- **Login** — Cookie-based session, error handling
- **Dashboard** — Stats cards, quick actions
- **Users CRUD** — List, create, edit, delete with confirmation modal
- **Search** — Filter by name/role, URL query params
- **Profile** — Settings form with toast notifications
- **Modals** — Native `<dialog>` element for confirm dialogs
- **Toasts** — Auto-dismiss notifications

## Test Cases (8 scenarios)

Mock issues in `mock-issues/` directory:

| ID | Test Case |
|----|-----------|
| TC-LOGIN-001 | Valid login redirects to dashboard |
| TC-LOGIN-002 | Invalid password shows error |
| TC-USER-001 | Create new user |
| TC-USER-002 | Edit existing user |
| TC-USER-003 | Delete with confirmation |
| TC-SEARCH-001 | Filter users by name |
| TC-PROFILE-001 | Update profile settings |
| TC-MODAL-001 | Cancel delete modal |

## Running E2E Tests

```bash
# 1. Start test app
npm run test-app &

# 2. Run QA Scan on a test case
/qa-scan TC-USER-001 --issue-file test-app/mock-issues/TC-USER-001.json

# 3. Check results
cat evidence/TC-USER-001/report.md
```

## Architecture

```
test-app/
├── server.ts       # Hono routes (port 3001)
├── data.ts         # In-memory mock data
├── views/
│   ├── layout.ts   # HTML wrapper + Tailwind CDN
│   ├── login.ts    # Login form
│   ├── dashboard.ts
│   ├── users.ts    # CRUD table + forms
│   └── profile.ts
└── mock-issues/    # 8 test case JSON files
```

## data-testid Selectors

All interactive elements have `data-testid` attributes for Playwright:

- `login-form`, `email-input`, `password-input`, `login-submit`
- `nav-dashboard`, `nav-users`, `nav-profile`, `logout-btn`
- `users-table`, `user-row-{id}`, `edit-{id}`, `delete-{id}`
- `create-user-btn`, `search-input`, `role-filter`, `search-btn`
- `delete-modal`, `confirm-delete`, `cancel-delete`
- `profile-form`, `save-profile-btn`
