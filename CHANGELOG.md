# Changelog

All notable changes to qa-scan will be documented here. Follows [Semantic Versioning](https://semver.org/).

## [4.5.0] — 2026-05-04

### Added

- **`qa-pipeline-planner` sub-agent** (Step 1b) — reasons about issue scope + project context, emits an `execution_plan` JSON deciding which **selectable** steps to run for this issue. Lives between `qa-issue-analyzer` (Step 1) and `qa-env-bootstrap` (Step 0a) so it can advise skipping the bootstrap when there's no runtime to test (doc-only, type-only, lint-only fixes).
- **`always_run` flag** on each manifest step (`references/qa-pipeline.yaml`). Always-run = `[0, 1, 1b, 6]` (context, issue, planner, report). Selectable = `[0a, 2, 3, 4, 5]`.
- **`STEP_SKIPPED step=<id> name=<agent> reason=<text>`** stdout marker — emitted by bash orchestrator and Claude orchestrator for steps the planner chose to skip.
- **`EXECUTION_PLAN selected=<csv>`** marker — printed once after Step 1b runs, listing which selectable steps will execute.

### Changed

- **Manifest order reshuffled** to support the planner: `[0, 1, 1b, 0a, 2, 3, 4, 5, 6]`. Step ids preserved (no on-disk filename changes) — only YAML order changed. Bash and Claude orchestrators both iterate in declared order.
- **`scripts/qa-scan-gemini.sh`** filters selectable steps against the planner's `execution_plan`. Hard rule: if planner doesn't emit `execution_plan` (malformed output) → `PIPELINE_DONE verdict=ABORTED reason=planner_no_plan`.
- **`agents/qa-orchestrator.md`** (Claude path) gains a Step 1b Task() block + filtering rule mirroring bash behavior.
- **Step 6 inputs** now include `planner_state: state/step-1b-plan.json` so the final report can document which steps were skipped and why.

### Why

User feedback after v4.4.0: manifest was static — every issue ran all 8 steps regardless of scope. A doc-only fix would still install dev deps + start a server + run Playwright (~2 min wasted). The planner adds task-aware reasoning: read issue + context, output a subset of steps that actually matter for THIS issue. Approx savings:

| Issue type             | Steps skipped         | Time saved |
|------------------------|-----------------------|------------|
| Doc / type-only        | 0a, 3, 4, 5           | ~3 min     |
| Single-component fix   | 5                     | ~30 s      |
| Critical security fix  | (none — full coverage)| 0          |
| Multi-component refactor | (none)              | 0          |

### Migration from 4.4.x

- **Sub-agent contracts unchanged.** Existing 8 sub-agents work as-is.
- **Pipeline customization:** to skip a step always, set `always_run: false` and the planner can decide; if you want a hard skip regardless of planner, remove the step from the manifest entirely.
- **CI / non-interactive:** planner emits its plan without prompting. `QA_SCAN_NONINTERACTIVE=1` still applies for downstream steps' BLOCKED handling.
- **Backward path:** if you want pre-4.5 behavior (always run everything), set `always_run: true` on all manifest steps. Planner will still run but its plan is ignored when no step is selectable.

### Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash -s -- --non-interactive
```

Verify:
```bash
ls .claude/agents/qa-pipeline-planner.md
grep -c "always_run" .agents/qa-scan/references/qa-pipeline.yaml   # expect 9
```

## [4.4.0] — 2026-05-04

### Added

- **Non-interactive subprocess rule** (`references/non-interactive-rule.md`) — sub-agents must NEVER call `AskUserQuestion` or wait for stdin. They emit `escalation` JSON payload with question + options and return `NEEDS_CONTEXT`/`BLOCKED`. The orchestrator (Claude Task or bash chain) is the only layer allowed to interact with the user. All 18 sub-agent files (Claude + Gemini) now `Load and follow` this rule.
- **Pipeline manifest** (`references/qa-pipeline.yaml`) — single source of truth declaring all 8 steps, agent names, output filenames, input dependencies, and on_failure policy. Both runtimes can read this; bash orchestrator now drives off it.
- **T1–T7 template files** (`references/templates/T{1..7}.md`) — discrete reusable escalation templates extracted from `vi-escalation.md`. Bash and Claude can both reference by ID instead of inlining text.

### Changed

- **`scripts/qa-scan-gemini.sh` rewritten manifest-driven.** Steps are no longer hard-coded; the script reads `qa-pipeline.yaml` and loops. Adds `NEEDS_CONTEXT` retry loop with user prompt (max `QA_SCAN_MAX_RETRIES` = 3 per step), `BLOCKED` escalation surface via T-template ID, and `QA_SCAN_NONINTERACTIVE=1` env flag for CI auto-abort.
- **New stdout markers:** `NEEDS_USER_INPUT`, `STEP_RETRY` — parseable by callers chaining the script.
- **Dependency check upfront:** script aborts immediately if `gemini` / `python3` / `jq` not in PATH (was failing mid-pipeline before).

### Why

User feedback after v4.3.0: sub-agents that hit ambiguity (e.g. low-confidence issue analysis) tried to call `AskUserQuestion` from inside their subprocess context, hanging the parent bash chain because subprocess stdin is closed. Same risk under Claude `Task()` — the spawned subagent has no dialog channel back. Fix: standardize on disk-based escalation payload + orchestrator-side prompts. KISS + DRY: the manifest replaces 8 hand-coded step blocks; the templates dir replaces inline T-text duplication.

### Migration from 4.3.x

- **Sub-agent authors:** if you previously emitted user prompts inline, switch to populating `escalation` in your output JSON (see `references/non-interactive-rule.md`). Loading that rule is now mandatory (already added to all bundled agents).
- **Bash orchestrator users:** behavior unchanged for the happy path; new behavior on NEEDS_CONTEXT (now retries with user input instead of aborting). Set `QA_SCAN_NONINTERACTIVE=1` in CI.
- **Pipeline customization:** to add/remove/reorder steps, edit `references/qa-pipeline.yaml` instead of touching the bash script.

### Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/cyberk-dev/qa-scan/main/install.sh | bash -s -- --non-interactive
```

Verify:
```bash
ls .agents/qa-scan/references/qa-pipeline.yaml
ls .agents/qa-scan/references/templates/T1.md
grep -c "non-interactive-rule" .claude/agents/qa-context-extractor.md   # expect 1
```

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
