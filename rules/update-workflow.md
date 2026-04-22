# QA Scan — Update Workflow (Governance Rule)

**Scope:** Maintainers của qa-scan (agents, references, rules, installer).
**Intent:** `qa-scan-repo` là single source of truth. Mọi update propagate ra workspace qua `install.sh`, không edit trực tiếp workspace copies.

---

## Source of Truth

```
qa-scan-repo/                      ← SOURCE (edit here)
├── agents/                        → installed into .claude/agents/
├── .gemini/agents/                → installed into .gemini/agents/
├── rules/                         → installed into .claude/rules/qa-scan/ + .gemini/rules/qa-scan/
├── references/                    → bundled in .agents/qa-scan/references/
├── scripts/, adapters/, config/   → bundled in .agents/qa-scan/
├── .claude/skills/qa-scan/        → installed into .claude/skills/qa-scan/
├── install.sh / uninstall.sh      → entry points
├── README.md                      → consumer-facing docs
├── CHANGELOG.md                   → release notes + migration
└── package.json                   → version
```

Workspace after install:
```
{workspace}/
├── .claude/agents/qa-*.md         ← installed copy — DO NOT EDIT
├── .gemini/agents/qa-*.md         ← installed copy — DO NOT EDIT
├── .claude/rules/qa-scan/*.md     ← installed copy — DO NOT EDIT
├── .gemini/rules/qa-scan/*.md     ← installed copy — DO NOT EDIT
├── .claude/skills/qa-scan/*       ← installed copy — DO NOT EDIT
└── .agents/qa-scan/               ← bundled runtime (references, scripts, evidence, cache)
```

---

## Update Chain (6 steps)

1. **Edit** trong `qa-scan-repo/` (never workspace copies)
2. **Commit** qa-scan-repo với conventional message (`feat|fix|refactor|docs|chore`)
3. **Bump version** `package.json` nếu breaking (major) / feature (minor) / fix (patch)
4. **Update** `CHANGELOG.md` với section mới — include migration steps nếu breaking
5. **Re-run installer** trong workspace:
   ```bash
   bash qa-scan-repo/install.sh --non-interactive --project-dir /path/to/workspace
   ```
6. **Verify** workspace = source:
   ```bash
   for f in qa-scan-repo/agents/qa-*.md; do
     diff -q "$f" ".claude/agents/$(basename $f)" || echo "DRIFT: $(basename $f)"
   done
   for f in qa-scan-repo/rules/*.md; do
     diff -q "$f" ".claude/rules/qa-scan/$(basename $f)" || echo "DRIFT: $(basename $f)"
     diff -q "$f" ".gemini/rules/qa-scan/$(basename $f)" || echo "DRIFT: $(basename $f)"
   done
   ```

---

## Forbidden

- ❌ Edit workspace `.claude/agents/qa-*.md` trực tiếp
- ❌ Edit workspace `.claude/rules/qa-scan/*.md` trực tiếp
- ❌ Edit workspace `.gemini/agents/qa-*.md` hoặc `.gemini/rules/qa-scan/*.md` trực tiếp
- ❌ Skip version bump cho breaking changes
- ❌ Skip CHANGELOG update

## Allowed
- ✅ Edit workspace files TẠM thời để prototype — MUST port back vào qa-scan-repo trước commit
- ✅ Edit `.agents/qa-scan/evidence/` / `cache/` (runtime state, not tracked)

---

## File Ownership Matrix

| Source path | Installed path | Editor |
|-------------|----------------|--------|
| `qa-scan-repo/agents/` | `{ws}/.claude/agents/` | Maintainer (source only) |
| `qa-scan-repo/.gemini/agents/` | `{ws}/.gemini/agents/` | Maintainer (source only) |
| `qa-scan-repo/rules/` | `{ws}/.claude/rules/qa-scan/` + `{ws}/.gemini/rules/qa-scan/` | Maintainer (source only) |
| `qa-scan-repo/references/` | `{ws}/.agents/qa-scan/references/` | Maintainer (source only) |
| `qa-scan-repo/.claude/skills/qa-scan/` | `{ws}/.claude/skills/qa-scan/` | Maintainer (source only) |
| `.agents/qa-scan/evidence/` | (same) | Runtime — agents write, human read |
| `.agents/qa-scan/cache/` | (same) | Runtime — agents write |

---

## Release Checklist

- [ ] Source edits committed trong qa-scan-repo
- [ ] `package.json` version bumped (semver)
- [ ] `CHANGELOG.md` section mới thêm — include migration nếu breaking
- [ ] `install.sh` dry-run OK trên ephemeral folder
- [ ] README reflect version mới (nếu thay đổi install command, usage, flow)
- [ ] Git tag: `git tag v{version} && git push --tags`
- [ ] Workspace verify: diff command ở trên output empty

---

## Enforcement (Optional CI)

Pre-commit hook đề xuất (không bắt buộc):
```bash
#!/bin/bash
# Block commits nếu workspace drift khỏi source
if [ -d qa-scan-repo ]; then
  for f in qa-scan-repo/agents/qa-*.md; do
    if ! diff -q "$f" ".claude/agents/$(basename $f)" > /dev/null 2>&1; then
      echo "ERROR: Workspace drift detected — re-run install.sh trước commit"
      exit 1
    fi
  done
fi
```

---

**Rationale:** Workspace copies là artifact, không phải canonical. Edit source → predictable distribution. Không source-first → workspace state không reproducible, install.sh ghi đè local edits gây conflict, maintainer lose changes.
