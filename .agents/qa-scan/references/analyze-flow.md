# Analyze Flow — Extract Testable States from Code

You are extracting testable states, branches, and user actions from source code files.

## React / Next.js State Patterns

### Loading States
```tsx
if (isLoading) return <Skeleton />
if (isPending) return <Spinner />
{status === 'loading' && <LoadingIndicator />}
// useQuery: isLoading, isFetching
// useMutation: isPending
// useSuspenseQuery: Suspense boundary
// React.lazy: Suspense fallback
```

### Error States
```tsx
if (error) return <ErrorMessage error={error} />
if (isError) return <Alert variant="error" />
{status === 'error' && <ErrorBanner />}
// try/catch blocks in event handlers
// Error boundaries (ErrorBoundary component)
// .catch() on promises
```

### Empty States
```tsx
if (!data || data.length === 0) return <EmptyState />
{items.length === 0 && <NoResults />}
{!product.ingredients?.length && <NoIngredients />}
// Null checks: if (!data) return null
// Optional chaining with fallback: data?.items ?? []
```

### Auth States
```tsx
if (!session) redirect('/login')
if (!isAuthenticated) return <LoginPrompt />
{user?.role === 'admin' && <AdminPanel />}
// Middleware auth checks
// Protected route wrappers
// Role-based conditional renders
```

### Success States
```tsx
// The "normal" render — data loaded, no errors
// Usually the longest render block
// Multiple sub-states within success:
{product.hasAnalysis && <AnalysisCard />}
{product.ingredients.length > 0 && <IngredientList />}
```

## API / Backend Patterns

### Error Responses
```ts
if (!found) return c.json({error: 'Not found'}, 404)
if (!valid) return c.json({error: 'Invalid'}, 400)
// Zod validation errors → 400/422
// Auth middleware → 401/403
```

### Success Variants
```ts
// Empty result: return c.json({data: []}, 200)
// Single item: return c.json({data: item}, 200)
// Paginated: return c.json({data, total, page}, 200)
```

## User Action Patterns

### Event Handlers (React)
```tsx
onClick={() => handleAction()}
onSubmit={handleSubmit}
onPress={handlePress}        // React Native
onChange={handleChange}
onBlur={handleBlur}          // Validation on blur
```

### Navigation
```tsx
router.push('/path')
router.replace('/path')
<Link href="/path">
redirect('/path')
```

### Mutations
```tsx
const { mutate } = useMutation({...})
// Each mutation = potential test:
//   1. Trigger mutation (click button)
//   2. Check optimistic update
//   3. Check success state
//   4. Check error state
```

## Extraction Rules

1. **Read the full file** — states hide in early returns at the top
2. **Trace custom hooks** — `useProductDetail()` may wrap `useQuery` with loading/error
3. **Check component props** — `isDisabled`, `isReadOnly`, `variant` create branches
4. **Look for guards** — early returns before main render are testable states
5. **Count conditional renders** — each `&&` or `? :` in JSX = potential test case
6. **Check error boundaries** — parent components may catch errors

## Priority Order (for test generation)

1. **Error states** — most likely to be untested, highest user impact
2. **Auth guards** — security-critical, must verify
3. **Empty states** — common UX gap
4. **Loading states** — usually quick but important for UX
5. **Success variants** — conditional renders within success path
6. **User actions** — onClick/onSubmit handlers
7. **Navigation** — route transitions
