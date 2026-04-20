import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '../evidence',
  outputDir: '../evidence/results',

  // CI optimization
  workers: process.env.CI ? 1 : undefined,
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,

  // Auth: global setup runs login + saves storage state (if configured)
  globalSetup: process.env.QA_AUTH_STRATEGY === 'storage-state'
    ? './auth-setup.ts'
    : undefined,

  use: {
    baseURL: process.env.QA_BASE_URL || 'http://localhost:3001',
    viewport: { width: 1280, height: 720 },

    // Artifact collection - optimized for CI
    video: process.env.CI ? 'retain-on-failure' : 'on',
    trace: process.env.CI ? 'on-first-retry' : 'on',
    screenshot: process.env.CI ? 'only-on-failure' : 'on',

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
