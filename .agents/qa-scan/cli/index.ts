#!/usr/bin/env bun

import { install } from './install';
import { update } from './update';
import { verify } from './verify';
import { analyze } from './analyze';
import { status } from './status';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';

const agentsDir = dirname(import.meta.dir);
const VERSION = readFileSync(join(agentsDir, '.version'), 'utf-8').trim();

const [cmd, ...args] = process.argv.slice(2);

async function main() {
  switch (cmd) {
    case 'install':
      await install();
      break;
    case 'update':
      await update();
      break;
    case 'verify':
      await verify();
      break;
    case 'analyze':
      await analyze(args);
      break;
    case 'status':
      await status();
      break;
    case '--version':
    case '-v':
      console.log(`qa-scan v${VERSION}`);
      break;
    default:
      console.log(`
qa-scan CLI v${VERSION}

Commands:
  install   Full setup (deps + adapters + results folder)
  update    Sync agents/scripts/refs (skip config)
  verify    Check installation status
  analyze   Generate test roadmap for project
  status    Show roadmap freshness

Options:
  --version Show version

Analyze Options:
  --repo <key>  Analyze specific repo only
  --force       Ignore cache, re-analyze
`);
  }
}

main().catch(console.error);
