Run QA scan pipeline.

If no arguments provided, ask the user what they want to do:
1. Scan a specific issue (ask for issue ID)
2. Scan all QA issues in batch
3. Run quick test with test-app
4. Show current config
5. Verify setup

If arguments provided:
@qa-orchestrator Run QA scan pipeline for issue $ARGUMENTS. Read config from .agents/qa-scan/config/qa.config.yaml. Follow the full pipeline: analyze issue, scout code, analyze flow, generate test, run test, verify coverage, synthesize report.
