# Story 5.1: Create Upstream Sync Branch and Resolve Merge Conflicts

Status: ready-for-dev

## Story

As an **operator**,
I want a clean `upstream-sync` branch with all 648 upstream commits merged and conflicts resolved,
So that I have a stable integration target to validate before merging into `develop`.

## Acceptance Criteria

1. **Given** the latest `upstream/main` has been fetched
   **When** I create branch `upstream-sync/2026-03-18` from `develop`
   **And** merge `upstream/main` into it
   **Then** all merge conflicts are resolved preserving both fork customizations and upstream changes

2. **Given** the merge is complete
   **When** I check `src/main.ts`
   **Then** the fork hook import (`src/fork/index`) is present and correctly placed per ARCH-37

3. **Given** the merge is complete
   **When** I run `npm install`
   **Then** `node_modules` installs without errors
   **And** `package.json` reflects upstream dependency additions without losing fork-specific dependencies

4. **Given** the merge is complete
   **When** I run `make generate`
   **Then** protobuf codegen succeeds
   **And** `src/generated/` output matches committed files (ARCH-38)

5. **Given** any fork file was upstream-modified
   **When** the conflict is resolved
   **Then** the resolution is documented in this story's merge log

## Scope Boundary

This story covers:
- Creating the `upstream-sync/2026-03-18` branch from `develop`
- Merging `upstream/main` (648 commits, PRs #809–#1851) into the sync branch
- Resolving all merge conflicts in fork-modified files
- Preserving the fork hook import in `src/main.ts`
- Preserving fork-specific dependencies in `package.json`
- Verifying `npm install` and `make generate` succeed post-merge
- Documenting all conflict resolutions

This story does NOT cover:
- Build validation or lint checks (Story 5-2)
- Environment variable auditing (Story 5-3)
- Fork branding visual verification (Story 5-4)
- E2E test execution (Story 5-5)
- Merging into `develop` or deploying (Story 5-6)

## Tasks / Subtasks

- [ ] **Task 1: Create upstream sync branch** (AC: #1)
  - [ ] 1.1 Verify `upstream` remote: `git remote -v | grep upstream` → `https://github.com/koala73/worldmonitor.git`
  - [ ] 1.2 Fetch latest upstream: `git fetch upstream`
  - [ ] 1.3 Ensure `develop` is clean: `git status` shows nothing
  - [ ] 1.4 Create branch: `git checkout -b upstream-sync/2026-03-18 develop`

- [ ] **Task 2: Merge upstream and catalog conflicts** (AC: #1, #5)
  - [ ] 2.1 Run `git merge upstream/main` — do NOT use `--squash` (preserve full history)
  - [ ] 2.2 Capture the full conflict list: `git diff --name-only --diff-filter=U` → save to merge log
  - [ ] 2.3 Categorize conflicts by risk tier (Critical / High / Medium / Low per architecture merge risk map)

- [ ] **Task 3: Resolve `package.json` and lockfile** (AC: #3)
  - [ ] 3.1 For `package-lock.json` — use `--theirs` strategy, then regenerate: `git checkout --theirs package-lock.json && npm install`
  - [ ] 3.2 For `package.json` — manual merge: accept all upstream dependency additions, preserve fork-specific deps (`@sentry/*` if present, any fork-only packages)
  - [ ] 3.3 Verify no fork dependencies were lost by diffing fork's `package.json` deps against merged result

- [ ] **Task 4: Resolve `src/main.ts` — preserve fork hook** (AC: #2)
  - [ ] 4.1 Check that `import './fork'` (or `import './fork/index'`) line is present
  - [ ] 4.2 If upstream modified `main.ts`, accept upstream changes BUT manually re-add the fork hook import
  - [ ] 4.3 Verify the import is after app initialization, per ARCH-37

- [ ] **Task 5: Resolve `vite.config.ts`** (AC: #1)
  - [ ] 5.1 Incorporate upstream's dynamic env variable loading (#1791)
  - [ ] 5.2 Preserve any fork-specific Vite configuration
  - [ ] 5.3 Verify `VITE_VARIANT=full` build target is intact

- [ ] **Task 6: Resolve `vercel.json`** (AC: #1)
  - [ ] 6.1 Merge upstream route/rewrite additions
  - [ ] 6.2 Preserve fork-specific routes if any exist
  - [ ] 6.3 Verify no route conflicts between fork and upstream additions

- [ ] **Task 7: Resolve `middleware.ts`** (AC: #1)
  - [ ] 7.1 Merge upstream edge middleware changes
  - [ ] 7.2 Preserve any fork-specific middleware logic (bot detection, redirects)

- [ ] **Task 8: Resolve `src/fork/` conflicts** (AC: #1)
  - [ ] 8.1 This directory is fork-only — conflicts should be minimal
  - [ ] 8.2 If upstream added files that collide, keep fork versions and document

- [ ] **Task 9: Resolve `tsconfig.json` and build configs** (AC: #1)
  - [ ] 9.1 Accept upstream TypeScript config changes
  - [ ] 9.2 Preserve fork-specific path aliases if any

- [ ] **Task 10: Verify post-merge toolchain** (AC: #3, #4)
  - [ ] 10.1 Run `npm install` — must complete without errors
  - [ ] 10.2 Run `make generate` — protobuf codegen must succeed
  - [ ] 10.3 Verify `src/generated/` output matches committed files

- [ ] **Task 11: Document conflict resolutions** (AC: #5)
  - [ ] 11.1 Create merge log section at bottom of this file or in a companion `5-1-merge-log.md`
  - [ ] 11.2 For each conflicted file, document: file path, conflict type, resolution strategy, and rationale

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| Upstream sync pattern | Dedicated `upstream-sync` branch → merge → test → PR into `develop` | [architecture.md](../_spec/planning-artifacts/architecture.md) Upstream Sync Strategy |
| Fork hook preservation | `src/main.ts` must contain the single-line fork hook import after every merge | ARCH-37, Upstream Sync Checklist |
| Proto codegen | Run `make generate` after every upstream merge; output must match committed files | ARCH-38 |
| Lockfile strategy | Use `--theirs` for lockfile, manual merge for `package.json` | Epic risk assessment |
| Fork only deploys `full` variant | No other build variants; ignore upstream variant additions | ARCH-4 |

### Merge Risk Map (from Architecture)

| Risk Level | Files | Reason |
|---|---|---|
| **Critical** | `src/app/panel-layout.ts`, `src/app/data-loader.ts` | Panel lifecycle and data orchestration — most active upstream change surfaces |
| **High** | `proto/**`, `src/generated/**` | Codegen cascade — upstream proto changes require full regeneration |
| **High** | `src/app/event-handlers.ts` | UI event routing — fork interaction hooks may conflict |
| **Medium** | `server/worldmonitor/*/v1/handler.ts` | Domain handler changes — upstream may add/modify API logic |
| **Medium** | `package.json`, `package-lock.json`, other `src/app/` modules | Dep conflicts + supporting module evolution |
| **Low** | `App.ts` (thin shell), `public/`, `index.html`, branding assets | Shell is stable; fork-specific assets unlikely to conflict |

### Expected Conflict Hotspots

Based on the 648-commit gap (130 features, 380 fixes, 50 refactors), expect conflicts in:
- `package.json` — new deps from Forecast, MCP, Widgets, Sanctions, Radiation, Thermal panels
- `src/main.ts` — upstream may have restructured imports
- `vite.config.ts` — dynamic env loading (#1791)
- `vercel.json` — new routes for `/blog`, `/docs`, `/pro`, new API endpoints
- `middleware.ts` — upstream edge middleware evolution
- `src/app/panel-layout.ts` — new panels change layout registration
- `src/app/data-loader.ts` — new data sources change loader config
- `proto/` — new message types for new domains

### Commit Convention

All commits on this branch use prefix: `[sync] merge upstream v2.x.x (PRs #809–#1851)`

Conflict resolution commits can use: `[sync] resolve {filename} — {strategy}`
