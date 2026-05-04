# Non-Interactive Subprocess Rule

**Scope:** All `qa-*` sub-agents (every agent except `qa-orchestrator`).
**Intent:** Sub-agents run inside subprocess contexts (Claude `Task()` subagent runtime, or `gemini -p` subprocess in the bash orchestrator) where there is no interactive TTY. Blocking on user input causes the parent to hang indefinitely.

---

## Hard Rules

1. **NEVER call `AskUserQuestion`** (Claude) or any equivalent interactive prompt tool.
2. **NEVER write a question to stdout and `read` from stdin.** stdin is closed in subprocess context.
3. **NEVER print "Please confirm" / "Type Y to continue" prompts** expecting a user reply within your session.
4. **NEVER `sleep` waiting for an external file to appear** unless covered by an explicit timeout < 60s and a fallback path.

The orchestrator (`qa-orchestrator` for Claude, `scripts/qa-scan-gemini.sh` for Gemini) is the **only** layer allowed to interact with the user.

---

## How to Escalate Properly

When you need clarification, confirmation, or a destructive-action approval:

1. **Stop your work.** Do not proceed past the point where the question matters.
2. **Write a question payload** to your output file (the same JSON file you'd write on success), under a top-level `escalation` key:
   ```json
   {
     "status": "NEEDS_CONTEXT",
     "escalation": {
       "template": "T2",                // optional — references/templates/T<N>.md
       "question": "Issue analysis confidence is 0.42. Continue with low confidence or paste richer issue text?",
       "options": [
         {"id": "continue",  "label": "Tiếp tục với kịch bản hiện tại"},
         {"id": "rewrite",   "label": "Tôi paste kịch bản chi tiết hơn"},
         {"id": "abort",     "label": "Huỷ scan"}
       ],
       "data": { /* anything orchestrator needs to re-spawn you */ }
     }
   }
   ```
3. **Return the status block** per `references/status-protocol.md`:
   ```
   **Status:** NEEDS_CONTEXT
   **Summary:** <one sentence why>
   **Escalation:** see <output_file>
   ```
4. **Exit immediately.** Do not attempt to wait for a reply.

---

## Same Pattern for `BLOCKED`

If a destructive precondition fails (e.g. monorepo with no manifest, port occupant cannot be killed, missing required secret) → status=`BLOCKED`, embed `escalation.template` (T1–T7) in JSON output, exit.

The orchestrator parses the escalation, presents options to the user via the rule in `.claude/rules/qa-scan/vi-escalation.md` (or its bash equivalent), gets the answer, then re-spawns you with the answer in the input block. Max 3 retries per step before the orchestrator gives up.

---

## CI / Non-Interactive Mode

When `QA_SCAN_NONINTERACTIVE=1` is set in the environment:
- Orchestrator does NOT prompt the user; auto-aborts on any `BLOCKED` / `NEEDS_CONTEXT`.
- Sub-agents still emit the same `escalation` payload — the orchestrator just routes it to a CI report instead of interactive prompt.
- Sub-agents do NOT need to detect this flag themselves; behavior is identical from their perspective.

---

## Rationale

Sub-agents in `gemini -p "$prompt"` run as one-shot subprocesses with closed stdin. Sub-agents spawned via Claude `Task()` run in an isolated runtime that surfaces output back to the parent only after the agent emits its final response — there is no streaming dialog channel. In both cases, asking for input mid-session simply hangs the agent until parent timeout.

Pushing all interaction up to the orchestrator keeps:
- Sub-agent prompts narrow (no UX boilerplate)
- Escalation paths uniform (every step uses the same JSON shape)
- Resumability (orchestrator can re-spawn with answer; sub-agent reads inputs fresh)
- CI-compatibility (one env var disables all interactivity globally)
