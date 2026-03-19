# Story 5.2: Build Validation and Proto Contract Check

Status: ready-for-dev

## Story

As an **operator**,
I want the merged codebase to build cleanly and pass all contract checks,
So that I know the sync didn't introduce structural regressions.

## Acceptance Criteria

1. **Given** the upstream-sync branch from Story 5-1
   **When** I run `make lint`
   **Then** lint passes (new upstream warnings are documented as the new baseline)

2. **Given** the upstream-sync branch
   **When** I run `make build` with `VITE_VARIANT=full`
   **Then** the Vite build succeeds without errors

3. **Given** the upstream-sync branch
   **When** I run `buf breaking`
   **Then** no breaking proto changes are detected (or documented if intentional upstream breaks)

4. **Given** the build succeeds
   **When** I run `node --test` for unit tests
   **Then** existing fork tests pass
   **And** new upstream tests pass (or documented failures are triaged)

## Scope Boundary

This story covers:
- Running the full lint suite and documenting the new warning baseline
- Verifying `make build` succeeds for the `full` variant
- Checking proto contract integrity with `buf breaking`
- Running unit tests and triaging failures
- Verifying `make generate` output is byte-identical to committed files (NFR33)
- Fixing any build/test failures introduced by merge resolution errors from Story 5-1

This story does NOT cover:
- Merge conflict resolution (Story 5-1 — completed before this)
- Environment variable auditing (Story 5-3 — can run in parallel)
- Visual/branding verification (Story 5-4)
- E2E test execution (Story 5-5)

## Tasks / Subtasks

- [ ] **Task 1: Lint validation** (AC: #1)
  - [ ] 1.1 Run `make lint` on the upstream-sync branch
  - [ ] 1.2 Record total warning count — compare against fork baseline (173→49 warnings per upstream #1712 lint debt reduction)
  - [ ] 1.3 If lint fails with errors (not warnings), fix the errors
  - [ ] 1.4 Document the new lint warning baseline in this story's results section

- [ ] **Task 2: Build validation** (AC: #2)
  - [ ] 2.1 Run `VITE_VARIANT=full make build`
  - [ ] 2.2 If build fails, analyze errors — likely causes: missing types, import path changes, new dependencies not installed
  - [ ] 2.3 Fix build failures — these are likely merge resolution errors from 5-1
  - [ ] 2.4 Record build output size for baseline comparison

- [ ] **Task 3: Proto contract check** (AC: #3)
  - [ ] 3.1 Run `buf breaking` against the proto directory
  - [ ] 3.2 If breaking changes detected, determine if they are intentional upstream changes
  - [ ] 3.3 Document any breaking proto changes with the upstream PR that introduced them
  - [ ] 3.4 Verify `make generate` output is byte-identical to committed `src/generated/` files

- [ ] **Task 4: Unit test validation** (AC: #4)
  - [ ] 4.1 Run `node --test` (or the project's test runner) for unit tests
  - [ ] 4.2 Triage any failures — categorize as: merge error, upstream regression, fork-specific issue
  - [ ] 4.3 Fix merge-error failures (send back to 5-1 tasks if conflict resolution was wrong)
  - [ ] 4.4 Document upstream regressions if any (file upstream issues)
  - [ ] 4.5 Fix fork-specific test failures

- [ ] **Task 5: Fix any build/test regressions** (AC: #1–#4)
  - [ ] 5.1 For each failure, commit a fix with prefix `[sync] fix {description}`
  - [ ] 5.2 Re-run the full sequence: `make generate && make lint && make build && node --test`
  - [ ] 5.3 All four must pass before marking this story done

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| Proto codegen | `make generate` output must be byte-identical to committed files | NFR33, ARCH-38 |
| Build variant | Fork only deploys `full` variant — build with `VITE_VARIANT=full` | ARCH-4 |
| Lint baseline | Upstream reduced lint warnings from 173→49 (#1712) — new baseline should be near 49 | Upstream PR #1712 |

### Expected Build Risks

- **TypeScript path changes**: Upstream decomposed `App.ts` into `src/app/` modules — import paths may have shifted
- **New panel registrations**: 10+ new panels registered in `src/app/panel-layout.ts` — verify fork panel ordering isn't broken
- **Protobuf evolution**: New message types for Forecast, MCP, Sanctions, Radiation, Thermal, Correlation domains
- **Vite config changes**: Dynamic env loading (#1791) changed how env vars are surfaced — may affect build-time constants
- **CSP hash updates**: Multiple CSP policy changes (#1756, #1709, #1750) — build may warn about inline scripts

### Depends On

- Story 5-1 must be complete (clean merge with `npm install` and `make generate` passing)

### Commit Convention

Fix commits use prefix: `[sync] fix {description}`
