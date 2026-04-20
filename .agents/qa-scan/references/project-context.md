# Project Context Extraction

Extract structured project context for qa-scan agents to understand target codebase.

## Context Schema (JSON Output)

```json
{
  "project": {
    "name": "string",
    "description": "string (1-2 sentences)",
    "type": "web-app | api | library | cli | mobile"
  },
  "tech_stack": {
    "language": "typescript | javascript | python | go",
    "framework": "react | next | express | fastapi | hono",
    "runtime": "node | bun | deno | python",
    "test_framework": "playwright | jest | pytest | vitest"
  },
  "commands": {
    "install": "npm install | bun install",
    "dev": "npm run dev | bun dev",
    "build": "npm run build",
    "test": "npm test | bun test"
  },
  "environment": {
    "env_file": ".env | .env.local | none",
    "required_services": ["postgres", "redis"],
    "ports": [3000, 5432]
  },
  "entry_points": {
    "main": "src/index.ts | app/main.py",
    "routes": "src/app/api/* | routes/*",
    "components": "src/components/*"
  }
}
```

## Extraction Sources (Priority)

| Source | Data Extracted |
|--------|----------------|
| `README.md` | Description, setup, architecture |
| `package.json` | Name, scripts, deps, framework |
| `pyproject.toml` | Python deps, scripts |
| `go.mod` | Go module info |
| `.env.example` | Required env vars |
| `docker-compose.yml` | Required services |
| `playwright.config.ts` | Test config |

## Extraction Steps

1. **Read README.md** (required)
   - Extract project description (first paragraph)
   - Find setup instructions (## Setup, ## Getting Started)
   - Identify tech stack mentions

2. **Read package.json** (if exists)
   - `name` → project.name
   - `scripts.dev` → commands.dev
   - `scripts.test` → commands.test
   - `dependencies` → detect framework (next, react, express, hono)
   - `devDependencies` → detect test framework (playwright, jest, vitest)

3. **Read pyproject.toml** (if Python project)
   - `[project].name` → project.name
   - `[project.scripts]` → commands

4. **Detect entry points**
   - Next.js: `src/app/`, `app/`
   - Express: `src/index.ts`, `server.ts`
   - React: `src/components/`

5. **Check environment**
   - Look for `.env.example` or `.env.local.example`
   - Extract required variables (without values)

## Output Format

Return JSON matching schema above, wrapped in code block:

```json
{
  "project": {
    "name": "test-app",
    "description": "Demo Next.js app for QA testing",
    "type": "web-app"
  },
  "tech_stack": {
    "language": "typescript",
    "framework": "next",
    "runtime": "bun",
    "test_framework": "playwright"
  },
  "commands": {
    "install": "bun install",
    "dev": "bun dev",
    "build": "bun run build",
    "test": "bun test"
  },
  "environment": {
    "env_file": ".env.local",
    "required_services": [],
    "ports": [3001]
  },
  "entry_points": {
    "main": "src/app/layout.tsx",
    "routes": "src/app/api/*",
    "components": "src/components/*"
  }
}
```

## Status Handling

| Condition | Status |
|-----------|--------|
| All critical info found | DONE |
| README sparse but parseable | DONE_WITH_CONCERNS [observational] |
| No README, package.json exists | DONE_WITH_CONCERNS [correctness] |
| No README and no package.json | NEEDS_CONTEXT |
| Parse error | BLOCKED |

Follow status protocol: `references/status-protocol.md`
