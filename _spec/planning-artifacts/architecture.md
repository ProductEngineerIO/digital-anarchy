---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-02-23'
inputDocuments:
  - _spec/planning-artifacts/prd.md
  - _spec/planning-artifacts/prd-validation-report.md
  - docs/architecture.md
  - docs/integration-architecture.md
  - docs/source-tree-analysis.md
  - docs/component-inventory.md
  - docs/api-contracts.md
  - docs/development-guide.md
  - docs/project-overview.md
  - docs/index.md
  - docs/DOCUMENTATION.md
  - docs/ADDING_ENDPOINTS.md
  - docs/API_KEY_DEPLOYMENT.md
  - docs/DESKTOP_CONFIGURATION.md
  - docs/RELEASE_PACKAGING.md
  - docs/TAURI_VALIDATION_REPORT.md
  - docs/local-backend-audit.md
  - docs/COMMUNITY-PROMOTION-GUIDE.md
  - README.md
  - CONTRIBUTING.md
  - CHANGELOG.md
  - public/llms.txt
  - public/llms-full.txt
workflowType: 'architecture'
project_name: 'Situation Monitor'
user_name: 'Ed'
date: '2026-02-23'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Document Navigation

```
Quick decisions         → Quick Reference Card (Implementation Patterns)
Where does this file go? → Project Structure & Boundaries
What tier is this change? → Hook Tier System (Core Architectural Decisions)
What's already decided?  → Inherited Decisions table (Core Architectural Decisions)
How do I handle errors?  → Process Patterns (Implementation Patterns)
What NOT to do?          → Anti-Patterns table (Implementation Patterns)
What's the merge risk?   → Merge Risk Map (Starter Template Evaluation)
Growth feature locations → Growth-Phase Structure Expansion (Project Structure)
First thing to build?    → Implementation Handoff (Validation Results)
Failure expectations?    → Failure Mode Validation (Validation Results)
Manual QA checklist?     → Verification Gap Register (Validation Results)
```

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
38 FRs across 7 capability areas. The distribution reveals an operationally-heavy architecture — 18 of 38 FRs (47%) cover deployment, CI/CD, upstream sync, and branding. Only 12 FRs cover core product functionality (visualization, data integration, AI). This is correct for a brownfield fork where the product is already built.

**Non-Functional Requirements:**
33 NFRs across 7 categories with priority markers (P0/P1/P2). The P0 requirements (verified on current deployment):
- NFR7: OG image gen within 10s/128MB (Vercel Hobby tier)
- NFR8–9: API key security (never in source, Vercel env vars only)
- NFR12–13: TLS everywhere (Vercel HTTPS, Upstash TLS)
- NFR15: Single-source failure isolation
- NFR17: Zero post-deployment regressions (QA → Prod gate)
- NFR26: Redis failure → graceful degradation, not crash
- NFR29: $0 monthly cost
- NFR33: Codegen determinism (make generate = byte-identical)

**Scale & Complexity:**
- Primary domain: Web SPA + Edge API (Vercel-hosted)
- Complexity level: High
- External integrations: 35+ data source APIs
- No user-facing database, authentication, or state management

### Technical Constraints & Dependencies

**Hard Constraints (Vercel Hobby Tier):**
- Serverless function timeout: 10 seconds
- Serverless function memory: 128MB
- Edge function execution: limited compute
- Bandwidth: 100GB/month
- Deployments: unlimited (Preview + Production)

**Hard Constraints (Upstash Redis Free Tier):**
- 10,000 commands/day (operational budget: 8,000)
- 256MB storage
- TLS-only connections

**Inherited Architecture (Non-Negotiable):**
- Framework-free TypeScript SPA (no React/Vue/Angular)
- Proto-first sebuf RPC layer (all API changes go through .proto → codegen)
- `buf breaking` enforces wire compatibility — proto schema evolution is constrained by CI. Breaking changes fail the pipeline.
- deck.gl + MapLibre GL for globe rendering (WebGL 2 mandatory)
- ONNX-based client-side ML inference in Web Workers
- AGPL-3.0 license (source must stay public)

**Build-Time Variant Exclusion:**
- `VITE_VARIANT=full` is the primary variant for the fork. Upstream ships 4 variants (full, tech, finance, happy) — all excluded at build time via Vite tree-shaking except the active one. Excluded variants produce zero runtime overhead — no code, no assets, no config. **[v2.5.8 UPDATE]** Happy variant added (positive news dashboard).
- Three `tauri.*.conf.json` files exist for desktop builds — entirely dormant for web-only deployment.

**Dormant Infrastructure:**
- Convex (`convex/registerInterest.ts`, `convex/schema.ts`) exists in the codebase for email registration. Intentionally inactive for MVP — no Convex deployment, no mutation calls. Present in the repo, not in the architecture.
- Railway AIS Relay (`scripts/ais-relay.cjs`) — WebSocket fanout for maritime vessel tracking. Excluded from MVP scope.

**Solo Operator Implications:**
- No team, no on-call rotation, no second pair of eyes. Every architectural decision must pass the "can Ed debug this alone at 7 AM with coffee?" test.
- Favors: observable systems over complex ones, convention over configuration, inherited behavior over custom behavior, platform-managed infrastructure (Vercel, Upstash) over self-managed.
- Operational complexity budget is near zero — if it can't be diagnosed from Vercel logs + Upstash dashboard, it's too complex.

**Deployment Context (Live & Verified):**
- Codebase is already deployed to Vercel and confirmed working
- Git-based deployment (Vercel auto-deploys on merge to main)
- GitHub Actions CI/CD as quality gate
- Two environments: Preview (QA) and Production
- No staging environment, no blue-green, no canary

**Test Infrastructure Constraints:**
- Playwright E2E uses SwiftShader (software WebGL) in CI — deck.gl visual output cannot be accurately validated. New visual features are effectively untestable in automated CI.
- 5 existing E2E specs cover map rendering, investments panel, keyword spike, mobile popup, runtime fetch — functional coverage, not visual fidelity.
- Unit tests run via Node.js `node --test` — no Jest, no Vitest. Lightweight but limited mocking.

### Core Architectural Pattern: Graceful Degradation

This is not a cross-cutting concern — it is THE fundamental resilience contract of the system. Every layer implements the same pattern:

**Request path:** Try preferred source → fall back to next tier → degrade visibly to user

**Manifestations:**
- **Data sources:** Each of 35+ APIs can fail independently. Panels show "not configured" or "unavailable" — never crash.
- **AI pipeline:** Groq → OpenRouter → browser-side T5. Three layers before AI features go dark.
- **Cache:** Redis unavailable → direct upstream call. Slower but functional (NFR26).
- **API keys:** Any subset can be missing. Panels with keys show data; panels without show graceful empty state (FR10–FR11).
- **Network:** Service worker serves cached views during outages. Offline fallback page as last resort (FR18–FR20).
- **OG pipeline:** If image generation fails, fall back to default OG card rather than broken preview.

This pattern must be preserved in every fork customization. It's what makes the system operatable by a solo operator — individual failures don't page anyone because they self-contain.

### Request Pipeline Topology

The system's runtime architecture is a pipeline, not a set of peer components:

```
Browser → Edge Middleware → RPC Gateway → Router → Domain Handler → External API
                                                         ↕
                                                   Upstash Redis
```

**Components in execution order:**
1. **SPA** (`src/`) — Client-side TypeScript, Web Workers for ML/analysis
2. **Edge Middleware** (`middleware.ts`) — Bot blocking, UA filtering
3. **RPC Gateway** (`api/[domain]/v1/[rpc].ts`) — CORS, API key validation, route dispatch
4. **Router** (`server/router.ts`) — Static Map<path, handler>, O(1) lookup
5. **Domain Handlers** (`server/worldmonitor/*/v1/handler.ts`) — 20 domains, external API calls
6. **Upstash Redis** — Cross-request caching (AI dedup, risk scores, temporal baselines)
7. **PWA Service Worker** — Offline caching layer (cache-first assets, network-first data)
8. **OG Image Pipeline** (`api/story.js`, `api/og-story.js`) — Serverless (not Edge), 10s budget
9. **Legacy REST** (`api/*.js`) — 11 non-RPC endpoints (RSS proxy, YouTube, EIA, version)

**App.ts Modular Architecture:** **[v2.5.8 UPDATE]** `App.ts` has been decomposed from a 4,629 LOC God Object into a 498 LOC thin shell + 8 modules in `src/app/`: `data-loader.ts` (1,823 LOC), `panel-layout.ts` (930 LOC), `event-handlers.ts` (731 LOC), `country-intel.ts` (530 LOC), `search-manager.ts` (552 LOC), `app-context.ts` (108 LOC), `refresh-scheduler.ts` (108 LOC), `desktop-updater.ts` (205 LOC). Fork hooks can target specific modules (e.g., panel ordering in `panel-layout.ts`, interaction interception in `event-handlers.ts`) rather than instrumenting a monolith. Merge risk is distributed across focused modules rather than concentrated in a single critical file.

### Cross-Cutting Concerns

1. **Cost Containment** — $0 operating budget means every architectural decision must account for free tier limits. Redis command counts, API rate limits, bandwidth — all constrained.

2. **Upstream Compatibility** — The fork must remain mergeable with upstream. Architectural changes that diverge from upstream patterns (file structure, build system, proto definitions) create merge debt. **[v2.5.8 UPDATE]** `src/app/panel-layout.ts` and `src/app/data-loader.ts` are the highest-risk merge surfaces (replacing the former `App.ts` monolith).

3. **Dual Runtime** — Edge Functions (middleware, RPC gateway) vs Serverless Functions (legacy API, OG image generation). Different runtime constraints, different timeout limits, different memory models.

4. **Cache Coherence** — Three-tier cache (in-memory → Redis → upstream) with QA/Prod isolation. Cache invalidation, TTL management, and environment separation are architectural concerns.

5. **Bot/Human Bifurcation** — The same URLs serve different content to bots (OG HTML) vs humans (SPA redirect). Edge middleware must accurately classify user-agents without false positives.

## Starter Template Evaluation

### Primary Technology Domain

**Web Application (SPA + Edge API)** — inherited from upstream fork, not selected.

### Starter Options Considered

| Option | Verdict |
|---|---|
| **Greenfield (Vite + framework)** | Rejected. 107.5K LOC of working product already exists. Rewrite = years of effort for zero user-visible gain. |
| **Alternative fork base** | No alternatives exist. worldmonitor is the only open-source intelligence monitoring SPA in this space. |
| **worldmonitor@v2.5.5 fork** | **Selected.** Full product with 62 components, ~95 services, 20 API domains, 57 RPCs, working CI/CD, E2E tests. Already deployed and verified on Vercel. **[v2.5.8 UPDATE]** Counts updated for upstream sync. |

### Selected Starter: worldmonitor@v2.5.5 (Fork) — Already Deployed

**Rationale for Selection:**
This is a brownfield customization of an existing, production-quality codebase. The fork is already deployed to Vercel and verified working. The architectural task is constraint mapping and customization planning — not technology selection or deployment.

**Current State:**
Fork is live on Vercel. All 57 endpoints functional. SPA loads and renders. The "starter" phase is complete — we are in the customization phase.

**Architectural Decisions Inherited from Starter:**

**Language & Runtime:**
- TypeScript 5.x (strict mode), targeting ES2022
- No framework — vanilla TypeScript with custom component lifecycle
- Vite 6.x build tooling with variant-aware tree-shaking
- Node.js runtime for serverless functions

**Styling Solution:**
- Plain CSS with CSS custom properties (no preprocessor, no CSS-in-JS)
- Responsive breakpoints via media queries
- Dark theme via CSS variables

**Build Tooling:**
- Vite for SPA bundling (dev server + production build)
- `buf generate` for proto→TypeScript codegen (sebuf RPC layer)
- `make generate` as canonical codegen entry point
- Vercel CLI for deployment

**Codegen Dependency Chain:**
The proto→codegen pipeline touches four directories in a single change:
```
proto/*.proto → buf generate → src/generated/ → server/ imports
```
Any `.proto` file change requires regeneration, updates to generated TypeScript, and potential changes to server handlers that import from `src/generated/`. This is the highest-friction development workflow in the codebase — implementation stories involving proto changes must account for this multi-directory cascade.

**Testing Framework:**
- Node.js `node --test` for unit tests (no Jest, no Vitest)
- Playwright for E2E (5 existing specs)
- SwiftShader for headless WebGL in CI — **zero visual CI coverage for new features.** Any new map panel or deck.gl visualization is untestable in automated CI. Existing E2E specs test functional behavior (click → panel appears, data loads), not visual output. New visual features require manual QA in a browser.
- `buf breaking` for proto schema compatibility — the **only** automated API contract validation
- **Test runtime bifurcation:** E2E runs in Chromium (Playwright), unit tests run in Node.js. No shared test utility layer. Mock infrastructure must be built separately for each runtime if needed.

**Code Organization:**
- `src/` — SPA (components, services, utils, workers, config, types)
- `server/` — Backend handlers (20 domains, shared utilities)
- `api/` — Vercel serverless entry points (RPC gateway + legacy REST)
- `proto/` — Protocol buffer definitions
- `src-tauri/` — Desktop shell (dormant for web-only deployment)

**Development Workflow Inherited:**
- **Local dev is two-process:** Vite dev server (`make dev`) for SPA + `vercel dev` for API function emulation. Some legacy REST endpoints (`api/*.js`) behave differently under `vercel dev` than in production due to edge vs serverless runtime divergence.
- **Make targets that matter:** `make generate` (codegen), `make dev` (local server), `make test` (unit tests), `make lint` (linting), `make build` (production build)
- **CI pipeline:** GitHub Actions: lint → unit tests → buf breaking → build → Playwright E2E. Green = safe to merge.

**Constraints Imposed by Starter:**
1. No framework adoption possible — 62 components use custom lifecycle, not React/Vue/Angular patterns
2. Proto schema changes require `buf breaking` pass — can't freely evolve APIs
3. **[v2.5.8 UPDATE]** `App.ts` decomposed into `src/app/` modules — panel changes route through `panel-layout.ts` (930 LOC) and `event-handlers.ts` (731 LOC) rather than a single God Object
4. WebGL 2 mandatory — deck.gl/MapLibre won't degrade to Canvas
5. AGPL-3.0 — all customizations must remain open source

### Fork Lifecycle

**Initialization (Complete):**
Fork is deployed and verified working on Vercel. Upstream remote configured. CI/CD pipeline operational. This is not a future story — it's done.

**Upstream Sync Strategy:**
- Cadence: At least monthly (per PRD measurable outcomes)
- Pattern: Dedicated `upstream-sync` branch → merge upstream → full test suite → PR into `main`
- Conflict resolution: **[v2.5.8 UPDATE]** `src/app/panel-layout.ts` (930 LOC) and `src/app/data-loader.ts` (1,823 LOC) are the highest-risk merge surfaces. The former `App.ts` monolith has been decomposed — merge risk is now distributed across focused modules rather than concentrated in a single file.
- Proto sync: Run `make generate` after every upstream merge. If upstream changes the codegen tool, catch it before it silently breaks the build.

**Merge Risk Map:** **[v2.5.8 UPDATE]**
| Risk Level | Files | Reason |
|---|---|---|
| **Critical** | `src/app/panel-layout.ts`, `src/app/data-loader.ts` | Panel lifecycle and data orchestration — most active upstream change surfaces |
| **High** | `proto/**`, `src/generated/**` | Codegen cascade — upstream proto changes require full regeneration |
| **High** | `src/app/event-handlers.ts` | UI event routing — fork interaction hooks may conflict |
| **Medium** | `server/worldmonitor/*/v1/handler.ts` | Domain handler changes — upstream may add/modify API logic |
| **Medium** | `package.json`, `package-lock.json`, other `src/app/` modules | Dep conflicts + supporting module evolution |
| **Low** | `App.ts` (thin shell), `public/`, `index.html`, branding assets | Shell is stable; fork-specific assets unlikely to conflict |

**Upstream Sync Checklist:**
- Verify `main.ts` diff — confirm the single-line fork hook is intact after merge
- Run `make generate` — confirm codegen output matches
- Check `package.json` — resolve Sentry dependency merge conflicts
- Run full test suite before PR into `main`

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Fork customization pattern (hook tiers + `src/fork/` structure) — shapes all future code changes
- Cache key strategy (prefixed client wrapper) — affects every Redis-touching endpoint

**Important Decisions (Shape Architecture):**
- Monitoring strategy (Sentry with noise filtering + correct env tagging)
- Branding scope (visual identity boundary defined)
- Fork pattern validation spike — proves the hook mechanism before committing

**Deferred Decisions (Post-MVP):**
- None. All 5 fork-specific decisions are resolved. Inherited decisions cover everything else.

### Inherited Decisions (Locked by Upstream)

| Category | Decision | Source |
|---|---|---|
| Language | TypeScript 5.x strict | Upstream |
| Framework | None (custom component lifecycle) | Upstream |
| Database | None (no user-facing DB/auth) | Upstream |
| Cache | Upstash Redis (free tier) | Fork deployment |
| API Pattern | sebuf RPC + REST legacy | Upstream |
| Frontend State | Custom (no Redux/MobX/Zustand) | Upstream |
| Hosting | Vercel Hobby tier | Fork deployment |
| CI/CD | GitHub Actions → Vercel auto-deploy | Fork deployment |
| Auth | None (public site, no user accounts) | PRD scope |
| Styling | Plain CSS + custom properties | Upstream |
| Testing | Node `--test` + Playwright + buf | Upstream |
| Rendering | deck.gl + MapLibre GL (WebGL 2) | Upstream |
| ML | ONNX in Web Workers | Upstream |

### Data Architecture

**Decision:** Single Upstash Redis instance with environment key prefixes, enforced at the client wrapper level.

| Attribute | Value |
|---|---|
| Category | Data Architecture |
| Decision | One Upstash Redis instance, key prefixes (`qa:` / `prod:`) for environment isolation |
| Rationale | Simpler — one instance, one dashboard, one set of credentials. Key prefixes provide logical isolation. The 10K commands/day budget is shared, but QA traffic is negligible. |
| Affects | Redis client wrapper (`server/_shared/redis.ts`), all cache operations |
| Trade-off accepted | Shared command quota. A careless `FLUSHDB` nukes both environments — mitigated by never using `FLUSHDB`. |

**Prefix enforcement pattern (architectural constraint):**
The environment prefix is injected at the Redis client wrapper level, not at individual call sites. Every Redis operation must go through the prefixed wrapper:

```typescript
// server/_shared/redis.ts
const prefix = process.env.VERCEL_ENV === 'production' ? 'prod:' : 'qa:';
export const prefixedKey = (key: string) => `${prefix}${key}`;
```

This is a hard architectural constraint — direct Redis calls that bypass `prefixedKey()` are forbidden. If every call routes through the wrapper, prefix omission is structurally impossible rather than relying on developer discipline.

### Authentication & Security

**No decisions required.** Public site, no user accounts, no auth. Security posture is inherited.

**Decision:** API key management via Vercel env vars only.

| Attribute | Value |
|---|---|
| Category | Security |
| Decision | All API keys stored exclusively in Vercel environment variables |
| Rationale | Dead simple. Rotate a key → update in Vercel dashboard → redeploy triggers automatically. No additional infrastructure. Solo operator pattern: fewer moving parts. |
| Trade-off accepted | No hot-swap capability. Key expiry mid-session → graceful degradation until next deploy. Acceptable — the degradation pattern already handles missing keys. |

### API & Communication Patterns

**No decisions required.** Fully inherited (sebuf RPC + legacy REST).

### Frontend Architecture

**Decision:** Wrapper/patch layer for fork customizations with three defined hook tiers.

| Attribute | Value |
|---|---|
| Category | Frontend Architecture |
| Decision | Create `src/fork/` directory with tiered hook mechanism |
| Rationale | Isolates fork changes from upstream. Merge cost drops to near-zero for Tier 1-2 changes. Tier 3 changes are tracked as explicit merge debt. |

**Hook Tier System:**

| Tier | Name | Mechanism | Merge Risk | Examples |
|---|---|---|---|---|
| **Tier 1** | Zero-touch | CSS custom property overrides, `<meta>` tags, favicon swap, static asset replacement | **None** — no upstream file modifications | Accent color, page title, OG images, favicon |
| **Tier 2** | Single-line hook | One import in `main.ts` that runs after app init. Can listen to DOM events, modify DOM, inject content via existing patterns | **Minimal** — one line in `main.ts`, everything else in `src/fork/` | Sentry init, header/footer text, custom analytics |
| **Tier 3** | Upstream modification | Changes that *must* touch upstream files beyond the single `main.ts` hook | **High** — each change tracked as merge debt with explicit upstream sync cost | `App.ts` behavioral changes, new panel types, routing modifications, `package.json` dependency additions |

Every fork story must declare its tier. Tier 3 changes require justification — "why can't this be Tier 1 or 2?"

**The actual hook mechanism is TBD.** The spike story (implementation step 2) must discover and document which mechanism works:
- DOM-ready callback (manipulate rendered DOM after init)
- Global event bus (if upstream dispatches custom events like `app:ready`)
- Direct import (override config/service values before `App` initializes)

Do not prescribe the mechanism — let the spike discover it.

**Fork directory structure:**
```
src/fork/
├── index.ts          # Entry point — registered from main.ts (Tier 2 hook)
├── branding.ts       # Visual identity overrides (Tier 1 — CSS vars + meta)
├── monitoring.ts     # Sentry initialization (Tier 2 / Tier 3 for package.json)
├── config.ts         # Fork-specific configuration values
└── __tests__/        # Fork-layer unit tests (node --test)
    ├── branding.test.mjs
    └── config.test.mjs
```

**Note:** `panels.ts` is not included in the initial structure. Add it when a story requires panel customization — don't build speculative structure.

**Fork testing contract:** All code in `src/fork/` requires unit tests in `src/fork/__tests__/` using the existing `node --test` infrastructure. Fork code is new code — it has no upstream test coverage.

**Decision:** Branding scope = visual identity only. Behavior changes = fork customization.

| Scope | Definition | Lives In |
|---|---|---|
| **Branding** (visual identity) | CSS custom properties, `<meta>` tags, `<title>`, favicon, OG card assets, `llms.txt`, header/footer text content | `src/fork/branding.ts` + static assets |
| **Fork customization** (behavior) | Panel visibility/ordering, data source priority, navigation flow, new features | `src/fork/config.ts` or new fork modules |

**Architectural constraint — CLS budget:** Fork branding must not cause Cumulative Layout Shift > 0. CSS custom property overrides are instant (same paint). DOM additions (header text, footer) must be present in the initial HTML or injected before first paint. The spike must verify this.

### Infrastructure & Deployment

**Decision:** Vercel-native monitoring + Sentry free tier (Tier 3 — modifies `package.json`).

| Attribute | Value |
|---|---|
| Category | Infrastructure |
| Decision | Sentry free tier (5K errors/month) for client-side error tracking |
| Classification | **Tier 3** — adds `@sentry/browser` to `package.json`, creating permanent merge debt |
| Rationale | Surfaces client-side crashes invisible to Vercel logs (WebGL context loss, ONNX failures, SW issues). |
| Affects | Bundle size (~20KB gzipped), `src/fork/monitoring.ts`, `package.json` (Tier 3 merge debt) |

**Sentry integration pattern:**
```typescript
// src/fork/monitoring.ts
import * as Sentry from '@sentry/browser';
Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.VITE_VERCEL_ENV || 'development',
  tracesSampleRate: 0,
  beforeBreadcrumb(breadcrumb) {
    if (breadcrumb.category === 'fetch' && !breadcrumb.data?.url?.includes(location.hostname)) {
      return null;
    }
    return breadcrumb;
  },
});
```

**Key details:**
- Environment uses `VITE_VERCEL_ENV` — correctly distinguishes `preview` (QA) from `production`. Vite's `MODE` is always `production` on Vercel builds.
- `beforeBreadcrumb` filters external API fetch noise — only captures same-origin breadcrumbs.
- No DSN = Sentry silently disabled (graceful degradation pattern).

### Decision Impact Analysis

**Implementation Sequence:**
1. **Create `src/fork/` structure** + single-line `main.ts` hook → unblocks all fork work
2. **Fork Pattern Validation Spike** — must answer three pass/fail questions:
   - Does the Tier 2 hook mechanism work? (Can `src/fork/index.ts` run code after app init?)
   - Does Tier 1 CSS override work? (Do CSS variable changes propagate to all components, or are some hardcoded?)
   - Does it deploy cleanly to Vercel Preview?
   - **Spike also discovers:** actual hook mechanism (DOM callback / event bus / direct import) and CSS variable coverage audit. Results documented in architecture doc.
3. **Configure Upstash Redis** with prefixed client wrapper → unblocks cache-dependent testing
4. **Apply full branding** (metadata + CSS overrides in `src/fork/branding.ts`) → first visible differentiation
5. **Add Sentry SDK** in `src/fork/monitoring.ts` (Tier 3 — `package.json` modification) → operational visibility

**Cross-Component Dependencies:**
- Step 1 unblocks step 2. Step 2 validates the pattern before steps 4 and 5 commit to it.
- Step 3 (Redis) is independent — pure infrastructure config.
- If spike (step 2) fails any gate, revise the fork pattern before proceeding.
- API key management (Vercel env vars) is already the current state — no implementation needed.

## Implementation Patterns & Consistency Rules

### Quick Reference Card

```
New fork file?       → src/fork/{purpose}.ts, kebab-case, with test
New fork endpoint?   → api/fork/{name}.js (legacy REST, not proto)
Touching upstream?   → Declare Tier (1/2/3), justify if Tier 3
Redis call?          → prefixedKey() always
External call?       → try/catch → fallback → console.warn
New dependency?      → Tier 3. Add to Merge Risk Map.
CSS override?        → <style id="fork-theme"> in <head>, :root vars
Import generated?    → NEVER in src/fork/. Use src/services/ or src/types/
Commit message?      → [fork] description  |  [sync] merge upstream vX.Y.Z
```

### Inherited Patterns (Follow Upstream — Non-Negotiable)

These are discovered from the existing codebase. AI agents must match these exactly.

**Naming:**

| Element | Convention | Example |
|---|---|---|
| Files (components) | `kebab-case.ts` | `country-panel.ts`, `risk-gauge.ts` |
| Files (services) | `kebab-case.ts` | `conflict-service.ts`, `cache-service.ts` |
| Files (types) | `kebab-case.ts` | `map-types.ts`, `api-types.ts` |
| Classes | `PascalCase` | `ConflictService`, `RiskGauge` |
| Functions | `camelCase` | `fetchCountryData()`, `renderPanel()` |
| Variables | `camelCase` | `countryCode`, `threatLevel` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT`, `DEFAULT_TTL` |
| CSS classes | `kebab-case` | `.panel-header`, `.risk-badge` |
| CSS custom properties | `--kebab-case` | `--accent-color`, `--panel-bg` |
| Proto messages | `PascalCase` | `CountryInstabilityRequest` |
| Proto fields | `snake_case` | `country_code`, `threat_level` |
| Proto RPCs | `PascalCase` | `GetCountryInstability`, `ListConflicts` |
| API route dirs | `kebab-case` | `api/[domain]/v1/[rpc].ts` |
| Env vars | `UPPER_SNAKE_CASE` with `VITE_` prefix for client | `VITE_SENTRY_DSN`, `UPSTASH_REDIS_REST_URL` |

**Structure:**

| Element | Location | Pattern |
|---|---|---|
| Components | `src/components/` | One file per component, flat or shallow grouping |
| Services | `src/services/` | One file per service domain |
| Types | `src/types/` | Shared type definitions |
| Worker scripts | `src/workers/` | Web Worker entry points |
| Server handlers | `server/worldmonitor/{domain}/v1/handler.ts` | One handler per domain |
| Shared server utils | `server/_shared/` | Cross-domain server utilities |
| Proto definitions | `proto/worldmonitor/` | Organized by domain |
| Generated code | `src/generated/` | Output of `buf generate` — **never hand-edit** |
| Unit tests | Co-located as `*.test.mjs` or in `tests/` | Matches existing pattern |
| E2E tests | `e2e/` | Playwright specs |
| Config | `src/config/` | Build-time and runtime configuration |
| Fork code | `src/fork/` | All fork-specific client code |
| Fork endpoints | `api/fork/` | Fork-specific API endpoints (legacy REST style) |
| Fork tests | `src/fork/__tests__/` | Fork-layer unit tests |

**API Format:**
- sebuf RPC: Binary protobuf request/response. The proto schema IS the format.
- Legacy REST (`api/*.js`): JSON responses, no consistent wrapper. Follow each endpoint's existing pattern.
- Error responses: HTTP status codes + JSON `{ error: string }` body.
- Date/time: ISO 8601 strings in JSON, Unix timestamps in proto.

### Fork-Specific Patterns

**Fork Endpoint Rule:**
Fork-specific endpoints go in `api/fork/` as legacy REST (`.js` files). Do not create new proto domains for fork features — every proto file is Tier 3 merge debt plus a codegen cascade. If a fork feature needs a server endpoint, it's a simple `.js` file in `api/fork/`.

**CSS Override Mechanism:**
Fork branding injects a `<style id="fork-theme">` block into `<head>` with `:root` overrides. No `document.documentElement.style.setProperty()` calls. The `<style>` approach has correct specificity behavior and survives component re-renders that read computed styles.

```typescript
// src/fork/branding.ts — CORRECT
const style = document.createElement('style');
style.id = 'fork-theme';
style.textContent = `:root {
  --accent-color: #1a73e8;
  --header-text: 'Situation Monitor';
}`;
document.head.appendChild(style);

// INCORRECT — don't use setProperty
// document.documentElement.style.setProperty('--accent-color', '#1a73e8');
```

**Generated Code Import Isolation:**
Fork code (`src/fork/**`) must not import directly from `src/generated/**`. Import from `src/services/` or `src/types/` instead. This isolates fork code from proto schema changes — if upstream modifies proto definitions, the breakage is contained to the service layer (upstream code, fixed by the merge) rather than spreading into fork files.

**Commit Message Convention:**
- Fork changes: `[fork] add accent color branding override`
- Upstream syncs: `[sync] merge upstream v2.5.6`
- Enables `git log --grep='\[fork\]'` to instantly filter fork-specific history

**Fork File Template:**
```typescript
// src/fork/{purpose}.ts
// kebab-case filename, named exports, strict TypeScript

export function doSomething(): void {
  try {
    // preferred path
  } catch (err) {
    console.warn('[fork] {purpose} failed, using defaults:', (err as Error).message);
    // graceful fallback — never crash
  }
}
```

### Process Patterns

**Redis Operations:**
```typescript
// CORRECT — always use prefixed wrapper
import { redis, prefixedKey } from '../_shared/redis';
await redis.get(prefixedKey('ai:summary:US'));

// FORBIDDEN — direct key without prefix
await redis.get('ai:summary:US');
```

**Error Handling (Server):**
```typescript
// CORRECT — throw mapped errors, let error-mapper.ts handle
import { mapError } from '../error-mapper';
try {
  const data = await fetchUpstream(url);
  return data;
} catch (err) {
  throw mapError(err);  // Returns appropriate HTTP status
}

// FORBIDDEN — catch and return custom error shapes
// FORBIDDEN — swallow errors silently
```

**Error Handling (Fork Client):**
```typescript
// CORRECT — graceful degradation pattern
try {
  applyBranding();
} catch (err) {
  console.warn('[fork] Branding failed, using defaults:', err.message);
  // Site works without fork branding — degradation, not crash
}

// FORBIDDEN — let fork errors crash the app
// FORBIDDEN — alert() or window.prompt() for error display
```

**Graceful Degradation (Universal):**
Every external call, every optional feature, every fork customization follows the same contract:
1. Try the preferred path
2. Catch failure
3. Fall back to a working state (may be reduced functionality)
4. Log the failure (`console.warn` for client, structured log for server)
5. Never crash, never hang, never show a blank screen

**Loading & State:**
- No global state management library. Components manage their own state.
- Loading states use CSS classes (`.is-loading`, `.has-error`, `.is-empty`) — not JS-driven visibility toggles
- Panels that await data show a skeleton/placeholder, not a spinner

**Import Order (Convention — advisory, not enforced):**
```typescript
// 1. Node/browser built-ins
import { readFile } from 'node:fs/promises';

// 2. Third-party packages
import { Redis } from '@upstash/redis';

// 3. Generated code (server/service layer only — never in src/fork/)
import { CountryInstabilityRequest } from '../generated/worldmonitor/cii/v1/cii';

// 4. Project imports (server, services, utils)
import { prefixedKey } from '../_shared/redis';

// 5. Fork imports (only in fork files or main.ts hook)
import { applyBranding } from './fork/branding';
```

*Note: No `eslint-plugin-import` is configured in this codebase. Import order is a convention for readability, not a CI-enforced rule. Adding lint enforcement is a Growth-phase improvement.*

### Enforcement Guidelines

**Hard Rules (Enforced by Lint/CI — build fails):**
1. `make lint` — catches naming and TypeScript strict mode violations
2. `buf breaking` — rejects proto schema breaking changes
3. `make generate` — codegen must produce byte-identical output
4. Playwright E2E — functional regressions fail the pipeline
5. `node --test` — unit test failures block merge

**Conventions (Enforced by Review — best effort):**
1. Declare fork tier (1/2/3) for changes touching upstream files
2. Use `prefixedKey()` for all Redis operations
3. Follow graceful degradation pattern for every external call
4. Never import from `src/generated/` in fork code
5. Use `[fork]` / `[sync]` commit message prefixes
6. Import order convention
7. Fork code has co-located tests

### Anti-Patterns

| Anti-Pattern | Why | Correct Pattern |
|---|---|---|
| Add React/Vue/Angular components | Incompatible with upstream's custom lifecycle | Use upstream's component pattern |
| Import from `src/generated/` in `src/fork/` | Proto schema changes break fork code on upstream sync | Import from `src/services/` or `src/types/` |
| Create new proto definitions for fork features | Every proto file is Tier 3 merge debt + codegen cascade | Use legacy REST in `api/fork/` |
| Import from `node_modules` in `src/generated/` | Generated code is overwritten by codegen | Import in handler or service layer |
| Use `FLUSHDB` or `FLUSHALL` on Redis | Nukes both QA and prod cache | Use prefix-scoped `SCAN` + `DEL` |
| Add `@ts-ignore` without explanation | Hides real type errors | Fix the type or document why it's unfixable |
| Modify `App.ts` without Tier 3 justification | Maximum merge conflict risk | Use `src/fork/` hook mechanisms |
| Use `fetch()` directly in fork code | Bypasses error mapping and retry logic | Use existing service layer methods |

## Project Structure & Boundaries

### Complete Project Directory Structure

Existing upstream structure with fork additions marked with `← FORK`.

```
situation-monitor/
├── .github/
│   └── workflows/              # CI/CD pipeline (GitHub Actions)
│       └── ci.yml              # lint → test → buf → build → E2E
├── api/                        # Vercel serverless entry points
│   ├── _api-key.js             # API key validation helper
│   ├── _cors.js                # CORS middleware
│   ├── _cors.test.mjs          # CORS unit test
│   ├── download.js             # File download endpoint
│   ├── fwdstart.js             # Forward start endpoint
│   ├── og-story.js             # OG image generation (serverless, 10s budget)
│   ├── og-story.test.mjs       # OG story unit test
│   ├── register-interest.js    # Interest registration
│   ├── rss-proxy.js            # RSS feed proxy
│   ├── story.js                # Story/deep-link handler (bot vs human)
│   ├── version.js              # Version info endpoint
│   ├── [domain]/               # sebuf RPC gateway (dynamic routing)
│   │   └── v1/
│   │       └── [rpc].ts        # Catch-all: domain + RPC → handler dispatch
│   ├── data/                   # Static data endpoints
│   ├── eia/                    # Energy Information Administration
│   ├── youtube/                # YouTube data proxy
│   └── fork/                   # ← FORK: Fork-specific endpoints (legacy REST)
│       └── *.test.mjs          # ← FORK: Co-located endpoint tests
├── convex/                     # DORMANT: Email registration (inactive for MVP)
│   ├── registerInterest.ts
│   ├── schema.ts
│   └── tsconfig.json
├── data/                       # Static data files
│   ├── gamma-irradiators.json
│   └── gamma-irradiators-raw.json
├── deploy/
│   └── nginx/                  # DORMANT: Nginx config (not used on Vercel)
├── docs/                       # Project documentation (21 files)
│   ├── index.md                # Doc hub
│   ├── architecture.md         # Upstream system architecture
│   ├── integration-architecture.md  # 8-part integration guide
│   ├── source-tree-analysis.md
│   ├── component-inventory.md
│   ├── api-contracts.md
│   ├── development-guide.md
│   ├── project-overview.md
│   └── ...                     # 13 more doc files
├── e2e/                        # Playwright E2E tests
│   ├── investments-panel.spec.ts
│   ├── keyword-spike-flow.spec.ts
│   ├── map-harness.spec.ts
│   ├── mobile-map-popup.spec.ts
│   ├── runtime-fetch.spec.ts
│   └── fork/                   # ← FORK: Fork-specific E2E tests
│       └── (created as needed)
├── proto/                      # Protocol Buffer definitions
│   ├── buf.gen.yaml            # Codegen configuration
│   ├── buf.yaml                # Buf module configuration
│   ├── sebuf/                  # sebuf framework protos
│   └── worldmonitor/           # Domain protos (20 domains)
├── public/                     # Static assets (served directly)
│   ├── llms.txt                # LLM context file (← FORK: rebrand)
│   ├── llms-full.txt           # Full LLM context (← FORK: rebrand)
│   ├── offline.html            # PWA offline fallback
│   ├── robots.txt
│   ├── data/                   # Public data files
│   └── favico/                 # Favicon assets (← FORK: replace)
├── scripts/                    # Build and utility scripts
│   ├── ais-relay.cjs           # DORMANT: AIS WebSocket relay
│   ├── build-sidecar-sebuf.mjs
│   ├── desktop-package.mjs
│   ├── download-node.sh
│   ├── sync-desktop-version.mjs
│   └── package.json
├── server/                     # Backend handler layer
│   ├── cors.ts                 # Server-side CORS
│   ├── error-mapper.ts         # Error → HTTP status mapping
│   ├── router.ts               # Static route map, O(1) lookup
│   ├── _shared/                # Cross-domain server utilities
│   │   └── redis.ts            # ← FORK: Create or modify — add prefixedKey() wrapper
│   └── worldmonitor/           # Domain handlers (20 domains)
│       └── {domain}/
│           └── v1/
│               └── handler.ts  # Domain-specific API logic
├── src/                        # Frontend SPA source
│   ├── App.ts                  # Thin shell (498 LOC) — delegates to src/app/ modules
│   ├── main.ts                 # Entry point (← FORK: +1 line for hook)
│   ├── settings-main.ts        # Settings page entry (ACTIVE — upstream feature)
│   ├── pwa.d.ts                # PWA type declarations
│   ├── vite-env.d.ts           # Vite environment types
│   ├── app/                    # [v2.5.8] App.ts decomposition modules
│   │   ├── app-context.ts      # Shared app state (108 LOC)
│   │   ├── data-loader.ts      # Data fetching orchestration (1,823 LOC)
│   │   ├── panel-layout.ts     # Panel lifecycle & grid (930 LOC)
│   │   ├── event-handlers.ts   # UI event routing (731 LOC)
│   │   ├── country-intel.ts    # Country intel aggregation (530 LOC)
│   │   ├── search-manager.ts   # Search & filtering (552 LOC)
│   │   ├── refresh-scheduler.ts # Timed refresh (108 LOC)
│   │   └── desktop-updater.ts  # Tauri desktop sync (205 LOC)
│   ├── bootstrap/              # App initialization
│   ├── components/             # 62 UI components
│   ├── config/                 # Build-time and runtime config
│   ├── e2e/                    # E2E test helpers
│   ├── generated/              # buf codegen output — NEVER HAND EDIT
│   ├── locales/                # i18n translations
│   ├── services/               # ~95 service modules
│   ├── styles/                 # CSS stylesheets
│   ├── types/                  # TypeScript type definitions
│   ├── utils/                  # Utility functions
│   ├── workers/                # Web Worker scripts (ML, analysis)
│   └── fork/                   # ← FORK: All fork-specific client code
│       ├── index.ts            # Fork entry point (Tier 2 hook)
│       ├── branding.ts         # Visual identity (CSS vars, meta, text)
│       ├── monitoring.ts       # Sentry initialization
│       ├── config.ts           # Fork-specific configuration
│       └── __tests__/          # Fork unit tests
│           ├── branding.test.mjs
│           └── config.test.mjs
├── src-tauri/                  # DORMANT: Desktop shell (Tauri)
├── tests/                      # Unit tests
│   ├── countries-geojson.test.mjs
│   ├── deploy-config.test.mjs
│   ├── gulf-fdi-data.test.mjs
│   ├── server-handlers.test.mjs
│   └── *.html                  # Test harness files
├── _bmad/                      # BMAD Method framework
├── _spec/                      # Specification artifacts
│   ├── planning-artifacts/     # PRD, architecture, UX
│   ├── implementation-artifacts/
│   └── test-artifacts/
├── fork.env.example            # ← FORK: Fork-specific env vars only
├── index.html                  # SPA shell (← FORK: meta tags, title)
├── settings.html               # Settings page shell (ACTIVE — upstream feature)
├── middleware.ts                # Vercel Edge Middleware (bot/UA filtering)
├── package.json                # Dependencies (← FORK: +Sentry = Tier 3)
├── tsconfig.json               # TypeScript config
├── tsconfig.api.json           # API-specific TS config
├── vite.config.ts              # Vite build config (variant-aware)
├── vercel.json                 # Vercel deployment config
├── playwright.config.ts        # E2E test config
├── Makefile                    # Build commands (generate, dev, test, lint)
├── CHANGELOG.md
├── README.md                   # (← FORK: rebrand)
├── CONTRIBUTING.md
├── LICENSE                     # AGPL-3.0
├── CODE_OF_CONDUCT.md
└── SECURITY.md
```

**Notes:**
- `server/_shared/redis.ts`: Exact upstream Redis utility path must be confirmed during implementation. The prefixedKey pattern applies wherever the Redis client is instantiated.
- `settings.html` / `settings-main.ts`: Active upstream feature for user preferences. Not mapped to fork-specific FRs but part of the inherited product.

### Architectural Boundaries

**API Boundaries:**
```
Client (SPA)  ─────┬─── sebuf RPC ──→  api/[domain]/v1/[rpc].ts → server/router.ts → handler
                    │
                    ├─── Legacy REST ──→  api/*.js (direct, no router)
                    │
                    └─── Fork REST ───→  api/fork/*.js (fork-specific, no router)
```

- sebuf RPC boundary: Client sends protobuf → RPC gateway validates → router dispatches → handler calls upstream API → returns protobuf
- Legacy REST boundary: Client sends JSON → endpoint handler processes → returns JSON
- Fork REST boundary: Same as legacy, scoped to `api/fork/`

**Component Boundaries:**
- `App.ts` owns all panel lifecycle — components don't communicate directly with each other
- Components → Services: components call service methods for data
- Services → Generated types: services use generated protobuf types for RPC calls
- Fork → App: fork hooks into app *after* initialization, can observe but shouldn't mutate internal state directly

**Data Boundaries:**
- **Redis** (`server/_shared/redis.ts`): All cache operations go through prefixed wrapper. No direct Redis client usage outside this module.
- **External APIs**: Each domain handler owns its external API calls. No cross-domain direct API calls.
- **Generated code** (`src/generated/`): Read-only boundary. Only `src/services/` and `server/` import from here. Fork code never imports directly.

### Data Flow

**API Pipeline:**
```
User Request (browser)
    │
    ▼
SPA (src/App.ts → src/services/ → fetch)
    │
    ▼
Edge Middleware (middleware.ts) ── bot? ──→ api/story.js → OG HTML
    │ (human)
    ▼
RPC Gateway (api/[domain]/v1/[rpc].ts)
    │
    ▼
Router (server/router.ts) → Handler (server/worldmonitor/{domain}/v1/handler.ts)
    │                              │
    │                              ▼
    │                    Redis Cache (prefixedKey)
    │                         │
    │                    hit? ─┤
    │                    │     │
    │                    ▼     ▼
    │                  return  External API → cache response → return
    │
    ▼
Response → SPA renders panel
```

**Web Worker Pipeline (ML/Analysis):**
```
SPA (main thread)
    │
    ├── postMessage() ──→ Web Worker (src/workers/)
    │                          │
    │                          ▼
    │                    ONNX Runtime (client-side ML inference)
    │                          │
    │                          ▼
    │                    Model output (classifications, embeddings)
    │                          │
    ◄── postMessage() ─────────┘
    │
    ▼
SPA renders AI-derived panel content
```

This is a completely separate data path from the API pipeline — compute-heavy work runs on worker threads, not the main thread.

### Requirements to Structure Mapping

**FR Category → Location:**

| FR Category | Primary Location | Supporting Files | Verification Location |
|---|---|---|---|
| Deployment & Infrastructure (FR1-FR4) | `vercel.json`, `.github/workflows/`, `Makefile` | `docs/API_KEY_DEPLOYMENT.md` | Vercel dashboard, CI logs |
| Data Integration (FR5-FR11) | `server/worldmonitor/*/v1/handler.ts` | `server/_shared/redis.ts`, `src/services/` | Each of 20 domain handlers (cross-cutting) |
| Visualization & UX (FR12-FR16) | `src/components/`, `src/App.ts` | `src/styles/`, `src/config/` | Manual browser QA (WebGL untestable in CI) |
| AI & Analysis (FR17-FR20) | `src/workers/`, `server/worldmonitor/*/v1/handler.ts` | `src/services/` | Worker output + API response verification |
| Sharing & Discovery (FR21-FR25) | `api/story.js`, `api/og-story.js`, `middleware.ts` | `public/llms.txt` | OG validator tools, curl bot UA tests |
| CI/CD & Quality (FR26-FR32) | `.github/workflows/`, `e2e/`, `tests/` | `playwright.config.ts`, `Makefile` | GitHub Actions history |
| Branding & Identity (FR33-FR38) | `src/fork/branding.ts`, `index.html`, `public/favico/` | `public/llms.txt`, `README.md` | Visual comparison, meta tag inspection |

**Cross-Cutting FR Verification:**

| FR | Description | Verification Strategy |
|---|---|---|
| FR10-11 | Graceful degradation for API keys | Test each of 20 domain handlers with missing keys — verify "not configured" state, not crash |
| FR33 | Codegen determinism | `make generate` in CI — diff output against committed `src/generated/` |
| FR14 | Graceful degradation (general) | Systematic failure injection per data source |

**Fork Decision → Location:**

| Decision | Files Impacted | Tier |
|---|---|---|
| Fork hook mechanism | `src/main.ts` (+1 line), `src/fork/index.ts` | 2 |
| Branding (CSS + meta) | `src/fork/branding.ts`, `index.html`, `public/favico/` | 1-2 |
| Redis prefix wrapper | `server/_shared/redis.ts` (create or modify) | 2 |
| Sentry monitoring | `src/fork/monitoring.ts`, `package.json` | 3 |
| Fork endpoints | `api/fork/*.js` | 2 |
| Fork env vars | `fork.env.example` | 1 |

### Growth-Phase Structure Expansion

Anticipated file locations for PRD Phase 2 (Growth) features:

| Growth Feature | Anticipated Location | Tier |
|---|---|---|
| Sitemap.xml generation | `api/fork/sitemap.js` | 2 |
| Enhanced `/api/story` for crawler pages | `api/story.js` (modify upstream) | 3 |
| SSR landing page | `api/fork/landing.js` + `public/landing.html` | 2 |
| Structured data (JSON-LD) | `src/fork/branding.ts` (extend) | 1 |
| `lighthouse-ci` in GitHub Actions | `.github/workflows/ci.yml` (modify) | 3 |
| Google Search Console sitemap submit | Manual — no code change | — |
| Automated upstream sync detection | `.github/workflows/upstream-sync.yml` (new) | 2 |
| Additional API key integrations | Vercel env vars only — no code change | — |

Growth stories should reference this table to place files correctly rather than creating ad-hoc structure.

### Development Workflow Integration

**Local Development (Two-Process Model):**
1. `make dev` — Vite dev server for SPA (HMR, instant reload)
2. `vercel dev` — API function emulation (edge + serverless)
- Note: Legacy REST endpoints may behave differently under `vercel dev` vs production (edge/serverless divergence)

**Build Process:**
1. `make generate` — proto → TypeScript codegen (`proto/` → `src/generated/`)
2. `make lint` — ESLint + TypeScript checking
3. `make build` — Vite production build (tree-shakes inactive variants)
4. `vercel build` — Packages API functions for deployment

**Deployment:**
- Merge to `main` → Vercel auto-deploys to Production
- PR/branch push → Vercel deploys to Preview (QA)
- CI must pass before merge is allowed

**Test Locations Summary:**

| Test Type | Location | Runtime |
|---|---|---|
| Upstream unit tests | `tests/*.test.mjs`, `api/*.test.mjs` | Node.js `node --test` |
| Fork client tests | `src/fork/__tests__/*.test.mjs` | Node.js `node --test` |
| Fork endpoint tests | `api/fork/*.test.mjs` | Node.js `node --test` |
| Upstream E2E tests | `e2e/*.spec.ts` | Playwright (Chromium + SwiftShader) |
| Fork E2E tests | `e2e/fork/*.spec.ts` | Playwright (Chromium + SwiftShader) |

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility: PASS**

| Decision A | Decision B | Compatible? | Notes |
|---|---|---|---|
| Single Redis instance + prefix | Vercel env vars for keys | ✅ | Redis URL shared across envs, prefix handles isolation |
| `src/fork/` wrapper layer | Sentry in `src/fork/monitoring.ts` | ✅ | Sentry lives entirely within fork layer |
| Tier system (1/2/3) | Upstream sync strategy | ✅ | Tiers directly map to merge risk, sync checklist references tiers |
| Fork REST endpoints | sebuf RPC gateway | ✅ | Fork endpoints bypass proto entirely (legacy style), no conflict |
| CSS `<style>` injection | CLS constraint | ✅ | Style block in `<head>` before first paint = zero CLS |
| Generated code isolation | Fork import rules | ✅ | Fork → services → generated. Clean chain. |

No contradictions detected. All 5 fork decisions reinforce each other.

**Pattern Consistency: PASS** — Naming conventions match upstream across all fork additions. Quick Reference Card aligns with detailed rules.

**Structure Alignment: PASS** — All fork directories sit within existing parent directories following upstream convention.

### Requirements Coverage Validation ✅

**Functional Requirements: 38/38 covered.**

| FR Range | Category | Architectural Support | Status |
|---|---|---|---|
| FR1-FR4 | Deployment & Infrastructure | Vercel config, CI/CD pipeline, upstream sync | ✅ |
| FR5-FR11 | Data Integration | Domain handlers, Redis prefix wrapper, graceful degradation | ✅ |
| FR12-FR16 | Visualization & UX | Inherited SPA architecture, fork branding layer | ✅ |
| FR17-FR20 | AI & Analysis | Web Worker pipeline, ONNX inference, Groq/OpenRouter fallback | ✅ |
| FR21-FR25 | Sharing & Discovery | OG pipeline, middleware bot detection, story endpoints | ✅ |
| FR26-FR32 | CI/CD & Quality | GitHub Actions, Playwright, buf breaking, node --test | ✅ |
| FR33-FR38 | Branding & Identity | `src/fork/branding.ts`, meta tags, favicons, llms.txt | ✅ |

**Non-Functional Requirements: All P0 NFRs covered** (NFR7, 8-9, 12-13, 15, 17, 26, 29, 33). P1/P2 NFRs covered by inherited infrastructure.

### Verification Gap Register

FRs with architectural homes but no automated test path — require manual QA on every related change:

| FR | Description | Why No Automation | Manual QA Action |
|---|---|---|---|
| FR12 | Globe visualization renders correctly | WebGL untestable in CI (SwiftShader) | Visual browser check on Preview |
| FR13 | Panel data renders in correct format | Component rendering is visual | Open each affected panel, verify data display |
| FR14 | Cross-panel correlation is intuitive | UX quality is subjective | Walkthrough user journey on Preview |
| FR15 | Mobile responsive layout works | SwiftShader CI lacks touch/viewport testing | Test on physical device or responsive DevTools |
| FR16 | Dark theme renders correctly | CSS visual output | Visual check across panels |
| FR35 | OG card branding is visually correct | Image output verification | Use OG preview validator (opengraph.xyz) |

**6 of 38 FRs (16%) require manual QA.** All are visual/UX requirements where automated CI provides zero coverage due to SwiftShader limitations.

### Failure Mode Validation

| Failure Scenario | Expected Behavior | Architectural Basis |
|---|---|---|
| `src/fork/index.ts` throws during initialization | Upstream SPA loads normally without fork customizations. Fork errors are caught by try/catch in the hook. Console.warn logs the error. | Fork error handling pattern: every fork function wraps in try/catch with graceful fallback |
| Redis `prefixedKey()` wrapper throws | Handler falls through to direct upstream API call (slower but functional). No crash. | Graceful degradation pattern (NFR26): Redis failure → direct upstream |
| Sentry SDK fails to initialize (bad DSN, network) | Sentry silently disabled. No error thrown. App functions normally without monitoring. | Sentry SDK design: no DSN = no-op. Network failure = queued/dropped silently |
| API key missing for a domain | Panel shows "not configured" empty state. Other panels unaffected. | FR10-11: graceful degradation per-panel. Single-source failure isolation (NFR15) |
| Upstream merge breaks `main.ts` hook line | `make build` fails in CI. Deploy blocked. Fork customizations absent on the broken build. | CI pipeline catches build failure. Upstream sync checklist requires verifying `main.ts` hook |
| CSS custom property override has no effect (upstream hardcodes values) | Branding partially applied — variables that exist override, hardcoded values don't. Visual inconsistency but no crash. | Spike story gate #2 audits CSS variable coverage. Architecture doc updated with findings. |

### Gap Analysis Results

**Critical Gaps: None.**

**Important Gaps (2 — intentionally deferred to implementation):**

| Gap | Mitigation |
|---|---|
| Hook mechanism TBD | Spike story has 3 pass/fail gates — will resolve |
| Redis wrapper path unconfirmed | Implementation story discovers actual path first |

**Minor Gaps (1):**

| Gap | Mitigation |
|---|---|
| Import order not lint-enforced | Marked advisory; lint rule is Growth-phase improvement |

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context analyzed (brownfield fork, deployed, verified)
- [x] Scale and complexity assessed (High — 20 domains, 35+ APIs)
- [x] Technical constraints identified (Vercel Hobby, Upstash Free, inherited arch)
- [x] Cross-cutting concerns mapped (5 concerns + graceful degradation as core pattern)

**✅ Architectural Decisions**
- [x] Critical decisions documented (5 fork-specific + 13 inherited)
- [x] Technology stack specified (inherited, no new selections)
- [x] Integration patterns defined (API, component, data boundaries)
- [x] Performance considerations addressed (free tier limits, 10s serverless budget)

**✅ Implementation Patterns**
- [x] Naming conventions established (matching upstream exactly)
- [x] Structure patterns defined (fork files, endpoints, tests)
- [x] Communication patterns specified (Redis via wrapper, errors via mapper)
- [x] Process patterns documented (graceful degradation, loading states, imports)
- [x] Quick Reference Card for AI agents
- [x] Anti-pattern table (8 entries)
- [x] Hard Rules vs Conventions distinction

**✅ Project Structure**
- [x] Complete directory structure with fork annotations
- [x] Component boundaries established
- [x] Integration points mapped (API pipeline + Web Worker pipeline)
- [x] Requirements to structure mapping (all 38 FRs)
- [x] Growth-phase expansion table
- [x] Test organization for all code categories

**✅ Validation**
- [x] Coherence validation passed
- [x] Requirements coverage verified (38/38 FRs, all P0 NFRs)
- [x] Failure modes documented (6 scenarios)
- [x] Verification gaps registered (6 FRs needing manual QA)
- [x] Implementation readiness confirmed

**Confidence Level:**
- Inherited architecture: **HIGH** — deployed and verified working
- Fork-specific decisions: **MEDIUM** — theoretically sound, pending spike validation

**Areas for Future Enhancement:**
- `eslint-plugin-import` for import order enforcement (Growth phase)
- `App.ts` decomposition study if fork needs Tier 3 panel changes (Vision phase)
- Automated upstream sync detection with GitHub Actions (Growth phase)

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use the Quick Reference Card as the first-check decision tree
- Declare fork tier (1/2/3) before starting any change
- Respect the generated code import boundary (`src/fork/` → `src/services/`, never `src/generated/`)
- Use `[fork]` commit prefix for all fork changes
- Consult the Failure Mode Validation for error handling expectations
- Check Verification Gap Register for FRs requiring manual QA

**Implementation Priority with Definition of Done:**

| Step | Task | Definition of Done |
|---|---|---|
| 1 | Create `src/fork/` structure + `main.ts` hook | Files exist, `make lint` passes, `make build` succeeds, Vercel Preview deploys |
| 2 | Fork Pattern Validation Spike | 3 pass/fail gates answered (hook works, CSS propagates, deploys clean), results documented in architecture doc |
| 3 | Configure Upstash Redis with prefixed wrapper | `prefixedKey()` exists, all existing Redis calls use it, `make test` passes |
| 4 | Apply branding (metadata + CSS overrides) | Visual diff visible on Vercel Preview, CLS = 0, `fork.env.example` updated |
| 5 | Add Sentry monitoring (Tier 3) | Errors appear in Sentry dashboard from Preview deployment, `package.json` updated, breadcrumb filter active |

## Spike Validation Record (Story 0.1)

Date: 2026-02-25
Story: `0-1-fork-pattern-validation-spike`

| Gate | Status | Evidence |
|---|---|---|
| Gate 1 — Tier 2 hook works | PASS | `src/main.ts` imports `./fork/index` after `app.init()` and calls `init()` with error fallback. |
| Gate 2 — CSS variable propagation | PASS | `src/fork/index.ts` injects `<style id="fork-theme">` with `--accent`, `--bg`, and `--surface` overrides and cascade verification. |
| Gate 3 — Vercel Preview deployment | PASS | Vercel Preview deployment confirmed 2026-02-26: site loads without errors, fork theme visible, CLS = 0. Build succeeds locally and in Preview. |

Scope note: Story 0.1 validates the primary app entry point path only. Secondary entry points (`settings` / `live-channels`) are deferred to Epic 2.
