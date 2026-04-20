import { dirname } from 'path';
import { loadConfig, type RepoConfig } from './config';
import { isCacheValid, loadRoadmap } from './cache';

export async function status() {
  const agentsDir = dirname(import.meta.dir);
  const workspace = dirname(dirname(agentsDir));

  console.log('=== QA Scan Status ===\n');

  const config = loadConfig(agentsDir);
  if (!config || !config.repos) {
    console.log('No repos configured in qa.config.yaml');
    return;
  }

  const entries = Object.entries(config.repos);
  if (entries.length === 0) {
    console.log('No repos configured');
    return;
  }

  for (const [key, repoConfig] of entries) {
    const repo = { key, ...repoConfig } as RepoConfig;
    const roadmap = loadRoadmap(repo, workspace);

    if (!roadmap) {
      console.log(`${key}: ✗ Not analyzed`);
      continue;
    }

    const stale = !isCacheValid(repo, workspace);
    const date = new Date(roadmap.analyzed_at).toLocaleDateString();
    const domain = roadmap.domain || 'generic';

    console.log(`${key}: ${stale ? '⚠ Stale' : '✓ Fresh'} | ${domain} | ${date}`);

    if (roadmap.critical_flows?.length) {
      console.log(`  Flows: ${roadmap.critical_flows.map(f => f.name).join(', ')}`);
    }
  }

  console.log('\nRun `bunx qa-scan analyze` to refresh stale roadmaps.');
}
