---
title: "Bun CLI for qa-scan install/update/verify"
description: "Add CLI commands to install, update, and verify qa-scan from any project"
status: completed
priority: P2
effort: 2h
branch: main
tags: [qa-scan, cli, bun, dx]
created: 2026-04-20
completed: 2026-04-20
---

# Bun CLI for qa-scan

Enable `bunx qa-scan install|update|verify` from any workspace.

## Problem

**Current:** `bash .agents/qa-scan/scripts/install.sh` only
**Desired:** `bunx qa-scan update` to refresh agents/scripts without touching user config

## Design

```
.agents/qa-scan/
├── cli/
│   ├── index.ts      # Entry: parse args, route to command
│   ├── install.ts    # Full setup (deps + adapters + results folder)
│   ├── update.ts     # Sync agents/scripts/refs only, SKIP config
│   └── verify.ts     # Check installation status
├── package.json      # Add bin + publish config
└── .version          # Track installed version
```

## Commands

| Command | Action |
|---------|--------|
| `bunx qa-scan install` | Full setup |
| `bunx qa-scan update` | Sync agents/scripts/refs, SKIP config |
| `bunx qa-scan verify` | Check status |
| `bunx qa-scan --version` | Show version |

## Phases

| # | Phase | Effort | Files |
|---|-------|--------|-------|
| 1 | [CLI Structure](./phase-01-cli-structure.md) | 30m | cli/index.ts, package.json |
| 2 | [Install Command](./phase-02-install-command.md) | 30m | cli/install.ts |
| 3 | [Update Command](./phase-03-update-command.md) | 30m | cli/update.ts |
| 4 | [Verify Command](./phase-04-verify-command.md) | 20m | cli/verify.ts |
| 5 | [Test & Validate](./phase-05-test-validate.md) | 10m | manual test |

## Update Logic

**Sync (overwrite):**
- `.claude/agents/qa-*.md`
- `.gemini/agents/qa-*.md`
- `.claude/skills/qa-scan/SKILL.md`
- `.antigravity/qa-scan.md`
- `.gemini/commands/*.toml`
- `references/*.md`

**Skip (preserve user data):**
- `config/qa.config.yaml`
- `qa-results/`
- `auth-state-*.json`

## Version Tracking

```
# .agents/qa-scan/.version
3.0.0

# On update:
"Updating qa-scan: v2.0.0 → v3.0.0"
```

## Success Criteria

- [x] `bunx qa-scan install` works from fresh workspace
- [x] `bunx qa-scan update` syncs agents without touching config
- [x] `bunx qa-scan verify` shows status
- [x] Version displayed on update
