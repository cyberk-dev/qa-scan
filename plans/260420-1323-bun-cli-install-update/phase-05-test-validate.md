# Phase 5: Test & Validate

## Overview
- **Priority:** P2
- **Status:** pending
- **Effort:** 10m

## Test Cases

### 1. Fresh Install

```bash
cd /tmp
mkdir test-workspace
cd test-workspace
git clone git@github.com:cyberk-dev/qa-scan.git .agents/qa-scan

# Run install
cd .agents/qa-scan
bun run cli/index.ts install

# Verify
bun run cli/index.ts verify
```

**Expected:**
- All deps installed
- qa-results/ created
- All adapters created
- verify shows all ✓

### 2. Update (preserve config)

```bash
# Modify an agent file in source
echo "# Modified" >> agents/qa-orchestrator.md

# Modify user's config (should be preserved)
echo "# User config" >> config/qa.config.yaml

# Run update
bun run cli/index.ts update

# Check
cat $WORKSPACE/.claude/agents/qa-orchestrator.md  # Should have "# Modified"
cat config/qa.config.yaml  # Should still have "# User config"
```

**Expected:**
- Agent overwritten
- Config preserved

### 3. Version Display

```bash
bun run cli/index.ts --version
# Output: qa-scan v3.0.0

bun run cli/index.ts update
# Output: Updating: v2.0.0 → v3.0.0
```

### 4. Help

```bash
bun run cli/index.ts
# Shows usage help
```

## Todo

- [ ] Test fresh install
- [ ] Test update preserves config
- [ ] Test version display
- [ ] Test help output

## Success Criteria

- All test cases pass
- No regressions from shell scripts
