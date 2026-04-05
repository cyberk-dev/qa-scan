Run QA scan pipeline for the specified issue.

@qa-orchestrator Run QA scan pipeline for issue $ARGUMENTS. Read config from .agents/qa-scan/config/qa.config.yaml. Follow the full pipeline: analyze issue, scout code, analyze flow, generate test, run test, verify coverage, synthesize report. Post VERDICT at the end.
