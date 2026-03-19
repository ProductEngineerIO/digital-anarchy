# Story 5.5: E2E Test Suite and Smoke Test Validation

Status: ready-for-dev

## Story

As an **operator**,
I want the E2E test suite and endpoint smoke tests to pass on the sync branch,
So that I can confidently merge into `develop` and deploy to Preview.

## Acceptance Criteria

1. **Given** the upstream-sync branch with all previous story fixes
   **When** I run the Playwright E2E suite
   **Then** all existing tests pass (new upstream E2E tests documented if added)

2. **Given** the endpoint smoke test script
   **When** I run it against local dev
   **Then** all endpoint routes resolve (new upstream routes included)

3. **Given** upstream added new E2E specs
   **When** I review `e2e/` for new test files
   **Then** new tests are catalogued and any fork-specific adjustments are noted

## Scope Boundary

This story covers:
- Running the full Playwright E2E test suite
- Running endpoint smoke tests against local dev
- Cataloguing new E2E test files added by upstream
- Triaging and fixing test failures caused by fork divergence
- Documenting test results including any skipped or quarantined tests

This story does NOT cover:
- Build fixes (Story 5-2)
- Fork branding visual verification (Story 5-4 — must be done first)
- Merging into `develop` or deploying (Story 5-6)
- Writing new fork-specific E2E tests (future epic work)

## Tasks / Subtasks

- [ ] **Task 1: Run Playwright E2E suite** (AC: #1)
  - [ ] 1.1 Start dev server: `make dev`
  - [ ] 1.2 Run full suite: `npx playwright test`
  - [ ] 1.3 Capture results: total tests, passed, failed, skipped
  - [ ] 1.4 For each failure, categorize: fork-specific divergence / upstream regression / env-var-dependent / flaky
  - [ ] 1.5 Fix fork-specific failures (e.g., tests that check titles, branding, or fork-modified UI)

- [ ] **Task 2: Run endpoint smoke tests** (AC: #2)
  - [ ] 2.1 Run endpoint smoke test script against local dev (if `scripts/validate-endpoints.sh` exists from Story 1-3, use it; otherwise manually hit key routes)
  - [ ] 2.2 Verify all existing API endpoint routes return non-error responses
  - [ ] 2.3 Verify new upstream API routes are accessible (Forecast, MCP, Sanctions, Radiation, Thermal, etc.)
  - [ ] 2.4 Document routes that return empty/error due to missing API keys (expected — will be configured in Vercel)

- [ ] **Task 3: Catalog new E2E test files** (AC: #3)
  - [ ] 3.1 Diff `e2e/` directory: `git diff develop..HEAD --name-only -- e2e/`
  - [ ] 3.2 List all new test files with brief descriptions
  - [ ] 3.3 Note any tests that reference upstream-specific branding or behavior that may need fork adjustments
  - [ ] 3.4 Document any tests that were removed or renamed by upstream

- [ ] **Task 4: Fix fork-specific test failures** (AC: #1)
  - [ ] 4.1 For tests that check page title, update expected values to "Situation Monitor"
  - [ ] 4.2 For tests that check branding elements, update selectors/assertions for fork branding
  - [ ] 4.3 For tests that depend on specific panel ordering, verify against fork panel order
  - [ ] 4.4 Commit fixes with prefix `[sync] fix e2e — {description}`

- [ ] **Task 5: Document results** (AC: #1–#3)
  - [ ] 5.1 Record final test results at bottom of this file
  - [ ] 5.2 List any quarantined/skipped tests with rationale
  - [ ] 5.3 Note any tests that should be added for fork-specific behavior (backlog for future)

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| E2E framework | Playwright (configured in `playwright.config.ts`) | Project setup |
| Test scope | E2E tests cover user flows, not individual endpoints | PRD distinction |
| Smoke tests | Endpoint smoke script hits all API endpoints checking for non-error responses | PRD FR item #8 |
| Fork branding in tests | Tests expecting "World Monitor" must be updated to "Situation Monitor" | Fork branding requirement |

### Expected E2E Test Areas (from Upstream)

Based on the 648-commit gap, upstream likely added tests for:
- New panels: Forecast, MCP, Sanctions, Radiation, Thermal
- Map interactions: country hover, sea context menu, weather radar layers
- Settings UI changes
- Blog, Pro, and Docs routes
- Circuit breaker persistence (#1809)
- Service worker behavior (#1718)

### Existing E2E Tests (Fork)

Current `e2e/` directory contains tests for:
- `circuit-breaker-persistence.spec.ts`
- `deduct-situation.spec.ts`
- `investments-panel.spec.ts`
- (and potentially more — full catalog from `ls e2e/`)

These existing tests should all pass. Any failures indicate a regression from the merge.

### Depends On

- Story 5-4 must be complete (fork hook and branding verified)
- Stories 5-2 and 5-3 should be complete (build passes, env vars documented)

### Commit Convention

Fix commits use prefix: `[sync] fix e2e — {description}`
