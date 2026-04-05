# Porting QA Scan to Gemini CLI

Guide for using the QA Scan workflow with Gemini CLI (or other non-Claude agents).

## Overview

QA Scan is agent-agnostic. All prompts and config live in `.agents/qa-scan/`.
The Gemini adapter at `.gemini/qa-scan.md` points to the same workflow.

## Gemini CLI Invocation

```bash
# From Gemini CLI, reference the workflow:
gemini "Follow the workflow at .agents/qa-scan/workflow.md to QA scan issue SKIN-101"
```

## Key Differences from Claude Code

| Aspect | Claude Code | Gemini CLI |
|--------|------------|------------|
| Trigger | `/qa-scan SKIN-101` | Natural language + workflow path |
| Linear MCP | Native MCP support | Use `gh` CLI or Linear API as fallback |
| GitNexus MCP | Native MCP support | Use grep/glob fallback from scout-code.md |
| Bash execution | Via Bash tool | Via code execution / shell |
| Subagent for verification | Task(subagent_type="tester") | Inline or separate prompt |

## Gemini-Specific Notes

1. **MCP Support:** Gemini CLI supports MCP. If configured, GitNexus and Linear MCP work the same.
2. **No SKILL.md:** Gemini doesn't use SKILL.md. Reference `workflow.md` directly.
3. **Prompts:** All prompts in `references/` are agent-agnostic markdown. Load them the same way.
4. **Playwright:** Runs via bash/shell execution. Same commands, same config.

## Minimal Gemini Setup

1. Run: `bash .agents/qa-scan/scripts/install.sh`
2. Ensure `.gemini/qa-scan.md` exists (created by install.sh)
3. In Gemini: reference `.agents/qa-scan/workflow.md` when asked to do QA
