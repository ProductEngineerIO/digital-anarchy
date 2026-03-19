# Epic: Upstream Sync — March 2026 (PRs #809–#1851)

Status: draft

## Overview

Integrate 648 commits from `upstream/main` (koala73/worldmonitor) into the fork's `develop` branch. The upstream has advanced from PR #809 to PR #1851, spanning **130 features**, **380 fixes**, **50 refactors**, **14 performance improvements**, and **16 documentation updates** — touching **987 files** with ~146K insertions and ~53K deletions.

This epic decomposes the sync into risk-tiered stories that can be merged incrementally, validated at each gate, and rolled back independently if needed.

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Merge conflicts in upstream-modified files | HIGH | Story 5-1 creates clean `upstream-sync` branch per ARCH-34 |
| Proto/codegen drift breaking the build | HIGH | Story 5-2 runs `make generate` + `buf breaking` early |
| Fork hook (`src/fork/index.ts` import in `main.ts`) lost in merge | MEDIUM | Story 5-1 explicitly validates hook preservation per ARCH-37 |
| New env vars required by upstream features | MEDIUM | Story 5-3 audits new env dependencies before deploy |
| `package.json` / lockfile conflicts | MEDIUM | Story 5-1 uses `--theirs` for lock, manual merge for `package.json` |
| Redis key schema changes from upstream | LOW | Story 5-3 checks for new key patterns and prefix compliance |
| New upstream build variants (beyond `full`) | LOW | Fork only deploys `full` variant per ARCH-4; verify no breakage |

## Upstream Change Summary by Domain

### New Features (Major)

| Domain | Feature | PR(s) | Impact |
|--------|---------|-------|--------|
| **Forecast** | AI Forecasts prediction module — simulation state, scenario pipeline, world-state synthesis, trace export, report continuity | #1579, #1646, #1773, #1779, #1780, #1785, #1788, #1847, #1850 | New panel + Railway service + R2 traces |
| **MCP** | MCP data panel for user-connected servers, SSE transport, multi-header auth | #1835, #1845, #1848 | New panel + MCP protocol integration |
| **Widgets** | AI widget builder, PRO interactive widgets, Exa web search | #1732, #1771, #1782 | PRO tier feature + iframe srcdoc |
| **Supply Chain** | CorridorRisk intelligence, freight indices (SCFI/CCFI/BDI), dark-transit anomaly detection, chokepoint transit intel | #1560, #1595, #1616, #1652, #1666 | Panel restructure + 3 new data sources |
| **Sanctions** | OFAC sanctions pressure intelligence | #1739 | New panel + Railway seed |
| **Radiation** | Radiation Watch with anomaly intelligence, map layers, country exposure | #1735 | New panel + seed service |
| **Thermal** | Thermal Escalation panel + seeded service | #1747, #1786 | New panel + seed service |
| **Trade** | US Treasury customs revenue, effective tariff rate source | #1663, #1689, #1790 | Trade Policy panel expansion |
| **Map** | Country hover, sea context menu, weather radar, PMTiles migration, per-provider theme selector, NOTAM overlay, satellite imagery | #1064, #1101, #1356, #1363, #1830 | Major map UX overhaul |
| **Predictions** | Kalshi data source, panel redesign with gradient bars | #1355, #1661 | Prediction panel overhaul |
| **Military** | Wingbits live flight details, enrichment audit waterfall, GPS jamming migration | #1240, #1730, #1816 | Wingbits integration |
| **Aviation** | Wingbits fallback for civilian flights | #1839 | OpenSky resilience |
| **Economy** | Macro stress signals, separate energy complex panel | #1719, #1749 | New panels |
| **Orbital** | Satellite surveillance layer with real-time tracking, satellite-to-ground beam viz | #1278, #1342, #1375 | Globe visual expansion |
| **Desktop** | Sidecar cloud proxy, domain handlers | #1454 | Tauri integration |
| **Blog** | Astro blog at /blog with 16 SEO posts + hero images | #1401, #1436, #1440 | /blog route + build pipeline |
| **Pro** | PRO waitlist landing page, referral system, early access banner | #1140, #1207, #1261, #1300, #1301, #1382 | /pro route + CTAs |
| **Docs** | Mintlify documentation site at /docs | #1444, #1495 | /docs route + Mintlify config |
| **Scoring** | Live advisory data from Redis, server-side CII port | #1351, #1620 | Advisory gold standard |
| **Correlation** | Multi-domain correlation engine + server-side seed | #1524, #1571 | Cross-domain intelligence |
| **CII** | Displacement signal + 30-day ACLED window | #1818 | Scoring accuracy |
| **Commodities** | Expand from 6 to 14 symbols | #1776 | Market data expansion |

### Infrastructure & Platform (Critical Path)

| Area | Changes | PR(s) |
|------|---------|-------|
| **Railway Seeds** | Seed scripts for all unseeded Vercel RPC endpoints | #1599 |
| **Vite Config** | Dynamic env variable loading | #1791 |
| **R2 Storage** | S3 client in scripts runtime, retry transient failures, lazy-load | #1831, #1832, #1654 |
| **CSP** | Multiple CSP hash and policy updates | #1756, #1709, #1750 |
| **SEO** | Sitemap, IndexNow, blog SEO, OG metadata | #1833, #1838, #1841 |
| **Health Monitoring** | 28+ health threshold adjustments, seed-meta tracking | #1127 and many fixes |
| **Circuit Breakers** | Persist caches, edge-cache Vary elimination | #1809, #1811 |
| **Service Worker** | Throttled event-driven updates, nuke key bumps | #1718, #1079, #1081 |
| **Gold Standard** | Redis-read-only migration for UCDP, theater posture, GDELT, sanctions | #1759, #1763, #1684 |
| **Security** | Cache key injection hardening, rate-limit improvements, SSRF checks | #1103, #1013, #1740 |

### Refactoring (Code Quality)

- 19 targeted refactors deduplicating helpers (RSS proxy, error mapper, JSON response assembly, FRED helper, Wingbits helper, Upstash reads, URL state parsers, signals fetch config, etc.)
- Protobuf unsafe non-null assertion cleanup (#1826)
- Unbounded cache growth fix for circuit breakers (#1829)
- Canvas 2D transit chart replacing lightweight-charts (#1609)
- LLM provider consolidation (#1640)
- Baseline lint debt reduction 173→49 warnings (#1712)

---

## Stories

### Story 5-1: Create Upstream Sync Branch and Resolve Merge Conflicts

**Status:** not-started

**As an** operator,
**I want** a clean `upstream-sync` branch with all 648 upstream commits merged and conflicts resolved,
**So that** I have a stable integration target to validate before merging into `develop`.

**Acceptance Criteria:**

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

**Tasks:**

- [ ] 1.1 Create `upstream-sync/2026-03-18` branch from `develop`
- [ ] 1.2 Run `git merge upstream/main` and catalog all conflicts
- [ ] 1.3 Resolve `package.json` and lockfile conflicts (upstream additions + fork deps)
- [ ] 1.4 Resolve `src/main.ts` — preserve fork hook import
- [ ] 1.5 Resolve `vite.config.ts` — incorporate upstream's dynamic env loading (#1791)
- [ ] 1.6 Resolve `vercel.json` — merge route/rewrite changes
- [ ] 1.7 Resolve `middleware.ts` — merge upstream edge middleware changes
- [ ] 1.8 Resolve any `src/fork/` conflicts (should be minimal — fork-only directory)
- [ ] 1.9 Resolve `tsconfig.json` / build config conflicts
- [ ] 1.10 Run `npm install` and verify clean install
- [ ] 1.11 Run `make generate` and verify proto codegen
- [ ] 1.12 Document all conflict resolutions in merge log

**Commit prefix:** `[sync] merge upstream v2.x.x (PRs #809–#1851)`

---

### Story 5-2: Build Validation and Proto Contract Check

**Status:** not-started  
**Depends on:** 5-1

**As an** operator,
**I want** the merged codebase to build cleanly and pass all contract checks,
**So that** I know the sync didn't introduce structural regressions.

**Acceptance Criteria:**

1. **Given** the upstream-sync branch from S-1
   **When** I run `make lint`
   **Then** lint passes (may have new upstream warnings — document baseline)

2. **Given** the upstream-sync branch
   **When** I run `make build`
   **Then** the Vite build succeeds for `VITE_VARIANT=full`

3. **Given** the upstream-sync branch
   **When** I run `buf breaking`
   **Then** no breaking proto changes are detected (or documented if intentional upstream breaks)

4. **Given** the build succeeds
   **When** I run `node --test` for unit tests
   **Then** existing fork tests pass
   **And** new upstream tests pass (or documented failures are triaged)

**Tasks:**

- [ ] 2.1 Run `make lint` — record any new warnings vs baseline
- [ ] 2.2 Run `make build` with `VITE_VARIANT=full` — verify clean build
- [ ] 2.3 Run `buf breaking` — verify proto contract integrity
- [ ] 2.4 Run unit tests — triage any failures
- [ ] 2.5 Verify `make generate` output is byte-identical to committed files (NFR33)
- [ ] 2.6 Fix any build/test failures introduced by merge resolution errors

---

### Story 5-3: Environment Variable Audit and Configuration Update

**Status:** not-started  
**Depends on:** 5-1

**As an** operator,
**I want** all new environment variables required by upstream features to be documented and configured,
**So that** new panels and services don't fail silently in Preview or Production.

**Acceptance Criteria:**

1. **Given** the upstream-sync branch
   **When** I audit new `process.env.*` and `import.meta.env.*` references
   **Then** a complete list of new env vars is produced with their purpose and required-vs-optional status

2. **Given** the new env var list
   **When** I update `fork.env.example`
   **Then** all new variables are documented with descriptions

3. **Given** new Redis keys introduced by upstream
   **When** I verify the key patterns
   **Then** all keys use the `prefixedKey()` wrapper (ARCH-29) and none bypass it

4. **Given** new Railway seed scripts
   **When** I identify new Railway services
   **Then** they are documented with their required environment variables and cron schedules

**New Services Requiring Env Vars (Expected):**

| Service | Likely Env Vars | Source PRs |
|---------|----------------|------------|
| Forecast/LLM | `GROQ_API_KEY`, `OPENROUTER_API_KEY`, LLM model overrides | #1579, #1751 |
| Sanctions/OFAC | OFAC data source keys | #1739 |
| Radiation Watch | Radiation data source keys, Safecast API | #1735 |
| Thermal Escalation | Thermal data source config | #1747 |
| CorridorRisk | CorridorRisk API key | #1616 |
| Wingbits | `WINGBITS_API_KEY` | #1240, #1816, #1839 |
| MCP | MCP server connection config | #1835 |
| Widgets/Exa | `EXA_API_KEY` | #1782 |
| Mintlify Docs | Mintlify API key | #1444 |
| IndexNow/SEO | IndexNow key | #1833 |
| CoinPaprika | CoinPaprika API config | #1092 |
| Kalshi | Kalshi API config | #1355 |
| Freight Indices | SCFI/CCFI/BDI data source config | #1666 |

**Tasks:**

- [ ] 3.1 Grep for new `process.env.` and `import.meta.env.` references vs fork baseline
- [ ] 3.2 Grep for new `UPSTASH_*` / Redis key patterns
- [ ] 3.3 Update `fork.env.example` with all new variables
- [ ] 3.4 Document new Railway seed services and cron schedules
- [ ] 3.5 Verify all Redis keys use `prefixedKey()` — no direct calls

---

### Story 5-4: Fork Hook and Branding Integrity Validation

**Status:** not-started  
**Depends on:** 5-2

**As an** operator,
**I want** to verify that all fork customizations (branding, CSS overrides, fork hook) still function after the upstream sync,
**So that** the Situation Monitor identity and fork behavior are preserved.

**Acceptance Criteria:**

1. **Given** the build passes from S-2
   **When** I start `make dev`
   **Then** the app loads with Situation Monitor branding (titles, meta tags, descriptions)
   **And** the fork theme CSS variables propagate to panels, modals, and globe container

2. **Given** the fork hook executes
   **When** I check the browser console
   **Then** zero `[fork] ...` warning messages appear (graceful degradation intact)

3. **Given** upstream added/modified panels (Forecast, MCP, Thermal, Sanctions, Radiation, Macro Stress, etc.)
   **When** the fork CSS theme is active
   **Then** new panels inherit the fork's `--sm-*` design tokens without hardcoded color drift

4. **Given** upstream restructured map, globe, or settings UI
   **When** the fork overrides are applied
   **Then** CLS = 0 and no visual regressions in the fork's branded areas

**Tasks:**

- [ ] 4.1 Start dev server and verify fork hook executes
- [ ] 4.2 Verify branding: page title, meta tags, OG metadata, favicon
- [ ] 4.3 Audit new panels for CSS token compliance (spot check ≥5 new panels)
- [ ] 4.4 Verify globe, map layers, and settings UI are intact
- [ ] 4.5 Run Lighthouse on local dev for CLS = 0 check
- [ ] 4.6 Fix any fork regressions

---

### Story 5-5: E2E Test Suite and Smoke Test Validation

**Status:** not-started  
**Depends on:** 5-4

**As an** operator,
**I want** the E2E test suite and endpoint smoke tests to pass on the sync branch,
**So that** I can confidently merge into `develop` and deploy to Preview.

**Acceptance Criteria:**

1. **Given** the upstream-sync branch with all previous story fixes
   **When** I run the Playwright E2E suite
   **Then** all existing tests pass (new upstream E2E tests may be added — document any new test files)

2. **Given** the endpoint smoke test script
   **When** I run it against local dev
   **Then** all endpoint routes resolve (new upstream routes included)

3. **Given** upstream added new E2E specs
   **When** I review `e2e/` for new test files
   **Then** new tests are catalogued and any fork-specific adjustments are noted

**Tasks:**

- [ ] 5.1 Run `npx playwright test` — triage failures
- [ ] 5.2 Run endpoint smoke test — verify route coverage
- [ ] 5.3 Catalog new E2E test files from upstream
- [ ] 5.4 Fix any test failures caused by fork-specific divergence
- [ ] 5.5 Document test results and any skipped/quarantined tests

---

### Story 5-6: Merge to Develop and Deploy to Preview

**Status:** not-started  
**Depends on:** 5-5

**As an** operator,
**I want** the validated upstream-sync branch merged into `develop` and deployed to Vercel Preview,
**So that** the full upstream feature set is available for QA validation.

**Acceptance Criteria:**

1. **Given** all previous stories are complete and passing
   **When** I create a PR from `upstream-sync/2026-03-18` → `develop`
   **Then** CI pipeline passes (lint, unit tests, build, proto check)

2. **Given** the PR is merged
   **When** Vercel creates a Preview deployment
   **Then** the deployment loads without errors
   **And** new panels (Forecast, MCP, Thermal, Sanctions, Radiation, etc.) are accessible

3. **Given** the Preview deployment is live
   **When** I run the endpoint smoke test against it
   **Then** all routes return non-error responses (accounting for missing API keys in Preview)

4. **Given** all validations pass
   **When** the sync is confirmed stable
   **Then** the merge commit uses prefix `[sync] merge upstream PRs #809–#1851`

**Tasks:**

- [ ] 6.1 Open PR `upstream-sync/2026-03-18` → `develop`
- [ ] 6.2 Verify CI passes on PR
- [ ] 6.3 Merge PR
- [ ] 6.4 Verify Preview deployment loads
- [ ] 6.5 Smoke test Preview deployment
- [ ] 6.6 Document any panels that require API keys not yet configured

---

## Sprint Sequencing

| Order | Story | Estimate | Risk | Dependencies |
|-------|-------|----------|------|-------------|
| 1 | 5-1: Merge Branch & Conflict Resolution | Large | HIGH | None |
| 2 | 5-2: Build Validation & Proto Check | Medium | HIGH | 5-1 |
| 2 | 5-3: Env Var Audit & Config (parallel with 5-2) | Medium | MEDIUM | 5-1 |
| 3 | 5-4: Fork Hook & Branding Validation | Small | MEDIUM | 5-2 |
| 4 | 5-5: E2E & Smoke Test Pass | Medium | MEDIUM | 5-4 |
| 5 | 5-6: Merge to Develop & Preview Deploy | Small | LOW | 5-5 |

## Definition of Done (Epic Level)

- [ ] `develop` branch contains all 648 upstream commits
- [ ] Fork hook in `main.ts` is intact and functional
- [ ] `make generate && make lint && make build` all pass
- [ ] Unit tests and E2E tests pass
- [ ] Fork branding (CSS tokens, meta tags, page title) is preserved
- [ ] `fork.env.example` documents all new environment variables
- [ ] Preview deployment loads and serves all panels
- [ ] No new Tier 3 merge debt introduced (or documented if unavoidable)
