#!/usr/bin/env bun

import { install } from './install';
import { update } from './update';
import { verify } from './verify';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';

const agentsDir = dirname(import.meta.dir);
const VERSION = readFileSync(join(agentsDir, '.version'), 'utf-8').trim();

const [cmd] = process.argv.slice(2);

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

Options:
  --version Show version
`);
  }
}

main().catch(console.error);
