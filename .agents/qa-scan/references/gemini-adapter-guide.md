# Gemini CLI — Native Agent Support

QA Scan agents work natively on Gemini CLI. Same YAML frontmatter, same tool restrictions, same pipeline.

## Setup

```bash
# install.sh copies agents to .gemini/agents/ automatically
bash install.sh
```

Agents installed to `.gemini/agents/qa-*.md`. Gemini CLI auto-discovers them.

## Usage

```bash
# Auto-delegation (Gemini routes to orchestrator based on description)
gemini "QA scan issue SKIN-101"

# Forced delegation (@ syntax)
@qa-orchestrator scan SKIN-101 --repo skin-agent-fe
```

## How It Works

Gemini reads agent `.md` files from `.gemini/agents/`. Each agent has:
- `name:` — exposed as a tool name
- `description:` — Gemini uses this to auto-delegate
- `tools:` — allowlist enforced (same as Claude Code)

When `qa-orchestrator` is invoked, it spawns sub-agents as tools:
```
qa-orchestrator → qa-issue-analyzer → qa-code-scout → qa-flow-analyzer → ...
```

## Differences from Claude Code

| Feature | Claude Code | Gemini CLI |
|---------|-----------|------------|
| Agent path | `.claude/agents/` | `.gemini/agents/` |
| Spawn mechanism | `Agent` tool with `subagent_type` | Auto-delegation or `@agent` |
| `model:` field | Respected (haiku/sonnet) | Ignored (uses Gemini model) |
| Tool wildcards | Not supported | Supported (`*`, `mcp_*`) |
| Subagent recursion | Configurable | Blocked (1 level only) |
| MCP per-agent | Session-level | `mcpServers:` in frontmatter |
| `background:` | Supported | May not be supported |
| `timeout:` | Supported | May not be supported |

## Compatibility Notes

- **Recursion limit:** Gemini subagents cannot spawn other subagents. Our pipeline is compatible — orchestrator is the only spawner, all sub-agents are leaf nodes.
- **`model:` field:** Gemini ignores `model: haiku`/`model: sonnet`. Uses its own default model for all agents.
- **`background:`/`timeout:`:** These Claude Code frontmatter fields may be ignored by Gemini. Coverage-verifier will run foreground instead of background — slightly slower but functionally identical.
- **MCP:** Gemini CLI supports MCP natively. If GitNexus/Linear MCP servers are configured, they work the same as Claude Code.

## Fallback

If agents don't work (older Gemini CLI version), use `workflow.md` directly:
```bash
gemini "Follow .agents/qa-scan/workflow.md to QA scan issue SKIN-101"
```
