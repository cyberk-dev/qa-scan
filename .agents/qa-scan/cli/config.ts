import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { parse as parseYaml } from 'yaml';

export interface RepoConfig {
  key: string;
  path: string;
  base_url?: string;
  source?: 'linear' | 'github';
  project_key?: string;
  repo?: string;
  branch?: string;
  gitnexus?: boolean;
  auth?: {
    strategy?: 'skip' | 'storage-state';
  };
}

export interface QAConfig {
  repos: Record<string, Omit<RepoConfig, 'key'>>;
  results_dir?: string;
}

export function loadConfig(agentsDir: string): QAConfig | null {
  const configPath = join(agentsDir, 'config/qa.config.yaml');

  if (!existsSync(configPath)) {
    return null;
  }

  const content = readFileSync(configPath, 'utf-8');
  return parseYaml(content) as QAConfig;
}
