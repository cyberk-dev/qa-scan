# QA Config Schema Reference

Configuration file: `.agents/qa-scan/config/qa.config.yaml`

## Top-Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `defaults` | object | Yes | Default settings for all repos |
| `repos` | object | Yes | Map of repo-key → repo config |

## defaults

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `video` | bool | true | Record video during test |
| `trace` | bool | true | Capture Playwright trace |
| `screenshots` | bool | true | Take screenshots |
| `evidence_dir` | string | ./evidence | Where to save artifacts |
| `selectors` | string | accessibility-first | Selector strategy |
| `self_healing_retries` | int | 1 | Max retries with self-healing (0=disabled) |

## repos.<key>

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Relative path to repo root |
| `base_url` | string | Yes | Dev server URL |
| `dev_command` | string | No | Command to start dev server |
| `source` | enum | Yes | `linear` or `github` |
| `project_key` | string | If linear | Linear project key (e.g., SKIN) |
| `repo` | string | If github | GitHub repo (e.g., org/name) |
| `branch` | string | Yes | Default branch to test |
| `gitnexus` | bool | No | Use GitNexus MCP for code scouting |
| `auth` | object | No | Auth configuration |

## repos.<key>.auth

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `strategy` | enum | Yes | `skip` or `storage-state` |
| `state_file` | string | If storage-state | Path to save auth cookies |
| `login_url` | string | If storage-state | Login page path |
| `credentials_env` | object | If storage-state | Env var names for email/password |

## Auto-Detection Rules

Issue identifier → repo matching:
1. `SKIN-101` → scan all repos for `project_key: SKIN`
2. `org/repo#42` → scan all repos for `repo: org/repo`
3. `--repo <key>` → direct key lookup (overrides auto-detect)
4. URL → parse domain (linear.app/github.com) then match

---

## Repo Manifest (`.qa-scan.yaml`) — v4+

Optional file in target repo root. Overrides auto-detect for env bootstrap (Step 0a).

Full schema: see `references/env-bootstrap.md` → "Manifest Schema" section.

Minimal example:
```yaml
dev:
  command: bun dev
  port: 3000
  health_path: /api/health
env:
  file: .env.local
  required: [DATABASE_URL]
```
