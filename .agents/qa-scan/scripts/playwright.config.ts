import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '../evidence',
  outputDir: '../evidence/results',

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
    ['json', { outputFile: '../evidence/results.json' }],
    ['html', { open: 'never', outputFolder: '../evidence/html-report' }],
  ],
});
