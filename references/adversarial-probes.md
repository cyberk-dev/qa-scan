# Adversarial Probe Library

Pick probes relevant to the feature area. Run at least 2 before issuing PASS.

## Boundary Values

| Probe | Command Example |
|-------|----------------|
| Empty string | Submit form with all fields empty |
| Max length | Paste 10,000 char string into input |
| Special chars | `<script>alert(1)</script>`, `'; DROP TABLE--`, unicode `こんにちは` |
| Zero/negative | Enter 0, -1, -999 for numeric fields |
| Whitespace only | `"   "` (spaces only) in required fields |
| Null bytes | `\x00` in text inputs |

```bash
# Example: empty form submit
curl -s -X POST {base_url}/api/endpoint \
  -H 'Content-Type: application/json' \
  -d '{"field":""}' | jq .

# Example: XSS probe
curl -s "{base_url}/search?q=<script>alert(1)</script>" | grep -i "script"
```

## Rapid Interaction

| Probe | What to Check |
|-------|--------------|
| Double-click submit | Duplicate submission? Double charge? |
| Spam click 10x/1s | Rate limiting? Multiple records? |
| Tab rapidly through form | Focus trap? Skip validation? |
| Navigate away mid-submit | Orphan state? Pending request? |

```bash
# Example: double-submit detection
curl -s -X POST {base_url}/api/endpoint -d '{"data":"test"}' &
curl -s -X POST {base_url}/api/endpoint -d '{"data":"test"}' &
wait
# Check: did it create 2 records or deduplicate?
```

## Navigation State

| Probe | What to Check |
|-------|--------------|
| Browser back after submit | Stale data? Re-submission? |
| Refresh mid-operation | State lost? Error? |
| Two tabs same page | Conflicts? Stale reads? |
| Deep link without auth | Redirect to login? 401? |

```bash
# Example: deep link without auth
curl -s -o /dev/null -w "%{http_code}" {base_url}/protected/page
# Expected: 302 or 401, NOT 200
```

## Network Resilience

| Probe | Playwright Command |
|-------|--------------------|
| Slow 3G | `await page.route('**/*', r => setTimeout(() => r.continue(), 3000))` |
| Offline mid-request | `await page.context().setOffline(true)` after click |
| Large response | What happens with 1000+ items in list? |
| API timeout | Does loading state show? Does it recover? |

```bash
# Example: slow response check
curl -s --max-time 2 {base_url}/api/slow-endpoint
# If timeout: does UI show error state?
```

## Auth Edge Cases

| Probe | What to Check |
|-------|--------------|
| Expired session | Proper redirect to login? |
| No cookie/token | 401 or redirect? Not 500 |
| Wrong role (admin page) | 403? Not blank page |
| Malformed token | Graceful error? Not crash |

```bash
# Example: no auth header
curl -s -o /dev/null -w "%{http_code}" {base_url}/api/protected
# Expected: 401 or 403

# Example: malformed token
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer invalid-garbage-token" \
  {base_url}/api/protected
# Expected: 401, NOT 500
```

## Data Edge Cases

| Probe | What to Check |
|-------|--------------|
| Entity with 0 children | Empty list handled? |
| Non-existent ID (404) | Error state shown? |
| Malformed API response | Graceful error? |
| Unicode in all fields | Render correctly? |
| Very long names/titles | Truncation? Overflow? |

```bash
# Example: non-existent product
curl -s {base_url}/api/products/DOES-NOT-EXIST-99999 | jq .
# Expected: 404 with error message, NOT 500

# Example: product with no ingredients
curl -s {base_url}/api/products/{id-with-no-ingredients} | jq .
# Check: ingredients array exists (even if empty), no crash
```

## API Contract Verification

| Probe | What to Check |
|-------|--------------|
| Response shape | All documented fields present? |
| Content-Type header | Correct MIME type? |
| Error response shape | Consistent error format? |
| Pagination edge | Page 0? Page MAX_INT? |

```bash
# Example: verify response shape
curl -s {base_url}/api/endpoint | jq '{
  has_id: has("id"),
  has_name: has("name"),
  has_status: has("status")
} | if (.has_id and .has_name and .has_status) then "PASS" else "FAIL: missing fields" end'
```
