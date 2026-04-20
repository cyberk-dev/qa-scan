# Scout Code — Find Relevant Files

You are scouting the codebase to find files relevant to a specific feature area.

## Input

- **feature_area**: e.g., "Product Detail", "Authentication", "Dashboard"
- **test_scenarios**: from analyze-issue step
- **repo config**: path, branch, gitnexus flag

## Strategy

### With GitNexus (preferred — if `gitnexus: true` in repo config)

Use GitNexus MCP tools for semantic code understanding:

1. **Query symbols:**
   ```
   gitnexus_query({query: "{feature_area keywords}"})
   ```
   Find functions, components, routes related to the feature.

2. **Trace impact (blast radius):**
   ```
   gitnexus_impact({target: "{key_symbol}", direction: "upstream"})
   ```
   Find all callers and consumers. Prioritize by distance:
   - **d=1 (direct):** MUST test — functions that directly call/use the changed code
   - **d=2 (indirect):** SHOULD test — callers of callers
   - **d=3+ (transitive):** OPTIONAL — regression scope

3. **Get full context:**
   ```
   gitnexus_context({name: "{symbol}"})
   ```
   360° view: callers, callees, process participation.

4. **Detect changes (if branch available):**
   ```
   gitnexus_detect_changes({base_ref: "main"})
   ```
   Get list of changed symbols in the branch vs main.

### Without GitNexus (fallback)

1. **Search routes:** Grep for feature area keywords in routing files
   - Next.js: `app/` directory structure
   - React Router: route definitions

2. **Search components:** Glob for component names matching feature area
   - `**/*product*detail*` or `**/*auth*`

3. **Search API handlers:** Grep for endpoint paths
   - `/api/products`, `/api/auth`

4. **Search shared utils:** Grep for business logic functions

## Output Format

List relevant files with brief purpose:

```
## Relevant Files

### Routes
- `apps/web/app/products/[id]/page.tsx` — Product detail page (main entry)

### Components
- `apps/web/src/features/product/components/ingredient-list.tsx` — Ingredient display
- `apps/web/src/features/product/components/analysis-card.tsx` — AI analysis card

### API
- `packages/api/src/routers/product.ts` — Product API endpoints

### Shared
- `packages/api/src/services/product-analysis.ts` — Analysis business logic
```

## Rules

1. **Prioritize by test relevance:** route files > page components > API handlers > utils
2. **Include max 10 files** — focus on most relevant
3. **Note file purpose** — brief description of what each file does
4. **Flag generated/config files** — these are less useful for test context
