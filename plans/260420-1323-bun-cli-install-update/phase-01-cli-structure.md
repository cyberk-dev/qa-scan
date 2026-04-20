# Phase 1: CLI Structure

## Overview
- **Priority:** P1
- **Status:** pending
- **Effort:** 30m

## Files to Create/Modify

| File | Action |
|------|--------|
| `cli/index.ts` | Create - CLI entry point |
| `package.json` | Modify - add bin field |
| `.version` | Create - version tracking |

## Implementation

### 1. Update package.json

```json
{
  "name": "@cyberk/qa-scan",
  "version": "3.0.0",
  "bin": {
    "qa-scan": "./cli/index.ts"
  },
  "type": "module",
  "scripts": {
    "setup": "bun run cli/index.ts install",
    "verify": "bun run cli/index.ts verify"
  }
}
```

### 2. Create cli/index.ts

```typescript
#!/usr/bin/env bun

import { install } from './install';
import { update } from './update';
import { verify } from './verify';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';

const VERSION = readFileSync(join(dirname(import.meta.dir), '.version'), 'utf-8').trim();

const [cmd] = process.argv.slice(2);

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
```

### 3. Create .version

```
3.0.0
```

## Todo

- [ ] Update package.json with bin field
- [ ] Create cli/index.ts entry point
- [ ] Create .version file
- [ ] Test: `bun run cli/index.ts --version`

## Success Criteria

- `bun run cli/index.ts` shows help
- `bun run cli/index.ts --version` shows 3.0.0
