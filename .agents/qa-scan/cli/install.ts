import { $ } from 'bun';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { syncAgents, syncCommands, syncReferences, writeSkill, writeAntigravity } from './shared';

export async function install() {
  const agentsDir = dirname(import.meta.dir);
  const workspace = dirname(dirname(agentsDir));

  console.log('=== QA Scan Setup ===\n');

  // 1. Install deps
  console.log('→ Installing dependencies...');
  try {
    await $`bun install`.cwd(agentsDir).quiet();
    console.log('  ✓ Dependencies installed');
  } catch (err) {
    console.error('  ✗ Failed to install dependencies:', (err as Error).message);
    process.exit(1);
  }

  console.log('→ Installing Playwright...');
  try {
    await $`npx playwright install chromium`.cwd(agentsDir).quiet();
    console.log('  ✓ Playwright installed');
  } catch (err) {
    console.error('  ✗ Failed to install Playwright:', (err as Error).message);
    process.exit(1);
  }

  // 2. Create qa-results folder
  const qaResults = join(workspace, 'qa-results');
  mkdirSync(qaResults, { recursive: true });

  const trackerFiles = ['qa-tracker.json', 'hotspot-memory.json', 'flaky-memory.json'];
  for (const file of trackerFiles) {
    const path = join(qaResults, file);
    if (!existsSync(path)) writeFileSync(path, '[]');
  }
  console.log(`  ✓ Results folder: ${qaResults}`);

  // 3. Sync all adapters and agents
  console.log('→ Creating Claude skill...');
  writeSkill(workspace);

  console.log('→ Installing Claude agents...');
  syncAgents(agentsDir, join(workspace, '.claude/agents'));

  console.log('→ Installing Gemini agents...');
  syncAgents(agentsDir, join(workspace, '.gemini/agents'));

  console.log('→ Installing Gemini commands...');
  syncCommands(agentsDir, join(workspace, '.gemini/commands'));

  console.log('→ Creating Antigravity adapter...');
  writeAntigravity(workspace);

  console.log('→ Syncing references...');
  syncReferences(agentsDir, join(workspace, 'references'));

  // 4. Write installed version
  const version = readFileSync(join(agentsDir, '.version'), 'utf-8').trim();
  writeFileSync(join(agentsDir, '.installed-version'), version);

  console.log('\n✓ QA Scan installed successfully.');
  console.log('  Run: bunx qa-scan verify');
}
