# Changelog

All notable changes to qa-scan will be documented here. Follows [Semantic Versioning](https://semver.org/).

## [4.3.0] — 2026-05-04

### Added

- **`scripts/qa-scan-gemini.sh`** — bash orchestrator for the Gemini CLI runtime. Chains 8 fresh `gemini -p` subprocesses, one per pipeline step. Each sub-agent gets its own clean context window. State passes between steps via JSON files at `{results_dir}/{repo}/{issue}/state/step-{n}-{name}.json`. Mirrors the `run-cell-v3.sh` pattern from the research pipeline (proven to scale).
- Stdout markers: `STEP_BEGIN`, `STEP_COMPLETE`, `STEP_FAILED`, `PIPELINE_DONE` — parseable from any caller.

### Changed

- **`.gemini/commands/qa-scan.toml`** — slash command `/qa-scan` no longer inlines the orchestrator agent into a single prompt. It now instructs Gemini to run `bash .agents/qa-scan/scripts/qa-scan-gemini.sh` via the Bash tool. The bash script handles all spawning. Result: each Gemini sub-agent invocation starts with empty context, which prevents the timeout/cancel observed in v4.0–4.2 around step 5–6.
- **`agents/qa-orchestrator.md`** (Claude path) — removed redundant `Read your agent file at .claude/agents/<name>.md and ` line from all 8 Task() prompts. Claude resolves the agent definition from `subagent_type` automatically; the explicit path was harmful path coupling that broke portability and double-loaded agent files.

### Why

User report: pulling v4.2.0 to a Gemini sandbox still timed out, because the v4.2.0 fix only updated the Claude orchestrator (which uses Task() invocations Gemini does not support). Gemini path needed its own architecture. Bash chaining mirrors the proven research-pipeline approach: orchestrator state lives in shell variables and disk, never in any LLM context.

### Migration from 4.2.x

- **Claude users:** no behavior change. Same `/qa-scan SKI-101`. Path coupling cleanup is internal.
- **Gemini users:** same `/qa-scan SKI-101` invocation; first call dispatches to the bash orchestrator. Requires `gemini` CLI ≥ 0.40 in PATH. Each step runs in its own subprocess so context bloat no longer compounds.

### Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash -s -- --non-interactive
```

Verify Gemini installer:
```bash
ls .agents/qa-scan/scripts/qa-scan-gemini.sh   # script present
grep "qa-scan-gemini.sh" .gemini/commands/qa-scan.toml   # slash command points to bash
```

## [4.2.0] — 2026-05-04

### Changed

- **`qa-orchestrator` enforces explicit `Task()` spawn pattern.** Each step that previously said "Spawn agent: X" (8 steps total: context-extractor, env-bootstrap, issue-analyzer, code-scout, test-generator, test-runner, coverage-verifier, report-synthesizer) now contains a copy-verbatim `Task(subagent_type=…, description=…, prompt=…)` code block with concrete input/output file paths. Prior wording was ambiguous → orchestrator inlined sub-agent work into its own context, bloating one session past timeout.
- **Disk-based state contract.** Each sub-agent now writes its output JSON to `{results_dir}/{repo_key}/{issue_id}/state/step-{n}-{name}.json`. Subsequent agents read previous step state from that path instead of receiving full payload through prompt context. Mirrors `research-orchestrator` pattern (`run-cell-v3.sh` + `cells/{cell_id}/*.json`) which has been proven to scale.

### Added

- **AUTONOMOUS EXECUTION block** (top of `qa-orchestrator.md`) — mirrors `research-orchestrator.md`. Orchestrator MUST NOT stop between steps; only stops on `BLOCKED`, `NEEDS_CONTEXT`, or `COMPLETE`. Treats the entire run as one atomic task.
- **Sub-agent Spawn Pattern section** with canonical `Task()` template. Hard rule: orchestrator never reads agent files itself, never executes step bodies itself, never calls sub-agent tools (Bash/MCP/Read on the sub-agent's behalf). Toolkit intentionally minimal: `Read` (config + status only), `Task` (spawn), `SendMessage` (escalation).
- **Inline-Detection Guard** — orchestrator must emit `INLINE_DETECTED` and resume via `Task()` if it catches itself reading agent files, running sub-agent tools, or producing sub-agent JSON output directly.

### Why

Live runtime observed orchestrator running ALL 8 steps in one subagent context (no `Task()` invocations), causing context bloat → timeout → session cancellation around step 5–6. Root cause: prompt wording "Spawn agent: X" was treated as plain text, not a runtime instruction. Fix copies the proven research pipeline pattern (explicit Task spawn + disk-based state passing) so each sub-agent gets its own 200K-token context window and orchestrator only holds state pointers.

### Migration from 4.1.x

No breaking changes for end users — same `/qa-scan SKI-101` invocation. Sub-agent contracts (qa-context-extractor.md, qa-env-bootstrap.md, etc.) unchanged. Behavior change: orchestrator now spawns each sub-agent through Claude's Task tool. On Gemini CLI (which lacks Task spawning), pipeline still inlines — full Gemini fix tracked for v5.0.0.

### Upgrade

```bash
bash qa-scan-repo/install.sh --non-interactive
```

Verify: `grep -c "subagent_type=" .claude/agents/qa-orchestrator.md` should output `9` (1 template + 8 step invocations).

## [4.1.0] — 2026-05-04

### Changed

- **`qa-orchestrator` pre-flight no longer runs install commands.** Pre-flight now DETECTS only (Linear MCP, GitNexus, Playwright binary). If Playwright missing → mark `needs_install` and defer to `qa-env-bootstrap` (Step 0a) which is lockfile-aware. Prior behavior hardcoded `bun install` regardless of repo's package manager, breaking pnpm/npm/yarn projects.
- **`qa-env-bootstrap` Step 2 (install) made lockfile-mandatory.** Detection logic now explicit per manager (`bun.lock`/`bun.lockb` → bun, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm). Falls back to `project_context.commands.install` when no lockfile matches; BLOCKED T4 if neither resolvable. Prefers `project_context.commands.install` when present.
- **`qa-env-bootstrap` now installs Playwright dev dep on demand** using the detected manager (e.g. `bun add -d @playwright/test`). Never substitutes the manager.

### Added

- `qa-orchestrator.md` "Hard Rules" section explicitly forbids hardcoded `bun install` / `npm install` / `pnpm install` / `yarn install` in any agent prompt. Forces stack-aware install path through Step 0 → Step 0a.

### Why

Live runtime observed orchestrator running `npm install --save-dev @playwright/test` in pre-flight on a `bun`-based repo, corrupting context and forcing user cancellation. Root cause: pre-flight ran before `qa-context-extractor` (which detects package manager) → no way to choose the correct manager. Fix moves all install responsibility to Step 0a where lockfile detection already exists.

### Upgrade

Re-run installer in your workspace:
```bash
bash qa-scan-repo/install.sh --non-interactive
```

No config changes required. Behavior is backward-compatible — existing scans continue to work, but now correctly use the project's package manager instead of hardcoded `bun`.

## [4.0.2] — 2026-05-04

### Fixed

- **Workspace runtime `references/`, `fixtures/`, `scripts/` not synced on install** — `install.sh` now copies bundled runtime to `$WORKSPACE/.agents/qa-scan/` so agents can resolve `references/X.md` paths at runtime. Prior installs left workspace `.agents/qa-scan/references/` stale (e.g. missing `env-bootstrap.md`, `web3-testing.md`, `status-protocol.md`, `mcp-diagnostics.md`, `gitnexus-flows.md`, `project-context.md`), breaking `qa-env-bootstrap` and `qa-context-extractor` agent reference loads.
- **Source drift consolidated** — `references/env-bootstrap.md` moved into `.agents/qa-scan/references/` (canonical location). Both legacy `references/` and `.agents/qa-scan/references/` accepted as source by installer (canonical wins).

### Upgrade

Re-run installer in your workspace:
```bash
bash qa-scan-repo/install.sh --non-interactive
```
Then verify: `ls .agents/qa-scan/references/` should contain `env-bootstrap.md`.

## [4.0.1] — 2026-04-22

### Fixed

- **Gemini CLI `/qa-scan` slash command not installed on fresh install** — `install.sh` now copies `.gemini/commands/*.toml` → `$WORKSPACE/.gemini/commands/`. Previously only `/scan` MD prompt was synced, making `/qa-scan` unavailable on fresh machines. `uninstall.sh` updated to clean up.

### Upgrade

Re-run installer:
```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
```

## [4.0.0] — 2026-04-22

### Breaking

- **Remove `qa-flow-analyzer` agent** — merged into `qa-code-scout` (single unified Step 2)
- **Remove `references/analyze-flow.md`** — content absorbed into `references/scout-code.md`
- **Rename Step 0b (server health) → Step 0a (env bootstrap)** with expanded responsibilities (install deps, setup .env, start services, kill-restart dev server)
- **Agent frontmatter cleanup** — removed `model`, `tools`, `background`, `maxTurns`, `timeout` keys; tools declared inline in body
- **Reference paths normalized** — `.agents/qa-scan/references/` → `references/` trong agent Load directives

### Added

- **`qa-env-bootstrap` agent** (Step 0a) — auto-detect stack, install deps, setup `.env`, start Docker services, spawn dev server with kill+restart policy, health wait
- **`.qa-scan.yaml` manifest support** — optional per-repo override for env bootstrap (dev command, port, health path, required env vars, services, install command)
- **`rules/vi-escalation.md`** — VI escalation rule với 7 templates (T1-T7) cho user-facing prompts
- **`rules/update-workflow.md`** — governance rule: qa-scan-repo là source of truth, never edit workspace copies
- **`qa-context-extractor` agent** (Step 0) — explicit project context extraction (previously inline trong orchestrator)
- **README Mermaid diagrams** — 3 flow diagrams (pipeline, escalation state machine, install sequence)
- **install.sh rules sync** — copy `rules/*.md` → `.claude/rules/qa-scan/` + `.gemini/rules/qa-scan/`

### Changed

- **`qa-code-scout` output contract** — now returns `{files, flows, routes, shapes, test_matrix}` in single pass (was `{files}` only); GitNexus preferred, grep/glob fallback
- **`qa-orchestrator` Step -1 pre-flight** — debug-first escalation ladder với auto-fix attempts (max 3) trước user prompt
- **Status protocol** — all agents emit structured status blocks: `DONE`, `DONE_WITH_CONCERNS[observational|correctness]`, `BLOCKED`, `NEEDS_CONTEXT`
- **`qa-code-scout` description** — updated để reflect unified role (Step 2 merged)

### Migration from v3

**For existing v3 users upgrading:**

1. Finish any in-progress scan (tracker state may reset during upgrade)
2. Re-run installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash
   # or, if already cloned:
   bash .agents/qa-scan/scripts/install.sh
   ```
3. Installer tự động:
   - Remove stale `.claude/agents/qa-flow-analyzer.md` + `.gemini/agents/qa-flow-analyzer.md`
   - Install new `qa-env-bootstrap` + `qa-context-extractor` agents
   - Create `.claude/rules/qa-scan/` + `.gemini/rules/qa-scan/` với 2 rule files
4. Optional: add `.qa-scan.yaml` manifest vào target repo(s) nếu cần override auto-detect
5. Verify: `/qa-scan <issue>` — should spawn Step 0a (env bootstrap) sau Step 0
6. Nếu có custom edits trong `.claude/agents/qa-*.md` → port ngược vào `qa-scan-repo/agents/` TRƯỚC re-install (theo `rules/update-workflow.md`)

**Breaking callouts:**
- Scripts referencing `qa-flow-analyzer` trực tiếp sẽ fail — remove references
- `references/analyze-flow.md` no longer exists — if custom prompts reference it, switch to `references/scout-code.md` "Flow Extraction Fallback" section
- Dev server auto-start behavior changed — destructively kills port occupants. Set `QA_SCAN_NO_KILL=1` env var nếu muốn giữ hành vi cũ (fail fast on port conflict)

### Fixed

- Inconsistent VI/EN user prompts — now standardized VI via `rules/vi-escalation.md`
- Workspace drift từ source — governance rule `update-workflow.md` prevents direct workspace edits

---

## [3.0.0] — 2026-04-20

Earlier release (claude-kit pattern, bun CLI install, fixture auto-mapping). See git log for detail.
