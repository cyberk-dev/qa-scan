import { existsSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { loadConfig, type RepoConfig } from './config';
import { isCacheValid, getCachedCommit, loadRoadmap, writeRoadmap } from './cache';
import { detectDomain } from './domain-detector';
import { extractFlows } from './flow-extractor';
import { generateRoadmap } from './roadmap-generator';

function parseArg(args: string[], flag: string): string | undefined {
  const idx = args.indexOf(flag);
  return idx !== -1 && args[idx + 1] ? args[idx + 1] : undefined;
}

export async function analyze(args: string[]) {
  const repoKey = parseArg(args, '--repo');
  const force = args.includes('--force');

  const agentsDir = dirname(import.meta.dir);
  const workspace = dirname(dirname(agentsDir));

  console.log('=== QA Scan Analyze ===\n');

  const config = loadConfig(agentsDir);
  if (!config || !config.repos) {
    console.log('No repos configured in qa.config.yaml');
    return;
  }

  const repoEntries = repoKey
    ? [[repoKey, config.repos[repoKey]] as const].filter(([, v]) => v)
    : Object.entries(config.repos);

  if (repoEntries.length === 0) {
    console.log(repoKey ? `Repo "${repoKey}" not found in config` : 'No repos configured');
    return;
  }

  for (const [key, repoConfig] of repoEntries) {
    const repo = { key, ...repoConfig } as RepoConfig;
    console.log(`→ Analyzing ${key} (${repo.path})...`);

    if (!force && isCacheValid(repo, workspace)) {
      const commit = getCachedCommit(repo, workspace);
      console.log(`  ✓ Cache valid (commit: ${commit?.slice(0, 7)})`);
      continue;
    }

    try {
      const repoPath = join(workspace, repo.path);
      const domain = await detectDomain(repoPath);
      console.log(`  Domain: ${domain.domain} (confidence: ${(domain.confidence * 100).toFixed(0)}%)`);

      const flows = await extractFlows(repoPath, domain);
      console.log(`  Flows: ${flows.length} critical flows detected`);

      const roadmap = generateRoadmap(repo, domain, flows, workspace);
      writeRoadmap(repo, roadmap, workspace);

      console.log(`  ✓ Roadmap generated`);
    } catch (err) {
      console.error(`  ✗ Analysis failed: ${(err as Error).message}`);
    }
  }

  console.log('\nDone. Run `bunx qa-scan status` to check freshness.');
}
