# Changelog

All notable changes to qa-scan will be documented here. Follows [Semantic Versioning](https://semver.org/).

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
