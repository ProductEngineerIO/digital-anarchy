# Story 1.1: Vercel Environment Configuration & Redis Key-Prefix Isolation

Status: ready-for-dev

## Story

As an **operator**,
I want Preview and Production environments with isolated Redis namespaces,
So that QA testing never pollutes production cache data.

## Acceptance Criteria

1. **Given** the Vercel project is configured
   **When** I set environment variables (API keys, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`) scoped to Preview and Production
   **Then** each environment uses its own variable values independently
   **And** API keys are never committed to source control (verified by grep of `.env*` patterns in `.gitignore`)

2. **Given** the Redis client wrapper exists
   **When** a Preview deployment writes to Redis key `summaries:US`
   **Then** the actual Redis key is `qa:summaries:US`
   **And** a Production deployment writing the same logical key creates `prod:summaries:US`

3. **Given** the `prefixedKey()` wrapper is in place
   **When** CI runs a grep check for direct Redis calls bypassing the wrapper
   **Then** the check passes with zero violations (automated, not convention-dependent)

4. **Given** the environment is configured
   **When** a new contributor checks the repository
   **Then** `fork.env.example` documents all fork-specific environment variables with descriptions

## Scope Boundary

This story covers:
- Aligning the existing Redis prefix logic to the architecture spec (`prod:` / `qa:` prefixes)
- Creating `fork.env.example` for fork-specific env documentation
- Adding an automated grep guard to catch direct Redis calls bypassing the wrapper
- Verifying `.gitignore` covers all env file patterns

This story does NOT cover:
- CI pipeline setup (Story 1.2)
- Endpoint smoke testing (Story 1.3)
- Vercel dashboard configuration (manual operator task, documented in `fork.env.example`)
- Adding new API keys or changing upstream Redis consumers

## Tasks / Subtasks

- [ ] **Task 1: Align Redis prefix logic to architecture spec** (AC: #2)
  - [ ] 1.1 Modify `server/_shared/redis.ts` `getKeyPrefix()` to use `prod:` for production and `qa:` for non-production (see Implementation Spec below)
  - [ ] 1.2 Remove SHA-based prefix — the architecture specifies simple `prod:` / `qa:`, not `preview:{sha8}:`
  - [ ] 1.3 Export `prefixKey` as a named export (currently private) so tests and grep guards can reference it
  - [ ] 1.4 Add unit test in `server/_shared/redis.test.mjs` for prefix logic (production → `prod:`, preview → `qa:`, development → `qa:`, missing → `prod:`)
- [ ] **Task 2: Create automated grep guard for prefix enforcement** (AC: #3)
  - [ ] 2.1 Create `scripts/check-redis-prefix.sh` that greps `server/worldmonitor/` for direct Upstash REST URL usage or `fetch.*redis` patterns that bypass the wrapper
  - [ ] 2.2 The script should exit 0 if no violations found, exit 1 with descriptive output if violations detected
  - [ ] 2.3 Document that this script will be wired into CI in Story 1.2
- [ ] **Task 3: Create `fork.env.example`** (AC: #4)
  - [ ] 3.1 Create `fork.env.example` in the project root documenting all fork-specific environment variables
  - [ ] 3.2 Include: `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, `VITE_SENTRY_DSN` (future), fork-specific API keys if any, and reference to `.env.example` for upstream vars
  - [ ] 3.3 Add comments explaining Vercel env var scoping (Preview vs Production)
- [ ] **Task 4: Verify `.gitignore` env coverage** (AC: #1)
  - [ ] 4.1 Verify `.gitignore` includes `.env`, `.env.local`, `.env.*.local`, `fork.env`, `fork.env.local`
  - [ ] 4.2 Add any missing patterns
  - [ ] 4.3 Run `git grep -l 'UPSTASH_REDIS_REST_TOKEN\|UPSTASH_REDIS_REST_URL' -- ':!*.example' ':!*.md' ':!*.yaml'` to verify no real credentials in tracked files
- [ ] **Task 5: Document findings and update architecture** (AC: #1, #2)
  - [ ] 5.1 Update the architecture doc Redis process pattern example to match the actual code (current example shows `redis.get(prefixedKey(...))` but the real API is `getCachedJson(key)` which prefixes internally)
  - [ ] 5.2 Add a note in the architecture doc acknowledging the spec-to-implementation alignment completed in this story

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| ARCH decision: Data Architecture | Single Upstash instance with `qa:` / `prod:` key prefixes | [architecture.md lines 313-335](_spec/planning-artifacts/architecture.md#L313) |
| ARCH decision: Security | API keys stored exclusively in Vercel env vars | [architecture.md lines 340-345](_spec/planning-artifacts/architecture.md#L340) |
| Quick Reference | `Redis call? → prefixedKey() always` | [architecture.md line 462](_spec/planning-artifacts/architecture.md#L462) |
| Anti-pattern | `FLUSHDB`/`FLUSHALL` FORBIDDEN — use prefix-scoped SCAN+DEL | [architecture.md line 680](_spec/planning-artifacts/architecture.md#L680) |
| Fork tier | This story is **Tier 1** — no upstream file modifications except `server/_shared/redis.ts` (shared infrastructure, not fork code) | Epics definition |

### Current State Analysis

**`server/_shared/redis.ts` (122 LOC):**
- `getKeyPrefix()` (lines 7-12): Currently returns empty string for production, `{env}:{sha8}:` for preview/development
- `prefixKey()` (lines 15-19): Private function with cached prefix — called internally by all wrapper functions
- `getCachedJson(key)` (lines 21-36): GET via Upstash REST, 3s timeout
- `setCachedJson(key, value, ttl)` (lines 38-52): SET with EX via REST, 3s timeout, best-effort
- `getCachedJsonBatch(keys)` (lines 56-89): Pipeline GET for N keys
- `cachedFetchJson(key, ttl, fetcher)` (lines 97-122): Cache-aside with in-flight deduplication

**Key finding: All 53 server handler files already route through these wrapper functions.** No direct Redis calls exist outside `redis.ts`. The prefix enforcement is already structurally sound — the only issue is the prefix scheme doesn't match the architecture spec.

**Architecture spec says:** `prod:` for production, `qa:` for non-production
**Current code says:** empty string for production, `{env}:{sha}:` for non-production

### Implementation Spec: `getKeyPrefix()` Change

```typescript
// BEFORE (current code)
function getKeyPrefix(): string {
  const env = process.env.VERCEL_ENV;
  if (!env || env === 'production') return '';
  const sha = process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 8) || 'dev';
  return `${env}:${sha}:`;
}

// AFTER (aligned to architecture spec)
function getKeyPrefix(): string {
  const env = process.env.VERCEL_ENV;
  if (!env || env === 'production') return 'prod:';
  return 'qa:';
}
```

**Rationale for the change:**
1. The architecture doc specifies `prod:` / `qa:` — simple, deterministic, no SHA variance
2. SHA-based prefixes create cache fragmentation: every preview commit gets its own namespace, wasting the 10K commands/day budget
3. `prod:` prefix for production (instead of empty string) provides consistent key structure and makes it safe to inspect Redis keys (every key has an environment label)

**Migration note:** Existing production keys have NO prefix. After this change, production will use `prod:` prefix. This means the first deployment will effectively start with a cold cache. This is acceptable — all caches have TTLs and will repopulate naturally. No data migration needed.

**⚠️ CRITICAL: Do NOT add `as const` or change the return type.** The function returns `string`, keep it that way. The cached prefix in `prefixKey()` already handles memoization.

### Implementation Spec: Export `prefixKey`

```typescript
// BEFORE
let cachedPrefix: string | undefined;
function prefixKey(key: string): string {
  // ...
}

// AFTER — add export
let cachedPrefix: string | undefined;
export function prefixKey(key: string): string {
  // ...
}
```

This enables the grep guard script to verify that all Redis operations go through `prefixKey` and enables tests to import and validate prefix behavior directly.

### Implementation Spec: Redis Prefix Test

Create `server/_shared/redis.test.mjs` using the project's test pattern:

```javascript
import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';

describe('redis key prefix', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    // Restore env
    process.env = { ...originalEnv };
  });

  it('uses prod: prefix when VERCEL_ENV is production', async () => {
    process.env.VERCEL_ENV = 'production';
    // Import fresh module to reset cached prefix
    const { prefixKey } = await import('./redis.ts');
    assert.equal(prefixKey('summaries:US'), 'prod:summaries:US');
  });

  it('uses prod: prefix when VERCEL_ENV is missing', async () => {
    delete process.env.VERCEL_ENV;
    const { prefixKey } = await import('./redis.ts');
    assert.equal(prefixKey('summaries:US'), 'prod:summaries:US');
  });

  it('uses qa: prefix when VERCEL_ENV is preview', async () => {
    process.env.VERCEL_ENV = 'preview';
    const { prefixKey } = await import('./redis.ts');
    assert.equal(prefixKey('summaries:US'), 'qa:summaries:US');
  });

  it('uses qa: prefix when VERCEL_ENV is development', async () => {
    process.env.VERCEL_ENV = 'development';
    const { prefixKey } = await import('./redis.ts');
    assert.equal(prefixKey('summaries:US'), 'qa:summaries:US');
  });
});
```

**⚠️ CRITICAL: Module-level `cachedPrefix` caching issue.** The `cachedPrefix` variable is module-scoped and memoized. Dynamic `import()` in tests may return the cached module. Solutions:
1. Use `tsx` with `--import` to get fresh modules (preferred — matches fork test pattern)
2. OR: Export a `_resetPrefixCache()` test helper that sets `cachedPrefix = undefined`
3. OR: Test `getKeyPrefix()` directly by also exporting it

**Recommended approach:** Export `getKeyPrefix()` as well (for testability), and test it directly. The caching in `prefixKey()` is an optimization detail — testing the prefix derivation logic is what matters.

### Implementation Spec: Grep Guard Script

Create `scripts/check-redis-prefix.sh`:

```bash
#!/usr/bin/env bash
# Checks that no server handler bypasses the Redis wrapper in server/_shared/redis.ts
# All Redis access must go through getCachedJson/setCachedJson/cachedFetchJson/getCachedJsonBatch

set -euo pipefail

violations=0

# Check for direct Upstash REST URL construction outside redis.ts
if grep -rn 'UPSTASH_REDIS_REST_URL\|UPSTASH_REDIS_REST_TOKEN' \
  server/worldmonitor/ server/cors.ts server/error-mapper.ts server/router.ts 2>/dev/null; then
  echo "❌ Direct Redis env var access found outside server/_shared/redis.ts"
  violations=$((violations + 1))
fi

# Check for fetch calls to redis-looking URLs outside redis.ts
if grep -rn 'fetch.*redis\|fetch.*upstash' \
  server/worldmonitor/ 2>/dev/null; then
  echo "❌ Direct fetch to Redis found outside server/_shared/redis.ts"
  violations=$((violations + 1))
fi

if [ "$violations" -eq 0 ]; then
  echo "✅ Redis prefix enforcement: all access routes through server/_shared/redis.ts"
  exit 0
else
  echo "❌ Found $violations Redis access violation(s)"
  exit 1
fi
```

### Implementation Spec: `fork.env.example`

```bash
# fork.env.example — Situation Monitor fork-specific environment variables
# See .env.example for upstream World Monitor variables (API keys, etc.)
#
# Vercel env var scoping:
# - Preview: Set in Vercel Dashboard → Settings → Environment Variables → Preview
# - Production: Set in Vercel Dashboard → Settings → Environment Variables → Production
# - Local dev: Copy this file to fork.env.local and fill in values

# ── Redis (required for caching) ──
# Upstash Redis REST API — shared instance, key-prefix-isolated per environment
# Production keys prefixed with "prod:", preview/development with "qa:"
UPSTASH_REDIS_REST_URL=https://your-instance.upstash.io
UPSTASH_REDIS_REST_TOKEN=your-token-here

# ── Monitoring (future — Epic 7) ──
# VITE_SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id

# ── Fork Identity ──
# No env vars needed — fork identity is compiled into src/fork/config.ts
# Theme tokens are inlined in src/fork/index.ts

# ── Notes ──
# • API keys for data sources (GROQ, ACLED, etc.) are upstream variables — see .env.example
# • VERCEL_ENV and VERCEL_GIT_COMMIT_SHA are auto-set by Vercel — do not configure manually
# • Redis prefix is determined automatically: prod: for production, qa: for everything else
```

### `.gitignore` Verification

Current patterns in `.gitignore` for env files:
- `.env` ✅
- `.env.local` ✅
- `.env.vercel-backup` ✅
- `.env.vercel-export` ✅

**Need to add:**
- `fork.env` — the actual fork env file (if someone creates it without `.local` suffix)
- `fork.env.local` — local development fork env

### `@upstash/redis` SDK Note

The `@upstash/redis` package is in `package.json` but is unused — all Redis operations use raw `fetch()` against the REST API. **Do NOT remove it in this story** — that's a separate clean-up task and removing a dependency is a different kind of change. Document it as future clean-up.

### Previous Story Intelligence (Story 0.1)

**Relevant learnings from the spike:**
- Test pattern: `npx tsx --test` for running `.test.mjs` files that import `.ts` sources
- Assertion style: `import { describe, it } from 'node:test'; import assert from 'node:assert/strict';`
- `tsc --noEmit` must pass after all changes
- `npm run build` must succeed
- The fork test at `src/fork/__tests__/` uses DOM mocking — server tests won't need that
- Code review caught first-pass implementation gaps — double-check all AC before submitting

**Git context (recent commits):**
- `e5bfa49` — chore: fix markdown lint issues and scope lint targets
- `2292e7b` — chore: remove duplicate '* 2' files and sync story 0.1 review fixes
- Story 0.1 PR created: `develop` → `main`

### Fork Development Contract (Definition of Done)

1. ✅ **Tier Declared** — Tier 1 (no upstream modifications beyond shared infrastructure)
2. ☐ **Graceful Degradation** — Redis wrapper already handles missing env vars (returns null/void)
3. N/A **Token-Only Styling** — No CSS changes in this story
4. N/A **Fork DOM Convention** — No DOM changes in this story
5. ☐ **Companion Tests** — `server/_shared/redis.test.mjs` for prefix logic, grep guard script
6. ☐ **No Upstream Mods** — Only `server/_shared/redis.ts` modified (shared infrastructure, agreed in architecture)

### Anti-Patterns

| Anti-Pattern | Why |
|---|---|
| Using `@upstash/redis` SDK instead of existing REST fetch pattern | Inconsistent with codebase — all 53 handlers use the REST wrapper |
| Adding `FLUSHDB` or clean-up commands | FORBIDDEN by architecture — nukes both environments |
| Putting env vars in `vercel.json` | Vercel dashboard only — `vercel.json` is committed to source control |
| Making `prefixKey` async | It's synchronous, cached, and called in hot path — keep it sync |
| Changing the wrapper function signatures | 53 consumer files depend on `getCachedJson(key)` / `setCachedJson(key, value, ttl)` — no breaking changes |
| Removing the SHA from the prefix AND keeping prefix cache | The `cachedPrefix` works because prefix is constant per deployment — this still holds with `prod:`/`qa:` |

### References

- [Architecture: Data Architecture Decision](_spec/planning-artifacts/architecture.md#L313) — Single Redis instance, prefix isolation
- [Architecture: API Key Management](_spec/planning-artifacts/architecture.md#L340) — Vercel env vars only
- [Architecture: Quick Reference Card](_spec/planning-artifacts/architecture.md#L459) — `Redis call? → prefixedKey() always`
- [Architecture: Redis Process Patterns](_spec/planning-artifacts/architecture.md#L570) — Correct vs. forbidden usage
- [Architecture: Anti-patterns](_spec/planning-artifacts/architecture.md#L680) — No FLUSHDB
- [Architecture: Fork Decision Map](_spec/planning-artifacts/architecture.md#L958) — Redis prefix = Tier 2
- [Architecture: Implementation Handoff](_spec/planning-artifacts/architecture.md#L1044) — Step 3: Configure Redis
- [Epics: Story 1.1](_spec/planning-artifacts/epics.md#L545) — Acceptance criteria
- [Epics: Epic 1 Overview](_spec/planning-artifacts/epics.md#L363) — FRs and NFRs covered
- [Epic 0 Retrospective](_spec/implementation-artifacts/epic-0-retro-2026-02-26.md) — Lessons from spike
- Source: `server/_shared/redis.ts` — Current Redis wrapper implementation (122 LOC)

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### Change Log

### File List
