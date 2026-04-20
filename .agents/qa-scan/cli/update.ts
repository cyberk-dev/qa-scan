import { existsSync, writeFileSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { syncAgents, syncCommands, syncReferences, writeSkill, writeAntigravity } from './shared';

export async function update() {
  const agentsDir = dirname(import.meta.dir);
  const workspace = dirname(dirname(dirname(agentsDir)));

  // Check if installed
  const installedVersionFile = join(agentsDir, '.installed-version');
  const currentVersionFile = join(agentsDir, '.version');

  if (!existsSync(installedVersionFile)) {
    console.log('qa-scan not installed. Run: bunx qa-scan install');
    process.exit(1);
  }

  const installedVersion = readFileSync(installedVersionFile, 'utf-8').trim();
  const currentVersion = readFileSync(currentVersionFile, 'utf-8').trim();

  console.log('=== QA Scan Update ===');
  if (installedVersion !== currentVersion) {
    console.log(`Updating: v${installedVersion} → v${currentVersion}\n`);
  } else {
    console.log(`Version: v${currentVersion} (no version change)\n`);
  }

  // Sync agents
  console.log('→ Syncing Claude agents...');
  syncAgents(agentsDir, join(workspace, '.claude/agents'));

  console.log('→ Syncing Gemini agents...');
  syncAgents(agentsDir, join(workspace, '.gemini/agents'));

  // Sync SKILL.md
  console.log('→ Syncing Claude skill...');
  writeSkill(workspace);

  // Sync Gemini commands
  console.log('→ Syncing Gemini commands...');
  syncCommands(agentsDir, join(workspace, '.gemini/commands'));

  // Sync Antigravity
  console.log('→ Syncing Antigravity adapter...');
  writeAntigravity(workspace);

  // Sync references
  console.log('→ Syncing references...');
  syncReferences(agentsDir, join(workspace, 'references'));

  // Update installed version
  writeFileSync(installedVersionFile, currentVersion);

  console.log('\n✓ Update complete.');
  console.log('  Skipped: config/qa.config.yaml (preserved)');
  console.log('  Skipped: qa-results/ (preserved)');
}
