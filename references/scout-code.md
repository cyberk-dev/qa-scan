# Scout Code — Find Relevant Files + Flows + Routes + Shapes (v4 unified)

You are scouting the codebase to find files, flows, API routes, and response shapes relevant to a specific feature area. **v4: merged former `analyze-flow.md` logic here.**

## Input

- **feature_area**: e.g., "Product Detail", "Authentication"
- **test_scenarios**: from analyze-issue step
- **repo config**: path, branch, gitnexus flag
- **project_context**: from qa-context-extractor

## Output JSON Schema

```json
{
  "files": [{"path": "...", "purpose": "...", "confidence": 0.0}],
  "flows": [{"name": "...", "steps": [...], "entry": "...", "module": "..."}],
  "routes": [{"path": "/api/x", "handler": "...", "middleware": [...], "shape": {...}}],
  "test_matrix": {
    "states": [{"name": "loading|error|empty|auth|success", "trigger": "...", "file": "..."}],
    "actions": [{"name": "onClick|onSubmit|...", "handler": "...", "file": "..."}],
    "gaps": ["..."]
  }
}
```

---

## Strategy

### Phase A — With GitNexus (preferred)

1. **Query symbols:**
   ```
   gitnexus_query({query: "{feature_area keywords}"})
   ```
   Returns processes (flows) + symbols ranked by relevance.

2. **Trace impact:**
   ```
   gitnexus_impact({target: "{key_symbol}", direction: "upstream"})
   ```
   Prioritize: d=1 MUST test, d=2 SHOULD, d=3+ optional.

3. **360° context:**
   ```
   gitnexus_context({name: "{symbol}"})
   ```

4. **Routes:**
   ```
   gitnexus_route_map({feature: "..."})
   gitnexus_shape_check({route: "/api/x"})
   ```
   Extract `{path, handler, middleware, responseKeys}` directly.

5. **Detect branch changes (optional):**
   ```
   gitnexus_detect_changes({base_ref: "main"})
   ```

### Phase B — Without GitNexus (fallback)

1. **Files:** Grep keywords in `app/`, `pages/`, `src/**`; Glob component patterns
2. **Flows:** parse states/actions from code (see "Flow Extraction Fallback" below)
3. **Routes:** grep `route()`, `app.get/post`, Next.js route handlers; extract middleware chains by pattern `withAuth(`, `withRateLimit(`
4. **Shapes:** grep `.json(`, `res.json(`, `NextResponse.json(` → extract top-level keys

### Phase C — Merge

Combine Phase A + B outputs. Deduplicate by file path. Prefer GitNexus confidence over fallback.

---

## Flow Extraction Fallback (from former analyze-flow.md)

Read top 3-5 relevant files. Extract states + actions.

### React / Next.js State Patterns

**Loading:**
```tsx
if (isLoading) return <Skeleton />
// useQuery.isLoading, useMutation.isPending, Suspense fallback
```

**Error:**
```tsx
if (error) return <ErrorMessage />
// try/catch, ErrorBoundary, .catch()
```

**Empty:**
```tsx
if (!data?.length) return <EmptyState />
```

**Auth:**
```tsx
if (!session) redirect('/login')
// middleware auth, role-based renders
```

**Success (branching):**
```tsx
{product.hasAnalysis && <AnalysisCard />}
{items.length > 0 && <List />}
```

### API / Backend Patterns

**Errors:**
```ts
if (!found) return c.json({error}, 404)
// Zod → 400/422, auth → 401/403
```

**Success variants:**
```ts
// empty [], single item, paginated {data, total, page}
```

### User Actions

```tsx
onClick, onSubmit, onPress, onChange, onBlur
router.push/replace, <Link>, redirect
useMutation mutate → optimistic/success/error
```

### Extraction Rules

1. Read full file — states hide in early returns at top
2. Trace custom hooks — `useProductDetail()` may wrap useQuery
3. Check props — `isDisabled`, `isReadOnly`, `variant` create branches
4. Guards = testable states (early returns)
5. Count `&&` / `? :` in JSX = potential test cases

---

## Priority (test generation)

1. **Error states** — most likely untested, highest impact
2. **Auth guards** — security-critical
3. **Empty states** — common UX gap
4. **Loading states** — important for UX
5. **Success variants** — conditional renders
6. **User actions**
7. **Navigation**

---

## Rules

1. Prioritize: routes > pages > API handlers > utils
2. Max 10 files — focus relevance
3. Include file purpose + confidence
4. Flag generated/config files (skip)
5. If GitNexus processes=0 AND fallback finds 0 files → DONE_WITH_CONCERNS (empty scout)
