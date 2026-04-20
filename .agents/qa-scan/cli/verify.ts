import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { $ } from 'bun';

export async function verify() {
  const agentsDir = dirname(import.meta.dir);
  const workspace = dirname(dirname(dirname(agentsDir)));

  let errors = 0;
  let warnings = 0;

  console.log('=== QA Scan Environment Check ===\n');

  // Core deps
  console.log('--- Core ---');
  if (await checkCommand('bun --version')) {
    console.log('✓ Bun');
  } else {
    console.log('✗ Bun not installed');
    errors++;
  }

  if (await checkPlaywright(agentsDir)) {
    console.log('✓ Playwright');
  } else {
    console.log('✗ Playwright not installed');
    errors++;
  }

  // Config
  console.log('\n--- Config ---');
  errors += checkFile(join(agentsDir, 'config/qa.config.yaml'), 'qa.config.yaml');
  errors += checkFile(join(agentsDir, 'workflow.md'), 'workflow.md');
  errors += checkFile(join(agentsDir, 'scripts/playwright.config.ts'), 'playwright.config.ts');

  // Adapters
  console.log('\n--- Adapters ---');
  warnings += checkFile(join(workspace, '.claude/skills/qa-scan/SKILL.md'), 'Claude skill', true);
  warnings += checkFile(join(workspace, '.antigravity/qa-scan.md'), 'Antigravity', true);

  // Claude agents
  console.log('\n--- Claude Agents ---');
  const agents = [
    'qa-orchestrator',
    'qa-issue-analyzer',
    'qa-code-scout',
    'qa-flow-analyzer',
    'qa-test-generator',
    'qa-test-runner',
    'qa-coverage-verifier',
    'qa-report-synthesizer',
  ];
  for (const a of agents) {
    const result = checkFile(join(workspace, `.claude/agents/${a}.md`), a, true);
    warnings += result;
  }

  // Gemini agents
  console.log('\n--- Gemini Agents ---');
  for (const a of agents) {
    const result = checkFile(join(workspace, `.gemini/agents/${a}.md`), `${a} (gemini)`, true);
    warnings += result;
  }

  // Gemini commands
  console.log('\n--- Gemini Commands ---');
  warnings += checkFile(join(workspace, '.gemini/commands/qa-scan.toml'), '/qa-scan (gemini)', true);

  // Results folder
  console.log('\n--- Results ---');
  const qaResults = join(workspace, 'qa-results');
  errors += checkFile(qaResults, 'qa-results/', false, true);
  warnings += checkFile(join(qaResults, 'qa-tracker.json'), 'qa-tracker.json', true);
  warnings += checkFile(join(qaResults, 'hotspot-memory.json'), 'hotspot-memory.json', true);

  // Summary
  console.log('\n========================');
  if (errors === 0 && warnings === 0) {
    console.log('✓ All checks passed');
  } else if (errors === 0) {
    console.log(`⚠ ${warnings} warnings (run: bunx qa-scan install)`);
  } else {
    console.log(`✗ ${errors} errors, ${warnings} warnings`);
    process.exit(1);
  }
}

async function checkCommand(cmd: string): Promise<boolean> {
  try {
    const parts = cmd.split(' ');
    await $`${parts}`.quiet();
    return true;
  } catch {
    return false;
  }
}

async function checkPlaywright(cwd: string): Promise<boolean> {
  try {
    await $`npx playwright --version`.cwd(cwd).quiet();
    return true;
  } catch {
    return false;
  }
}

function checkFile(path: string, name: string, warn = false): number {
  const exists = existsSync(path);
  if (exists) {
    console.log(`✓ ${name}`);
    return 0;
  } else {
    console.log(`${warn ? '⚠' : '✗'} ${name} missing`);
    return 1;
  }
}
