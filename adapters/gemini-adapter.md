# QA Scan — Gemini CLI

Automated QA pipeline with enforced agents. Agents installed to `.gemini/agents/qa-*.md` by `install.sh`.

## Usage
```
@qa-orchestrator scan SKIN-101 --repo my-project
```

Or let Gemini auto-delegate:
```
gemini "QA scan issue SKIN-101"
```

## Setup
```bash
bash install.sh    # copies agents to .gemini/agents/
```

## Reference
- Agents: `.gemini/agents/qa-*.md`
- Config: `config/qa.config.yaml`
- Prompts: `references/`
- Evidence: `evidence/`
- Guide: `references/gemini-adapter-guide.md`
