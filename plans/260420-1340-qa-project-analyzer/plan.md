---
title: "qa-project-analyzer: Test Roadmap Generation"
description: "Add analyze command to generate test-roadmap.json with domain detection and flow extraction"
status: completed
priority: P1
effort: 8h
branch: main
tags: [qa-scan, analyzer, domain-detection, cli]
created: 2026-04-20
---

# qa-project-analyzer

Add `bunx qa-scan analyze` command to pre-analyze projects and generate cached test strategy.

## Problem

Current qa-scan analyzes per-issue → duplicate work + no domain-specific understanding.

## Solution

Project-level analyzer that:
1. Detects domain (Web3/fintech/SaaS) from deps
2. Extracts critical flows via GitNexus
3. Generates `test-roadmap.json` (cached)
4. Infers test environment setup

## Commands

| Command | Action |
|---------|--------|
| `bunx qa-scan analyze` | Generate/refresh test roadmap |
| `bunx qa-scan analyze --repo x` | Specific repo only |
| `bunx qa-scan analyze --force` | Ignore cache, re-analyze |
| `bunx qa-scan status` | Show roadmap freshness |

## Output

```
.agents/qa-scan/cache/{repo-key}/
├── test-roadmap.json    # Main roadmap
├── .analyzed-commit     # Staleness check
└── setup-script.sh      # Auto-generated env setup
```

## Phases

| # | Phase | Effort | Files |
|---|-------|--------|-------|
| 1 | [CLI Command](./phase-01-cli-command.md) | 1h | cli/analyze.ts, cli/index.ts |
| 2 | [Domain Detection](./phase-02-domain-detection.md) | 1.5h | cli/domain-detector.ts, references/domain-detection.md |
| 2b | [Web3 Test Fixtures](./phase-02b-web3-fixtures.md) | 2h | fixtures/web3-mock.ts, references/web3-testing.md |
| 3 | [Flow Extraction](./phase-03-flow-extraction.md) | 1.5h | cli/flow-extractor.ts |
| 4 | [Roadmap Generation](./phase-04-roadmap-generation.md) | 1h | cli/roadmap-generator.ts |
| 5 | [Cache + Integration](./phase-05-cache-integration.md) | 1h | cache logic, Step 0 update |

## Success Criteria

- [x] `bunx qa-scan analyze` generates test-roadmap.json
- [x] Domain detection works for Web3, fintech, SaaS
- [x] Web3 projects get wagmi mock connector + anvil fixtures
- [x] GitNexus integration extracts flows (fallback to patterns if unavailable)
- [x] Cache invalidation on commit change
- [ ] Step 0 loads cached roadmap (orchestrator integration pending)

## Research

- [Web3 E2E Testing Report](../reports/researcher-260420-1403-web3-e2e-testing.md) - Wagmi mock + Anvil approach
