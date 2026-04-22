# Env Bootstrap Reference

Heuristics + manifest schema cho `qa-env-bootstrap` agent (Step 0a).

## Stack Detection (Heuristic)

### Signals (priority order)

1. **Manifest override** — `.qa-scan.yaml` ở repo root wins
2. **`package.json` scripts** — pattern match
3. **Framework config files** — `next.config.*`, `vite.config.*`, `app.json` (Expo), `nest-cli.json`
4. **Lockfile** — manager detection (bun.lock → bun, pnpm-lock.yaml → pnpm, yarn.lock → yarn, package-lock.json → npm)

### Framework signatures

| Framework | Signal | Default `dev` | Default port | Health path |
|-----------|--------|---------------|--------------|-------------|
| Next.js | `next.config.*` OR `"next"` trong deps | `next dev` | 3000 | `/` or `/api/health` |
| Vite | `vite.config.*` | `vite` | 5173 | `/` |
| Expo | `app.json` + `expo` dep | `expo start` | 8081 | `/` (Metro) |
| Nest.js | `nest-cli.json` | `nest start --watch` | 3000 | `/` |
| Express (custom) | `"express"` dep, no framework config | `node {entry}` from scripts | 3000 (fallback) | `/` |
| Astro | `astro.config.*` | `astro dev` | 4321 | `/` |

### Monorepo handling

Nếu detect `turbo.json` / `nx.json` / `pnpm-workspace.yaml`:
- **REQUIRE manifest `dev.cwd`** → fail BLOCKED nếu thiếu (không đoán target package)
- Run command từ manifest `dev.cwd` với appropriate tool (`turbo run dev --filter={name}` nếu turbo detected)

---

## Install Manager Detection

| Lockfile | Manager | Install command (skip if fresh) |
|----------|---------|--------------------------------|
| `bun.lock` | bun | `bun install` |
| `pnpm-lock.yaml` | pnpm | `pnpm install --frozen-lockfile` |
| `yarn.lock` | yarn | `yarn install --frozen-lockfile` |
| `package-lock.json` | npm | `npm ci` |
| (none) | fallback | `npm install` |

**"Skip if fresh":** compare `node_modules/.package-lock.json` mtime vs lockfile mtime. Skip install nếu node_modules newer than lockfile.

---

## .env File Resolution

### Order (first found wins)
1. Manifest `env.file` (override)
2. `.env.local`
3. `.env`
4. `.env.development`

### Required vars validation
- Manifest `env.required[]` lists env var names
- Grep từng var trong resolved .env file
- Missing → **BLOCKED via T4 template**, list each missing var

### Cache secrets (across runs)
- Path: `~/.qa-scan/secrets/{repo_name}.yaml` (mode 0600, gitignored)
- First run: prompt via T4 → save tới cache
- Subsequent runs: merge cache → `.env` trước validate

---

## Dependent Services

### Detection
- `docker-compose.yml` / `docker-compose.dev.yml` → compose services
- Manifest `services.compose_file` override

### Start logic
```bash
docker compose -f {compose_file} up -d {wait_for...}
```

### Healthcheck wait
Timeout 60s (configurable via manifest `services.healthcheck_timeout`). Poll `docker inspect` → healthy, OR TCP check port từ compose ports.

Fail handling: BLOCKED via T4.

---

## Dev Server Lifecycle

### Kill existing occupant
User decision (Brainstorm Session 1): **always kill + restart** cho port conflict.

```bash
# Log before kill for audit
lsof -iTCP:$PORT -sTCP:LISTEN -nP | tail -n +2 | awk '{print "PID="$2" CMD="$1" USER="$3}' > "$EVIDENCE/killed-processes.log"
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
```

**Escape hatch:** `QA_SCAN_NO_KILL=1` env var → skip kill, BLOCKED nếu port occupied.

### Spawn detached
```bash
nohup {dev_command} > "{results_dir}/{repo}/.dev-server.log" 2>&1 &
echo $! > "{results_dir}/{repo}/.dev-server.pid"
```

### Wait-for-ready
Primary: poll `health_path` 1s interval, 60s timeout, expect HTTP 2xx/3xx
Fallback: regex `ready_text` trên stdout log

### Cleanup (orchestrator registers)
```bash
# On scan end (success OR abort)
PID=$(cat "{results_dir}/{repo}/.dev-server.pid" 2>/dev/null)
[ -n "$PID" ] && kill "$PID" 2>/dev/null
```

Docker compose services: **persist** (don't teardown) — next scan reuse.

---

## Manifest Schema (`.qa-scan.yaml`)

Optional file ở target repo root. Override auto-detect khi cần.

```yaml
# Dev server config
dev:
  command: bun dev              # override auto-detected command
  cwd: apps/web                 # monorepo target (required nếu monorepo)
  port: 3000                    # override default port
  health_path: /api/health      # health check endpoint
  ready_text: "Ready in"        # alternative: regex trên stdout

# Environment
env:
  file: .env.local              # override resolution order
  required:                     # validate these exist
    - DATABASE_URL
    - NEXT_PUBLIC_API_URL

# Dependent services
services:
  compose_file: docker-compose.dev.yml
  wait_for: [db, redis]
  healthcheck_timeout: 60       # seconds

# Install
install:
  command: bun install --frozen-lockfile   # override auto-detect
  skip_if_fresh: true           # skip if node_modules.mtime > lockfile.mtime
```

### Validation
- `dev.port` 1-65535
- `dev.health_path` starts with `/`
- `env.required[]` non-empty strings
- `services.wait_for` matches services in compose_file

### Precedence
Manifest > heuristic. Invalid manifest → BLOCKED T4 with validation errors.

---

## Output Contract

Agent trả về JSON:
```json
{
  "base_url": "http://localhost:3000",
  "server_pid": 12345,
  "service_pids": {"db": 12340, "redis": 12341},
  "env_file": ".env.local",
  "cleanup_hook": {
    "pid_file": "qa-results/skin-agent-fe/.dev-server.pid",
    "log_file": "qa-results/skin-agent-fe/.dev-server.log"
  },
  "diagnostics": {
    "stack_detected": "nextjs",
    "manifest_used": true,
    "secrets_cached": 2,
    "services_started": ["db", "redis"],
    "killed_pids": [98765]
  }
}
```
