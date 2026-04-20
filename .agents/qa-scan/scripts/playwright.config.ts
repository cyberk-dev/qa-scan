import { defineConfig } from '@playwright/test';

// Results dir from qa.config.yaml → defaults.results_dir
// Env var QA_RESULTS_DIR set by orchestrator at runtime
const resultsDir = process.env.QA_RESULTS_DIR || '../../qa-results';
const repoKey = process.env.QA_REPO_KEY || 'default';
const issueId = process.env.QA_ISSUE_ID || 'test';

export default defineConfig({
  testDir: `${resultsDir}/${repoKey}/${issueId}`,
  outputDir: `${resultsDir}/${repoKey}/${issueId}/results`,

  // Auth: global setup runs login + saves storage state (if configured)
  globalSetup: process.env.QA_AUTH_STRATEGY === 'storage-state'
    ? './auth-setup.ts'
    : undefined,

  use: {
    video: 'on',
    trace: 'on',
    screenshot: 'on',
    baseURL: process.env.QA_BASE_URL || 'http://localhost:3001',
    viewport: { width: 1280, height: 720 },

    // Reuse auth state from global setup (if configured)
    ...(process.env.QA_AUTH_STRATEGY === 'storage-state' && {
      storageState: './auth-state.json',
    }),
  },

  reporter: [
    ['json', { outputFile: `${resultsDir}/${repoKey}/${issueId}/results.json` }],
    ['html', { open: 'never', outputFolder: `${resultsDir}/${repoKey}/${issueId}/html-report` }],
  ],
});
