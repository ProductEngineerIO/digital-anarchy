---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _spec/planning-artifacts/prd.md
  - _spec/planning-artifacts/architecture.md
  - _spec/planning-artifacts/ux-design-specification.md
---

# Situation Monitor - Epic Breakdown

> **v2.5.8 Sync Update (2025-06-10):** ARCH-35/36/59/60 revised — `App.ts` decomposed from 4,629 LOC God Object to 498 LOC shell + 8 `src/app/` modules. Merge risk significantly reduced. FR3 updated to 20 domains (was 17). ARCH-4 updated for 4 build variants (was 3). Story 0.1 spike expanded to evaluate modular hook targets. Story 6.1 merge risk map updated. Component count corrected from 52 to 62.

## Overview

This document provides the complete epic and story breakdown for Situation Monitor, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

## Fork Development Contract (Cross-Cutting Definition of Done)

Every fork story in every epic MUST satisfy ALL of the following before merge:

1. **Tier Declared** — Story states its hook tier (1/2/3); Tier 3 includes justification for why Tier 1/2 is insufficient (ARCH-9)
2. **Graceful Degradation** — Every fork function wraps in try/catch with `console.warn('[fork] ...')` fallback; fork errors never crash upstream (ARCH-25)
3. **Token-Only Styling** — Uses `--sm-*` or upstream semantic tokens; zero hardcoded hex values (UX-REQ-30)
4. **Fork DOM Convention** — Uses `data-sm-*` attributes for CSS targeting; no new DOM IDs (UX-REQ-32)
5. **Companion Tests** — Unit test in `src/fork/__tests__/` using `node --test`; Tier 2 patches include signature assertions (ARCH-21, UX-REQ-42)
6. **No Upstream Mods** — Zero upstream file modifications unless Tier 3 justified and documented as merge debt (ARCH-12)

## Requirements Inventory

### Functional Requirements

FR1: Users can view a 3D globe with real-time data overlay clusters representing active global events
FR2: Users can click globe clusters to navigate to specific countries or regions and see detailed data
FR3: Users can view data panels for each of the 20 intelligence domains (conflict, seismology, cyber, energy, markets, trade, giving, positive events, etc.)
FR4: Users can cross-reference data across multiple domain panels simultaneously (e.g., conflict + markets + prediction markets)
FR5: Users can view AI-generated summaries and threat classifications for countries and regions
FR6: Users can view a Country Instability Index with threat level indicators per country
FR7: Users can view prediction market data (Polymarket) alongside geopolitical and threat assessments
FR8: The system can aggregate data from 35+ external sources across 17 intelligence domains
FR9: The system can cache AI summaries and threat classifications via a multi-tier cache (in-memory → Redis → upstream API)
FR10: The system can degrade gracefully when any individual data source is unavailable, misconfigured, or rate-limited — affected panels display an informative status rather than crashing
FR11: The system can operate with any subset of API keys configured — panels with available keys show data, panels without keys show a "not configured" state
FR12: The system can fall back through the AI summarization chain (Groq → OpenRouter → browser-side T5) when higher-priority providers are unavailable
FR13: Users can share country-specific analysis URLs that generate rich social preview cards (OG title, description, image)
FR14: The system can detect social media crawler bots and serve them HTML with OpenGraph meta tags
FR15: The system can generate dynamic OG preview images with country name, instability score, threat level, and branding
FR16: Real users clicking shared links are redirected to the SPA with deep-link parameters that auto-navigate to the relevant country and analysis panel
FR17: The system can serve story URLs (`/api/story`) as HTML pages for crawlers, supporting search engine indexability
FR18: Users can view previously cached data when network connectivity is lost
FR19: The system can serve static assets from cache and fetch data over network (cache-first for assets, network-first for data)
FR20: Users can access an offline fallback page when the full application cannot load
FR21: The operator can deploy the application to separate Preview (QA) and Production environments
FR22: The operator can configure environment variables (API keys, Redis URLs) scoped independently per environment
FR23: The system can maintain separate Redis cache instances (or key prefixes) for QA and Production to prevent cross-environment cache pollution
FR24: The operator can promote changes from QA to Production only after validation in the Preview environment
FR25: The operator can verify the build configuration (rewrites, cache headers, route patterns) resolves correctly after deployment
FR26: The system can run an automated quality gate on every pull request (lint, unit tests, proto breaking change detection, build, E2E tests)
FR27: The system can block production deployment when the CI pipeline fails
FR28: The operator can run an endpoint smoke test script that validates all 57 endpoints return non-error responses
FR29: The operator can run a Lighthouse audit against the deployed Preview environment and record baseline scores
FR30: Every PR that changes fork-specific code includes at least one test exercising the changed path
FR31: The operator can merge upstream changes via a dedicated `upstream-sync` branch without affecting the main branch
FR32: The operator can run proto/sebuf codegen (`make generate`) and verify generated output matches committed files after an upstream merge
FR33: The system can detect proto breaking changes via `buf breaking` as part of the CI pipeline
FR34: The operator can run the full test suite against the upstream-sync branch before merging to main
FR35: The application displays Situation Monitor branding (not World Monitor) in page titles, meta tags, and descriptions
FR36: The LLM discoverability files (`llms.txt`, `llms-full.txt`) reflect Situation Monitor identity and content
FR37: Generated OG preview images display Situation Monitor branding
FR38: The system serves a `robots.txt` that permits crawling of public pages

### NonFunctional Requirements

NFR1: Initial page load (Largest Contentful Paint) completes in under 4 seconds on broadband connections (P1)
NFR2: Globe becomes interactive (Time to Interactive) within 6 seconds of navigation (P1)
NFR3: Individual data panel refreshes complete within 2 seconds of user action or data request (P1)
NFR4: Static assets are served with immutable cache headers (≥1 year) to eliminate redundant downloads on repeat visits (P2)
NFR5: The service worker caches static assets on first visit, enabling sub-second repeat load times for cached resources (P2)
NFR6: Edge function responses return within 500ms for Redis cache hits. Cold starts may add up to 2 seconds on first invocation per region. (P1)
NFR7: OG image generation completes within Vercel Hobby tier constraints (10-second serverless timeout, 128MB memory) (P0)
NFR8: API keys are never committed to source control or exposed in client-side code (P0)
NFR9: API keys are stored exclusively as Vercel environment variables, scoped per deployment environment (Preview vs Production) (P0)
NFR10: The edge middleware blocks known scraper and abuse bot user-agents while allowing legitimate social preview bots (P2)
NFR11: No user authentication data or personally identifiable information is collected, stored, or transmitted (P2)
NFR12: All traffic between users and Vercel is served over HTTPS (enforced by Vercel infrastructure) (P0)
NFR13: Redis connections use TLS encryption (enforced by Upstash) (P0)
NFR14: Site availability of 99%+ as provided by Vercel's infrastructure (no self-managed uptime obligation) (P1)
NFR15: Failure of any single external data source does not cause application-wide errors — other panels continue functioning normally (P0)
NFR16: The CI pipeline produces identical pass/fail results on re-run of the same commit. Any test that fails intermittently is quarantined within 24 hours and fixed or removed within one week. (P1)
NFR17: Zero post-deployment regressions — every change passes through QA (Preview) before reaching Production (P0)
NFR18: The service worker provides continuity during brief network interruptions — cached views remain accessible, data refreshes when connectivity returns (P2)
NFR19: All non-globe UI elements (panels, controls, text content) meet WCAG 2.1 AA contrast ratios (4.5:1 for normal text, 3:1 for large text) (P2)
NFR20: All interactive elements are reachable via keyboard Tab navigation in a logical order (P2)
NFR21: Focus indicators are visually distinct when navigating via keyboard (not suppressed for aesthetics) (P2)
NFR22: Screen readers can access panel text content including AI summaries, event lists, and data tables (P2)
NFR23: The offline fallback page meets basic accessibility standards (readable, navigable) (P2)
NFR24: The system tolerates external API response times up to 10 seconds before timing out and falling back to cached data or degraded state (P1)
NFR25: The system retries transient failures (5xx, network timeout) for external APIs with appropriate backoff — no retry storms (P1)
NFR26: Redis unavailability causes graceful degradation to direct upstream API calls, not application failure (P0)
NFR27: The AI summarization fallback chain (Groq → OpenRouter → browser-side T5) activates automatically without operator intervention (P1)
NFR28: External API rate limit responses (429) are handled by backing off and serving cached data where available (P1)
NFR29: Total monthly infrastructure cost remains at $0 across Vercel, Upstash, and all API providers. Any billable usage triggers investigation before the next billing cycle. (P0)
NFR30: Daily Upstash Redis command count stays below 8,000 (80% of free tier limit of 10,000). If exceeded, investigate caching patterns before tier upgrade. (P1)
NFR31: Environment variable changes propagate to Preview deployments within 2 minutes. Production deployment completes within 5 minutes of merge to main. (P1)
NFR32: The endpoint smoke test script (`scripts/validate-endpoints.sh`) can be run with any single API key removed to verify graceful degradation per domain. (P1)
NFR33: Running `make generate` on a clean checkout produces byte-identical output to the committed `src/generated/` files. Any drift fails the CI pipeline. (P0)

### Additional Requirements

#### From Architecture

**Infrastructure / Deployment Constraints:**
- ARCH-1: Vercel Hobby Tier imposes 100GB/month bandwidth limit — all architectural decisions must account for this ceiling
- ARCH-2: Upstash Redis Free Tier imposes 256MB storage limit alongside the command quota
- ARCH-3: Dual runtime model: Edge Functions (middleware, RPC gateway) and Serverless Functions (legacy API, OG image) have different timeout limits, memory models, and execution constraints — code must target the correct runtime
- ARCH-4: `VITE_VARIANT=full` is the primary build variant for the fork; upstream also ships tech, finance, and happy variants (4 total) — fork deploys `full` only
- ARCH-5: Three Tauri desktop config files are dormant for web-only deployment — do not modify or depend on them
- ARCH-6: Convex and Railway AIS Relay are dormant infrastructure — present in repo but excluded from architecture
- ARCH-7: Local development requires a two-process model: `make dev` (Vite SPA) + `vercel dev` (API emulation)
- ARCH-8: Build process is a strict 4-step pipeline: `make generate` → `make lint` → `make build` → `vercel build`

**Fork Hook Tier System:**
- ARCH-9: Every fork story MUST declare its tier (1/2/3) before implementation; Tier 3 changes require explicit justification
- ARCH-10: Tier 1 (Zero-touch): CSS custom property overrides, `<meta>` tags, favicon swap, static asset replacement
- ARCH-11: Tier 2 (Single-line hook): One import added to `main.ts` that runs after app init; all logic lives in `src/fork/`
- ARCH-12: Tier 3 (Upstream modification): Any change touching upstream files beyond the single `main.ts` hook — tracked as merge debt
- ARCH-13: The actual hook mechanism (DOM-ready callback, global event bus, or direct import) is TBD — the spike story must discover it
- ARCH-14: Sentry SDK addition is Tier 3 (modifies `package.json`, creating permanent merge debt)

**Fork Directory Structure & Code Isolation:**
- ARCH-15: Fork client code lives exclusively in `src/fork/` with defined files: `index.ts`, `branding.ts`, `monitoring.ts`, `config.ts`, and `__tests__/`
- ARCH-16: Fork-specific server endpoints go in `api/fork/` as legacy REST `.js` files — never create new proto domains for fork features
- ARCH-17: Fork E2E tests go in `e2e/fork/` — created as needed, not speculatively
- ARCH-18: `fork.env.example` documents fork-specific env vars only
- ARCH-19: Do NOT include `panels.ts` in initial structure — add only when a story requires panel customization
- ARCH-20: Fork code (`src/fork/**`) MUST NOT import directly from `src/generated/**` — import from `src/services/` or `src/types/`
- ARCH-21: Fork testing contract: all code in `src/fork/` requires unit tests in `src/fork/__tests__/` using `node --test`

**Implementation Patterns & Conventions:**
- ARCH-22: Fork branding uses `<style id="fork-theme">` block injected into `<head>` with `:root` overrides — `document.documentElement.style.setProperty()` is forbidden
- ARCH-23: Fork branding must not cause Cumulative Layout Shift > 0; DOM additions must be present in initial HTML or injected before first paint
- ARCH-24: Fork changes use `[fork] description` commit prefix; upstream syncs use `[sync] merge upstream vX.Y.Z`
- ARCH-25: Every fork function wraps in try/catch with graceful fallback and `console.warn('[fork] ...')` — fork errors must never crash the upstream app
- ARCH-26: Fork files use kebab-case filenames, named exports, strict TypeScript, with the try/catch graceful degradation pattern
- ARCH-27: 8 explicit anti-patterns defined: no React/Vue/Angular, no `src/generated/` imports in fork, no new proto definitions for fork, no `FLUSHDB`/`FLUSHALL`, no `@ts-ignore` without explanation, no `App.ts` mods without Tier 3 justification, no raw `fetch()` in fork code, no generated code imports in fork
- ARCH-28: Components use CSS classes (`.is-loading`, `.has-error`, `.is-empty`) not JS-driven visibility toggles; panels show skeleton/placeholder, not spinners

**Data Architecture Patterns:**
- ARCH-29: Redis key prefix (`qa:` / `prod:`) is enforced at the client wrapper level via `prefixedKey()` — direct Redis calls bypassing the wrapper are forbidden
- ARCH-30: A careless `FLUSHDB` nukes both environments — mitigated by never using `FLUSHDB`; use prefix-scoped `SCAN` + `DEL` instead
- ARCH-31: Date/time encoding: ISO 8601 strings in JSON responses, Unix timestamps in proto messages
- ARCH-32: API error responses follow: HTTP status codes + JSON `{ error: string }` body; server errors use `error-mapper.ts`
- ARCH-33: Three-tier cache hierarchy (in-memory → Redis → upstream) with QA/Prod isolation is the canonical caching pattern

**Upstream Sync Workflow:**
- ARCH-34: Upstream sync pattern: dedicated `upstream-sync` branch → merge upstream → full test suite → PR into `main`
- ARCH-35: ~~`App.ts` was a 4,629 LOC God Object~~ **[v2.5.8 UPDATE]** Upstream decomposed `App.ts` into a 498 LOC shell + 8 modules in `src/app/` (data-loader 1,823 LOC, panel-layout 930 LOC, event-handlers 731 LOC, country-intel 530 LOC, search-manager 552 LOC, app-context 108 LOC, refresh-scheduler 108 LOC, desktop-updater 205 LOC). Fork hooks can now target specific modules rather than instrumenting a monolith. Merge risk is significantly reduced.
- ARCH-36: Merge Risk Map **[v2.5.8 UPDATE]**: Critical = `src/app/panel-layout.ts`, `src/app/data-loader.ts`; High = `proto/**`, `src/generated/**`, `src/app/event-handlers.ts`; Medium = domain handlers, `package.json`, other `src/app/` modules; Low = `App.ts` (now thin shell), `public/`, `index.html`
- ARCH-37: Post-merge checklist: verify `main.ts` fork hook intact, run `make generate`, resolve `package.json` conflicts, run full test suite
- ARCH-38: Proto sync: run `make generate` after every upstream merge; if upstream changes the codegen tool, catch it before it silently breaks the build
- ARCH-39: Codegen dependency chain: `.proto` change → `buf generate` → `src/generated/` → `server/` imports; proto changes cascade across four directories

**Monitoring / Observability:**
- ARCH-40: Sentry free tier (5K errors/month) for client-side error tracking — surfaces crashes invisible to Vercel logs
- ARCH-41: Sentry environment tagging MUST use `VITE_VERCEL_ENV` (not Vite `MODE`)
- ARCH-42: Sentry `beforeBreadcrumb` filters external API fetch noise — only same-origin breadcrumbs captured
- ARCH-43: No Sentry DSN = Sentry silently disabled (follows graceful degradation pattern)
- ARCH-44: Sentry SDK adds ~20KB gzipped to bundle size
- ARCH-45: Solo operator observability constraint: if it can't be diagnosed from Vercel logs + Upstash dashboard + Sentry, it's too complex

**Testing & Verification Gaps:**
- ARCH-46: SwiftShader (software WebGL) in CI means visual features are effectively untestable in automated CI — require manual QA
- ARCH-47: Test runtime bifurcation: E2E in Chromium (Playwright), unit tests in Node.js — no shared test utility layer
- ARCH-48: 6 of 38 FRs (FR12–FR16, FR35) require manual QA — all visual/UX requirements with zero automated CI coverage
- ARCH-49: `buf breaking` is the ONLY automated API contract validation in the pipeline

**Spike & Validation Requirements:**
- ARCH-50: Fork Pattern Validation Spike must answer 3 pass/fail gates: (1) Does the Tier 2 hook mechanism work? (2) Do CSS variable changes propagate to all components? (3) Does it deploy cleanly to Vercel Preview?
- ARCH-51: Spike must also discover: actual hook mechanism and CSS variable coverage audit — results documented back into architecture doc
- ARCH-52: If spike fails any gate, revise the fork pattern before proceeding

**Growth-Phase Expansion (Architectural Pre-Mapping):**
- ARCH-53: Sitemap.xml generation → `api/fork/sitemap.js` (Tier 2)
- ARCH-54: Enhanced `/api/story` for crawler pages → modify upstream `api/story.js` (Tier 3)
- ARCH-55: SSR landing page → `api/fork/landing.js` + `public/landing.html` (Tier 2)
- ARCH-56: Structured data (JSON-LD) → extend `src/fork/branding.ts` (Tier 1)
- ARCH-57: `lighthouse-ci` in GitHub Actions → modify `.github/workflows/ci.yml` (Tier 3)
- ARCH-58: Automated upstream sync detection → new `.github/workflows/upstream-sync.yml` (Tier 2)

**Architectural Modularity (formerly God Object Risk):**
- ARCH-59: **[v2.5.8 UPDATE]** `App.ts` has been decomposed into `src/app/` modules. Component lifecycle is managed by `panel-layout.ts` (930 LOC), event routing by `event-handlers.ts` (731 LOC), and data management by `data-loader.ts` (1,823 LOC). Fork customizations can target specific modules — the monolithic bottleneck no longer exists.
- ARCH-60: **[v2.5.8 UPDATE]** Panel behavior now routes through `src/app/panel-layout.ts` and `src/app/event-handlers.ts` rather than a single `App.ts` God Object. Fork hooks should still observe but not mutate internal state — but can now hook at module boundaries (e.g., panel ordering in `panel-layout.ts`).

#### From UX Design

**Interaction Flow Requirements:**
- UX-REQ-1: Scan → Drill → Correlate three-phase loop; all three drill entry points (globe click, deep-link URL, ⌘K search) must produce identical panel activation results
- UX-REQ-2: Scan Depth Tiers — Glance (5s), Read (15–30s), Study (1–2min) without mode switching; each tier has exit ramp
- UX-REQ-3: Deep-Link Animation Skip — When `?c=` URL param is present, bypass ~800ms globe spin and snap to country view (~30 LOC, Tier 2 patch)
- UX-REQ-4: Deep-Link Invalid Param Fallback — bad country code or unknown panel type falls back to globe home view with World Brief
- UX-REQ-5: Rate-Limit Burst Handling on Shared Links — 1000+ simultaneous clicks serve cached/degraded version silently

**Data State Handling Requirements:**
- UX-REQ-6: Eight Panel Data States — Loading/Loaded/Stale(aging)/Stale(critical)/Error(transient)/Error(persistent)/Empty/Degraded with specific visual treatments per state
- UX-REQ-7: Never Show Blank Panel — panels always display skeleton → content → stale content → empty state
- UX-REQ-8: Never Hide Stale Data — stale data with timestamp is always preferred over loading spinner; stale-while-revalidate throughout
- UX-REQ-9: Per-Panel Independence — one panel's failure never affects another panel; no global error overlays for single-source failures

**Data Age Gradient & Freshness Requirements:**
- UX-REQ-10: Data Age Gradient via CSS saturation filter; `data-freshness` attribute (`fresh`|`aging`|`stale`) drives `saturate()` CSS filter (~10 LOC)
- UX-REQ-11: CSS Transition on Freshness State Changes — `transition: filter 2s ease`; disabled under `prefers-reduced-motion`
- UX-REQ-12: Per-Data-Source Freshness Thresholds — configurable per source type (earthquakes: 10min/30min, predictions: 1h/3h, news: 15min/1h, etc.)
- UX-REQ-13: `RelativeTimeFormatter` Utility — single `setInterval` updating every 60s; pre-computes bracket thresholds, only updates on bracket change (~40 LOC)
- UX-REQ-14: Stale Data Warning Bars — hidden if <24h, amber at 24h–72h, red at >72h; always visible to all users (~80 LOC)

**Accessibility Requirements (Beyond WCAG AA):**
- UX-REQ-15: `AriaAnnouncer.ts` — single `aria-live="polite"` region with 2-second debounce batching panel state changes (~30 LOC)
- UX-REQ-16: OperatorDrawer Focus Trap — focus moves to first element, Tab cycles within drawer, Escape restores focus to badge
- UX-REQ-17: `prefers-reduced-motion` blanket rule for all fork animations via `[data-sm-component]` selector (~3 LOC)
- UX-REQ-18: Fork Component ARIA Labels — specific `aria-label` for each fork interactive element (HealthIndicator, OperatorBadge, OperatorDrawer, warning bars)
- UX-REQ-19: Data Age Gradient Accessible Supplement — text timestamp + warning bar provide same freshness info; no color-only signaling
- UX-REQ-20: Color Blindness text labels alongside traffic-light signals; no color-only information signaling

**Responsive & Mobile-Specific Requirements:**
- UX-REQ-21: OperatorDrawer full viewport width below 768px breakpoint
- UX-REQ-22: Touch Targets ≥ 44×44px for all interactive fork elements on mobile
- UX-REQ-23: 320px minimum viewport width support
- UX-REQ-24: `WhatYouMissedPanel` mobile anchor — banner above panel grid (Growth phase)
- UX-REQ-25: `HotspotDelta` SVG equivalent on mobile for DeckGL/D3 SVG fallback (Growth phase)

**Animation & Transition Specifications:**
- UX-REQ-26: Interaction speed targets: theme injection <200ms, globe render <2s, panel skeleton→content <3s, deep-link snap <1s, search modal <100ms, panel collapse/expand <200ms, panel drag 60fps, globe fly-to ~800ms, modal overlay <100ms
- UX-REQ-27: Skeleton Loader Only — no spinners; skeleton indicates shape of incoming content
- UX-REQ-28: Panel Header Renders Immediately — only body shows skeleton animation
- UX-REQ-29: Hotspot Delta Pulse Timing — 10s pulse then static teal ring; disabled under `prefers-reduced-motion` (Growth phase)

**Design System Token & Convention Requirements:**
- UX-REQ-30: `--sm-*` namespace enforcement — no hardcoded hex values; CI grep check
- UX-REQ-31: Accent Restraint Rule — `--sm-accent` for identity only (header brand mark, active state, hotspot emphasis, share CTA); prohibited for panel headers, body text links, data values
- UX-REQ-32: `data-sm-*` DOM attribute convention for all fork elements; no new DOM IDs from fork code
- UX-REQ-33: CSS Cascade Position Rule — `<style id="fork-theme">` must be last stylesheet in `<head>`; E2E assertion required
- UX-REQ-34: No `!important` in fork CSS (sole exception: `prefers-reduced-motion` blanket rule); CI lint check
- UX-REQ-35: Light Mode Defensive Teal Override — `[data-theme="light"] { --accent: var(--sm-accent-light, #00838f); }` for 4.6:1 AA contrast
- UX-REQ-36: No New CSS Classes in Upstream Stylesheets — fork styles exclusively in `theme-inject.ts` or `theme.css`
- UX-REQ-37: FOUC Prevention — CSS tokens inlined as template literal in `theme-inject.ts`; no external CSS file load

**Performance Instrumentation Requirements:**
- UX-REQ-38: `performance.mark()` at fork lifecycle points: `sm-theme-injected`, `sm-globe-rendered`, `sm-panels-loaded`, `sm-deep-link-resolved` (~15 LOC)
- UX-REQ-39: Branding Injection < 200ms assertion via Playwright Performance API

**Testing Requirements (UX-Specific):**
- UX-REQ-40: Playwright Visual A11y Tests — `@axe-core/playwright` in `e2e/accessibility.spec.ts` (~30 LOC)
- UX-REQ-41: OperatorDrawer Focus Trap Test — dedicated test
- UX-REQ-42: Tier 2 Patch Signature Assertions — `console.assert` verifying original method exists with expected arity; tested in companion `*.test.ts`
- UX-REQ-43: Fork CSS Lint CI Checks — grep for hardcoded hex, missing `aria-label`, `data-sm-*` attributes, `!important` violations
- UX-REQ-44: `prefers-reduced-motion` system toggle test — verify HotspotDelta pulse disabled and freshness transition instant
- UX-REQ-45: Post-Upstream-Sync Visual Verification < 2 Minutes — Playwright screenshot comparison of 3 key views + DOM assertions

**Pattern Adoption Checklist:**
- UX-REQ-46: PR Checklist for Fork Components — 18-point checklist including token usage, accent restraint, skeleton loaders, stale data preservation, ARIA labels, touch targets, reduced motion, and focus trap testing

**Component-Level UX Behaviors:**
- UX-REQ-47: `HealthIndicator` — 8px colored dots in panel headers for data source freshness; operator-gated (~120 LOC)
- UX-REQ-48: `OperatorBadge` + `OperatorDrawer` split architecture — badge always rendered, drawer lazy-loads on click
- UX-REQ-49: Startup Compatibility Notification — dismissible amber bar when Tier 2 monkey-patch signature assertion fires; operator-only, once per session
- UX-REQ-50: No Toast/Snackbar Notifications — data changes communicated through panel content updates only
- UX-REQ-51: Modal Rules — one modal at a time, background scroll lock, Escape always closes, click-outside for non-critical
- UX-REQ-52: Default Panel Order Configuration — fork-specific default sequence from `src/fork/config/default-panel-order.ts` placing priority correlation pairs adjacent
- UX-REQ-53: InsightsPanel Position-Locked Above Fold — P0 requirement for scan phase
- UX-REQ-54: Globe Empty State — always shows country boundaries immediately from static TopoJSON
- UX-REQ-55: Panel Empty State — light italic "No {dataType} data available for {countryName}"
- UX-REQ-56: Search Empty State — "No results for '{query}'" with suggestion text
- UX-REQ-57: InsightsPanel Generating State — skeleton with "Generating world brief..." placeholder
- UX-REQ-58: Uniform Globe Detection — must ensure baseline visual activity even during calm periods
- UX-REQ-59: Overwhelming Globe Prevention — severity weighting must create visual contrast hierarchy

**Growth-Phase UX Requirements:**
- UX-REQ-60: Hotspot Delta Detection — pulsing teal ring around new/escalated markers; delta from localStorage via `VisitTracker.ts` (~150 LOC)
- UX-REQ-61: "What You Missed" Panel — collapsible card at top of InsightsPanel for returning visitors (~180 LOC)
- UX-REQ-62: `VisitTracker.ts` Service — localStorage-based visit tracking with versioned schema (~120 LOC)
- UX-REQ-63: MobileWarningModal Softening — suppress/replace "desktop recommended" modal for deep-link arrivals
- UX-REQ-64: Panel-to-Panel Highlighting — click country in CII panel highlights corresponding data in correlation pairs

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Upstream (inherited) | 3D globe with real-time data overlay clusters |
| FR2 | Upstream (inherited) | Click globe clusters to navigate to countries |
| FR3 | Upstream (inherited) | Data panels for 17 intelligence domains |
| FR4 | Upstream (inherited) + Epic 9 (Growth enhancement) | Cross-panel correlation |
| FR5 | Upstream (inherited) | AI-generated summaries and threat classifications |
| FR6 | Upstream (inherited) | Country Instability Index |
| FR7 | Upstream (inherited) | Prediction market data (Polymarket) |
| FR8 | Upstream (inherited) | Aggregate 35+ external sources |
| FR9 | Upstream (inherited) | Multi-tier cache (in-memory → Redis → upstream) |
| FR10 | Epic 4: Panel Data States & Freshness | Graceful degradation UX |
| FR11 | Epic 4: Panel Data States & Freshness | Operate with any subset of API keys |
| FR12 | Upstream (inherited) | AI summarization fallback chain |
| FR13 | Epic 3: Social Sharing & Deep Links | Share country-specific analysis URLs |
| FR14 | Epic 3: Social Sharing & Deep Links | Detect social media crawler bots |
| FR15 | Epic 3: Social Sharing & Deep Links | Generate dynamic OG preview images |
| FR16 | Epic 3: Social Sharing & Deep Links | Deep-link redirect with auto-navigate |
| FR17 | Epic 3: Social Sharing & Deep Links | Story URLs as HTML for crawlers |
| FR18 | Upstream (inherited) | View cached data offline |
| FR19 | Upstream (inherited) | Cache-first assets, network-first data |
| FR20 | Upstream (inherited) | Offline fallback page |
| FR21 | Epic 1: Deployment & Quality Pipeline | Deploy to Preview/Production |
| FR22 | Epic 1: Deployment & Quality Pipeline | Environment variables per environment |
| FR23 | Epic 1: Deployment & Quality Pipeline | Redis key-prefix QA/Prod isolation |
| FR24 | Epic 1: Deployment & Quality Pipeline | Promote QA → Production after validation |
| FR25 | Epic 1: Deployment & Quality Pipeline | Verify build configuration post-deploy |
| FR26 | Epic 1: Deployment & Quality Pipeline | Automated CI quality gate on every PR |
| FR27 | Epic 1: Deployment & Quality Pipeline | Block production on CI failure |
| FR28 | Epic 1: Deployment & Quality Pipeline | Endpoint smoke test (57 endpoints) |
| FR29 | Epic 1: Deployment & Quality Pipeline | Lighthouse audit on Preview |
| FR30 | Epic 1: Deployment & Quality Pipeline | Fork code PR test requirement |
| FR31 | Epic 6: Upstream Sync Workflow | Merge upstream via upstream-sync branch |
| FR32 | Epic 6: Upstream Sync Workflow | Proto/sebuf codegen verification |
| FR33 | Epic 6: Upstream Sync Workflow | Proto breaking change detection |
| FR34 | Epic 6: Upstream Sync Workflow | Full test suite on upstream-sync branch |
| FR35 | Epic 2: Situation Monitor Identity | Display SM branding in titles/meta |
| FR36 | Epic 2: Situation Monitor Identity | LLM discoverability files reflect SM |
| FR37 | Epic 2: Situation Monitor Identity | OG preview images with SM branding |
| FR38 | Epic 2: Situation Monitor Identity | robots.txt permits crawling |

### P0 NFR Coverage

| NFR | Epic | Description |
|-----|------|-------------|
| NFR7 | Epic 3 | OG image generation within Vercel Hobby constraints |
| NFR8 | Epic 1 | API keys never in source control |
| NFR9 | Epic 1 | API keys as Vercel env vars, per-environment |
| NFR12 | Upstream (inherited) | HTTPS via Vercel |
| NFR13 | Upstream (inherited) | Redis TLS via Upstash |
| NFR15 | Epic 4 | Single-source failure isolation |
| NFR17 | Epic 1 | Zero post-deployment regressions (QA gate) |
| NFR26 | Epic 4 | Redis unavailability → graceful degradation |
| NFR29 | Epic 1 | $0 monthly infrastructure cost |
| NFR33 | Epic 1 + Epic 6 | `make generate` byte-identical codegen |

---

## Epic List

> **Note:** Growth-phase epics (7–9) are planned but not estimated. Scope will be refined based on MVP learnings and real usage data.

### Prerequisite: Fork Pattern Validation Spike (Story 0)

**Goal:** Validate the fork architecture works before committing to implementation.

**Three pass/fail gates:**
1. Does the Tier 2 hook mechanism work? (DOM-ready callback / event bus / direct import — discover which)
2. Do CSS variable changes propagate to ALL 52 components, or are some hardcoded?
3. Does it deploy cleanly to Vercel Preview?

**If any gate fails:** Revise fork architecture before proceeding to Epic 1.

**Key requirements:** ARCH-9–13, ARCH-22–23, ARCH-50–52
**Outcome:** Hook mechanism documented, CSS coverage audit complete, Vercel Preview deploy verified. Architecture doc updated with findings.

---

### Epic 1: Deployment & Quality Pipeline

**Goal:** Operator can deploy to QA and Production environments with automated quality gates and operational confidence.

**FRs covered:** FR21, FR22, FR23, FR24, FR25, FR26, FR27, FR28, FR29, FR30
**P0 NFRs addressed:** NFR8, NFR9, NFR17, NFR29, NFR33
**Key ARCH reqs:** ARCH-1–3, ARCH-7–8, ARCH-16–18, ARCH-24, ARCH-29–30, ARCH-46–49

**User outcome:** Every code change flows through a validated pipeline — lint, test, build, proto-break detection — before reaching production. QA and Production are isolated. The operator has confidence that nothing ships broken.

---

### Epic 2: Situation Monitor Identity

**Goal:** Users see Situation Monitor branding — not World Monitor — everywhere they encounter the app.

**FRs covered:** FR35, FR36, FR37, FR38
**Key ARCH reqs:** ARCH-10, ARCH-15, ARCH-22–23
**Key UX reqs:** UX-REQ-30–37, UX-REQ-38–39

**User outcome:** Fork theme injection with `--sm-*` tokens, header/attribution text, favicon, meta tags, `llms.txt`/`llms-full.txt` updated, `robots.txt` serving, light mode defensive teal override, performance marks at lifecycle points. Zero CLS. FOUC prevented via inlined tokens.

---

### Epic 3: Social Sharing & Deep Links

**Goal:** Users can share country-specific analysis URLs that generate rich social previews and auto-navigate recipients to the right view.

**FRs covered:** FR13, FR14, FR15, FR16, FR17
**P0 NFRs addressed:** NFR7
**Key ARCH reqs:** ARCH-3
**Key UX reqs:** UX-REQ-3–5, UX-REQ-26

**User outcome:** Country analysis URLs generate OG cards with SM branding. Bot detection serves meta tags. Real users get deep-link `?c=` param with globe animation skip. Invalid params fall back to globe home. Rate-limit bursts on viral shares serve cached/degraded content silently. Story URLs indexable as HTML.

---

### Epic 4: Panel Data States & Freshness

**Goal:** Users always see the freshest available data with clear age indicators; panels never go blank.

**FRs covered:** FR10, FR11
**P0 NFRs addressed:** NFR15, NFR26
**Key ARCH reqs:** ARCH-28, ARCH-31–33
**Key UX reqs:** UX-REQ-6–14, UX-REQ-27–28, UX-REQ-50, UX-REQ-52–59

**User outcome:** 8 panel data states with specific visual treatments. CSS saturation gradient for data age. Per-source configurable freshness thresholds. `RelativeTimeFormatter` utility (single setInterval, bracket-change updates). Stale warning bars (hidden/<24h, amber 24–72h, red >72h). Skeleton loaders (no spinners). Panel header renders immediately. Default panel order with correlation pair adjacency. Globe always shows baseline activity. Stale data never replaced with loading state.

---

### Epic 5: Accessibility & Design System Compliance

**Goal:** All fork components meet WCAG AA, follow the design system contract, and work across devices.

**Key UX reqs:** UX-REQ-15–25, UX-REQ-30–37, UX-REQ-40, UX-REQ-43–44, UX-REQ-46
**Key NFRs:** NFR19–23

**User outcome:** `AriaAnnouncer` with 2s debounce. `prefers-reduced-motion` blanket rule. ARIA labels on all fork interactive elements. Color blindness text supplements. Touch targets ≥44×44px. 320px min viewport. CSS cascade position assertion. No `!important` (except motion rule). Fork CSS lint CI checks (hex, aria-label, `data-sm-*`, `!important`). Playwright axe-core a11y tests. PR checklist enforced.

---

### Epic 6: Upstream Sync Workflow

**Goal:** Operator can safely merge upstream World Monitor updates without breaking the fork.

**FRs covered:** FR31, FR32, FR33, FR34
**P0 NFRs addressed:** NFR33
**Key ARCH reqs:** ARCH-34–39, ARCH-59–60 *(note: ARCH-35/36/59/60 updated for v2.5.8 App.ts decomposition)*
**Key UX reqs:** UX-REQ-42, UX-REQ-45

**User outcome:** Documented `upstream-sync` branch pattern. Post-merge checklist (fork hook intact, `make generate` passes, dependency conflicts resolved, full test suite green). Merge Risk Map referenced. Playwright screenshot comparison for <2min visual verification of 3 key views. Tier 2 patch signature assertions catch upstream breaking changes at boot.

---

### Epic 7: Operational Monitoring & Observability *(MVP/Growth boundary)*

**Goal:** Operator can monitor data source health, diagnose issues, and catch fork compatibility problems at a glance.

**Key ARCH reqs:** ARCH-40–45
**Key UX reqs:** UX-REQ-16, UX-REQ-18, UX-REQ-21–22, UX-REQ-41, UX-REQ-47–49
**Key NFRs:** NFR32

**User outcome:** Sentry integration (Tier 3, ~20KB gzipped). `HealthIndicator` per-panel status dots (operator-gated). `OperatorBadge` + lazy-loaded `OperatorDrawer` with focus trap, mobile full-width, touch targets. Startup compatibility notification bar (amber, once per session, operator-only). Endpoint smoke test with key-removal verification.

---

### Epic 8: Returning Visitor Experience *(Growth — planned, not estimated)*

**Goal:** Returning visitors instantly see what changed since their last visit.

**Key UX reqs:** UX-REQ-60–62, UX-REQ-24–25, UX-REQ-29, UX-REQ-44

**User outcome:** `VisitTracker.ts` localStorage service with versioned schema. `HotspotDelta` pulsing teal rings on changed markers (DeckGL + SVG mobile fallback). "What You Missed" collapsible card in InsightsPanel (mobile: banner above grid). `prefers-reduced-motion` pulse test.

---

### Epic 9: Enhanced Cross-Panel Correlation *(Growth — planned, not estimated)*

**Goal:** Users can interactively cross-reference data across panels with visual highlighting.

**FRs covered:** FR4 (enhancement layer)
**Key UX reqs:** UX-REQ-64, UX-REQ-51

**User outcome:** Click country in CII panel → highlights corresponding data in Economic/Military panels. Extends spatial proximity correlation to interactive linking. Modal rules enforced. Ships the "opinions about events" differentiator.

---

### Epic 10: Discoverability & SEO *(Growth — planned, not estimated)*

**Goal:** Search engines and AI tools discover, index, and present Situation Monitor content.

**Key ARCH reqs:** ARCH-53–58
**Key UX reqs:** UX-REQ-63

**User outcome:** `api/fork/sitemap.js` (Tier 2). Enhanced `/api/story` for crawler pages (Tier 3). SSR landing page. JSON-LD structured data. `lighthouse-ci` in GitHub Actions (Tier 3). Automated upstream sync detection workflow. Mobile warning modal softening for deep-link arrivals.

---

## Stories

### Story Tally

| Epic | Stories | Phase |
|------|---------|-------|
| Prerequisite: Spike | 1 | MVP |
| Epic 1: Deployment & Quality Pipeline | 5 | MVP |
| Epic 2: Situation Monitor Identity | 3 | MVP |
| Epic 3: Social Sharing & Deep Links | 4 | MVP |
| Epic 4: Panel Data States & Freshness | 5 | MVP |
| Epic 5: Accessibility & Design System | 4 | MVP |
| Epic 6: Upstream Sync Workflow | 3 | MVP |
| Epic 7: Operational Monitoring | 4 | MVP |
| Epic 8: Returning Visitor Experience | 3 | Growth |
| Epic 9: Cross-Panel Correlation | 1 | Growth |
| Epic 10: Discoverability & SEO | 4 | Growth |
| **Total** | **37** | |

---

## Prerequisite: Fork Pattern Validation Spike

### Story 0.1: Fork Pattern Validation Spike

As an **operator**,
I want to validate that the fork architecture (Tier 2 hook, CSS variable propagation, and Vercel deploy) works end-to-end,
So that I can proceed with branding and feature work with confidence that the foundation is sound.

**Acceptance Criteria:**

**Given** a clean checkout of the fork repository
**When** I create `src/fork/index.ts` and `src/fork/config.ts` as the minimal fork skeleton
**And** add a single Tier 2 hook import in `main.ts` (one import from `src/fork/index.ts`)
**Then** the import executes after app initialization without errors in the browser console
**And** the hook mechanism type is documented (DOM-ready callback / event bus / direct import)

**Given** the Tier 2 hook is in place
**When** I inject `<style id="fork-theme">` with `:root` CSS variable overrides (e.g., `--sm-accent: #4dd0e1`)
**Then** the override propagates to a representative sample of at least 10 components across 3 categories (panels, modals, globe container)
**And** any components with hardcoded values that DON'T respond are documented in a CSS coverage audit
**And** the full 62-component audit is deferred to Epic 2

**Given** the `src/app/` modular architecture (v2.5.8)
**When** the spike evaluates hook placement
**Then** it documents which `src/app/` module(s) are the optimal hook targets for fork customizations (likely `panel-layout.ts` for panel ordering, `event-handlers.ts` for interaction interception)
**And** the spike validates that a Tier 2 hook can intercept module behavior without modifying module source files

**Given** the hook and CSS injection are working locally
**When** I push to a branch and Vercel creates a Preview deployment
**Then** the Preview deployment loads without errors, fork theme is visible, and CLS = 0
**And** the three spike gates are documented as PASS/FAIL in the architecture doc

**Given** any spike gate fails
**When** the failure is analyzed
**Then** the fork architecture section is revised before any Epic 1 work begins
**And** the revised approach is re-validated through the same three gates

**Tier:** 2 (single `main.ts` import) — may discover Tier 3 needs during spike

---

## Epic 1: Deployment & Quality Pipeline

### Story 1.1: Vercel Environment Configuration & Redis Key-Prefix Isolation

As an **operator**,
I want Preview and Production environments with isolated Redis namespaces,
So that QA testing never pollutes production cache data.

**Acceptance Criteria:**

**Given** the Vercel project is configured
**When** I set environment variables (API keys, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`) scoped to Preview and Production
**Then** each environment uses its own variable values independently
**And** API keys are never committed to source control (verified by grep of `.env*` patterns in `.gitignore`)

**Given** the Redis client wrapper exists
**When** a Preview deployment writes to Redis key `summaries:US`
**Then** the actual Redis key is `qa:summaries:US`
**And** a Production deployment writing the same logical key creates `prod:summaries:US`

**Given** the `prefixedKey()` wrapper is in place
**When** CI runs a grep check for direct Redis calls bypassing the wrapper
**Then** the check passes with zero violations (automated, not convention-dependent)

**Given** the environment is configured
**When** a new contributor checks the repository
**Then** `fork.env.example` documents all fork-specific environment variables with descriptions

**Tier:** 1

---

### Story 1.2: CI Pipeline — Lint, Test, Build, Proto Breaking Change Detection

As an **operator**,
I want an automated quality gate that runs on every PR,
So that broken code never reaches production.

**Acceptance Criteria:**

**Given** a CI runner environment
**When** the pipeline starts
**Then** `buf` CLI is available (installed via CI step or pre-cached)

**Given** a PR is opened against `main`
**When** the CI pipeline triggers
**Then** it executes in order: `make generate` (verify byte-identical) → `make lint` → project's configured test runner (unit tests) → `buf breaking` (proto contract) → `make build` → Playwright E2E tests
**And** any step failure fails the entire pipeline and blocks merge

**Given** `make generate` produces output that differs from committed `src/generated/` files
**When** the CI step compares output
**Then** the pipeline fails with a clear diff message

**Given** the CI pipeline has run on a commit
**When** the same commit is re-run
**Then** the result is identical (deterministic — NFR16)

**Given** a PR changes files in `src/fork/`
**When** the CI pipeline runs
**Then** it verifies `src/fork/__tests__/` contains at least one test file (non-empty test directory gate)

**Given** the fork test suite exists
**When** the CI pipeline runs
**Then** a `test:fork` npm script is available (e.g., `npx tsx --test src/fork/__tests__/*.test.mjs`) and is executed as part of the unit test step

> **Retro Action (Epic 0):** Currently fork tests require manual `npx tsx --test` invocation. This story must add the `test:fork` script to `package.json` and wire it into CI.

**Tier:** 1

---

### Story 1.3: Endpoint Smoke Test Script

As an **operator**,
I want a script that validates all endpoints return non-error responses,
So that I can quickly verify deployment health after any change.

**Acceptance Criteria:**

**Given** the application is deployed to a target environment
**When** I run `scripts/validate-endpoints.sh` with the target URL
**Then** it hits all endpoints and reports pass/fail for each
**And** the summary asserts "tested N endpoints, expected 57" — a count mismatch is a visible warning

**Given** a single API key is removed from the environment
**When** I run the smoke test
**Then** the affected domain endpoints show graceful degradation (non-500 response with informative body)
**And** all other endpoints still pass (NFR32)

**Tier:** 1

---

### Story 1.4: Lighthouse Baseline Audit

As an **operator**,
I want to run Lighthouse against the Preview environment and record baseline scores,
So that I have a reference point for detecting future performance regressions.

**Acceptance Criteria:**

**Given** a Preview deployment is live
**When** I run the Lighthouse audit script against the Preview URL
**Then** it produces scores for Performance, Accessibility, Best Practices, and SEO
**And** baseline scores are recorded in a trackable format (JSON or CI artifact)

**Tier:** 1

---

### Story 1.5: Production Promotion & Deploy Verification

As an **operator**,
I want to promote validated Preview changes to Production and verify the deploy,
So that I know Production is correctly configured and serving traffic.

**Acceptance Criteria:**

**Given** changes have passed all CI checks and are validated in Preview
**When** the PR is merged to `main`
**Then** Vercel automatically deploys to Production within 5 minutes (NFR31)

**Given** a Production deployment completes
**When** I verify the build configuration
**Then** rewrites, cache headers (`immutable` on static assets — NFR4), and route patterns all resolve correctly (FR25)
**And** the endpoint smoke test passes against the Production URL

**Given** a CI pipeline failure
**When** the PR attempts to merge
**Then** the merge is blocked (FR27)

**Tier:** 1

---

## Epic 2: Situation Monitor Identity

### Story 2.1: Fork Theme Injection & CSS Token System

As a **user**,
I want the application to display Situation Monitor's visual identity from the very first frame,
So that I recognize the product as Situation Monitor, not World Monitor.

**Acceptance Criteria:**

**Given** the application loads in a browser
**When** the first paint occurs
**Then** `<style id="fork-theme">` is present in `<head>` with `:root` overrides for all `--sm-*` tokens
**And** the style block is the **last** `<style>` child of `<head>` (CSS cascade position — UX-REQ-33)
**And** `performance.mark('sm-theme-injected')` fires
**And** theme injection completes in < 200ms (UX-REQ-39)

**Given** the theme is injected
**When** I inspect the fork CSS
**Then** zero `!important` declarations exist (exception: `prefers-reduced-motion` blanket rule — UX-REQ-34)
**And** zero hardcoded hex values exist in `src/fork/` (UX-REQ-30)
**And** `document.documentElement.style.setProperty()` is never used (ARCH-22)

**Given** the user has light mode active (`[data-theme="light"]`)
**When** the fork theme applies
**Then** `--accent` resolves to `var(--sm-accent-light, #00838f)` yielding 4.6:1 contrast ratio (UX-REQ-35)

**Given** the theme injection runs
**When** CLS is measured
**Then** Cumulative Layout Shift = 0 (ARCH-23)
**And** tokens are inlined as template literal in `theme-inject.ts`, not an external CSS file load (UX-REQ-37)

**Given** the application has secondary entry points (`settings.html`, `live-channels.html`)
**When** those pages load
**Then** they also receive the fork theme injection via their own Tier 2 hooks
**And** the hook follows the same `import('./fork/index').then(m => m.init())` pattern established in Story 0.1

> **Retro Action (Epic 0):** Story 0.1 spike validated the main entry point only. This story must extend fork hooks to `settings-main.ts` and `live-channels-main.ts` as well.

> **Retro Action (Epic 0):** The CSS coverage audit identified 5 upstream components with hardcoded colors that should migrate to `--sm-*` tokens (MacroSignalsPanel, CountryTimeline, ProgressChartsPanel, SignalModal fallback, main.css misc) plus 2 needing investigation (Map.ts legend, CountryBriefPage SVG fills). See `_spec/implementation-artifacts/epic-0-retro-2026-02-26.md` appendix for full categorization.

**Tier:** 2

---

### Story 2.2: Header, Attribution & Favicon

As a **user**,
I want to see "Situation Monitor" in the page title, header area, and browser tab,
So that the product identity is clear across all touchpoints.

**Acceptance Criteria:**

**Given** the application loads
**When** I check the browser tab
**Then** `<title>` contains "Situation Monitor" (not "World Monitor")
**And** the favicon is the Situation Monitor icon (replaced in `public/favico/`)

**Given** the main view renders
**When** I look at the header/attribution area
**Then** "Situation Monitor" branding text is visible
**And** the text uses `--sm-accent` for identity emphasis per the accent restraint rule (UX-REQ-31)
**And** attribution text follows the `data-sm-component="attribution"` convention (UX-REQ-32)

**Given** the branding elements are injected
**When** CLS is measured
**Then** CLS remains 0 — elements are injected before first paint or are present in initial HTML (ARCH-23)

**Tier:** 1 + 2

---

### Story 2.3: Meta Tags, robots.txt & LLM Discoverability Files

As a **search engine bot or AI tool**,
I want meta tags, `robots.txt`, and LLM discoverability files to reflect Situation Monitor identity,
So that the correct product appears in search results and AI responses.

**Acceptance Criteria:**

**Given** a crawler requests the application
**When** it reads `<meta>` tags in the HTML `<head>`
**Then** `og:site_name`, `description`, and `application-name` reference "Situation Monitor"

**Given** a crawler requests `/robots.txt`
**When** the response is returned
**Then** it permits crawling of public pages (FR38)
**And** the file references "Situation Monitor" in comments

**Given** an AI tool requests `/llms.txt` or `/llms-full.txt`
**When** the response is returned
**Then** the content reflects Situation Monitor identity, capabilities, and data sources (FR36)
**And** no references to "World Monitor" remain in these files

**Tier:** 1

---

## Epic 3: Social Sharing & Deep Links

### Story 3.1: OG Meta Tags & Bot Detection Middleware

As a **user sharing a link on social media**,
I want the shared URL to generate a rich preview card,
So that my audience sees a meaningful preview before clicking.

**Acceptance Criteria:**

**Given** a social media bot (Twitter, Facebook, LinkedIn, Telegram) requests a country URL
**When** the edge middleware detects the bot user-agent
**Then** it serves HTML with OpenGraph meta tags: `og:title` (country + threat level), `og:description` (AI summary excerpt), `og:image` (dynamic preview image URL), `og:site_name` ("Situation Monitor")
**And** legitimate social preview bots are allowed while known scraper/abuse bots are blocked (NFR10)

**Given** a real user clicks the same shared link
**When** the request reaches the application
**Then** they are redirected to the SPA with deep-link parameters (`?c={countryCode}`) that auto-navigate to the relevant country and analysis panel (FR16)

**Tier:** 2

---

### Story 3.2: Dynamic OG Preview Image Generation

As a **user sharing a country analysis link**,
I want the preview card to show a dynamic image with the country name, instability score, and threat level,
So that the shared link is visually compelling and informative.

**Acceptance Criteria:**

**Given** a bot requests the OG image URL for a specific country
**When** the serverless function generates the image
**Then** it renders: country name, instability score, threat level indicator, and Situation Monitor branding (FR37)
**And** generation completes within 10-second Vercel Hobby timeout and 128MB memory limit (NFR7)

**Given** the OG image has been generated recently
**When** another request arrives for the same country
**Then** the cached version is served from Redis (multi-tier cache — FR9)

**Given** an invalid country code is requested
**When** the OG function processes it
**Then** it returns a generic Situation Monitor branded fallback image (never a broken image or error)

**Tier:** 2

---

### Story 3.3: Deep-Link Navigation & Animation Skip

As a **user arriving via a shared link**,
I want to land directly on the relevant country view without waiting for globe animation,
So that I immediately see the analysis that was shared with me.

**Acceptance Criteria:**

**Given** the URL contains `?c={countryCode}` parameter
**When** the SPA loads
**Then** the ~800ms globe spin animation is bypassed and the view snaps directly to the country (UX-REQ-3)
**And** `performance.mark('sm-deep-link-resolved')` fires (UX-REQ-38)
**And** resolution completes in < 1 second (UX-REQ-26)

**Given** the URL contains an invalid country code or unknown panel type
**When** the SPA processes the deep-link
**Then** it falls back to globe home view with World Brief — never shows an error page (UX-REQ-4)

**Given** a shared link generates burst traffic (1000+ simultaneous clicks)
**When** the API rate limit is hit
**Then** cached/degraded content is served silently — never a spinner or error to the user (UX-REQ-5)

**Tier:** 2

---

### Story 3.4: Story URL HTML Pages for Crawlers

As a **search engine crawler**,
I want `/api/story` URLs to return indexable HTML,
So that Situation Monitor content appears in search results.

**Acceptance Criteria:**

**Given** a crawler requests a `/api/story` URL
**When** the server processes the request
**Then** it returns an HTML page with structured content, meta tags, and Situation Monitor branding (FR17)
**And** the HTML includes proper `<title>`, `<meta description>`, and canonical URL

**Given** a real user requests the same `/api/story` URL
**When** the server detects a non-bot user-agent
**Then** it redirects to the SPA with appropriate deep-link parameters

**Tier:** 2

---

## Epic 4: Panel Data States & Freshness

### Story 4.1: Eight Panel Data States & Skeleton Loaders

As a **user**,
I want every panel to always show me something meaningful — data, stale data, or a clear status — never a blank space,
So that I can trust the interface and understand what's happening with each data source.

**Acceptance Criteria:**

**Given** a panel is loading data for the first time
**When** the request is in progress
**Then** the panel header renders immediately (static) and the body shows a skeleton pulse animation (2s ease-in-out loop, `--surface` → `--surface-hover` gradient sweep — UX-REQ-27, UX-REQ-28)
**And** no spinner elements are used anywhere

**Given** a panel has loaded data successfully
**When** the data is fresh
**Then** the panel displays full content with `data-freshness="fresh"` attribute and no special indicators

**Given** a panel's data source returns an error
**When** the panel has previously loaded data
**Then** it preserves the last-known content and shows an amber "Source temporarily unavailable" bar (transient) or red "Source unavailable" bar (persistent — UX-REQ-6)
**And** the panel auto-retries silently for transient errors

**Given** a panel has no data and no cached data
**When** the empty state renders
**Then** light italic text displays "No {dataType} data available for {countryName}" — no error styling, no sad-face icons (UX-REQ-55)

**Given** a panel receives partial data
**When** the degraded state renders
**Then** partial content is shown with "Partial data — X of Y sources responding" indicator (UX-REQ-6)

**Given** one panel's data source fails
**When** other panels are checked
**Then** they continue functioning normally — no global error overlays (UX-REQ-9, NFR15)

**Tier:** 2

---

### Story 4.2: Data Age Gradient & Freshness CSS Saturation

As a **user scanning the dashboard**,
I want my peripheral attention to naturally gravitate toward panels with the freshest data,
So that I focus on what's most current without consciously checking timestamps.

**Acceptance Criteria:**

**Given** a panel's data refresh cycle updates the freshness state
**When** data transitions from `fresh` to `aging`
**Then** `data-freshness` attribute updates to `"aging"` and CSS applies `filter: saturate(0.85)` to `.panel-body` (UX-REQ-10)
**And** the filter change uses `transition: filter 2s ease` — no jarring snap (UX-REQ-11)

**Given** data transitions from `aging` to `stale`
**When** the panel updates
**Then** `data-freshness` updates to `"stale"` and CSS applies `filter: saturate(0.7)` (UX-REQ-10)

**Given** the user has `prefers-reduced-motion` enabled
**When** a freshness state changes
**Then** the transition is instant (no 2s ease) — respects motion preference (UX-REQ-11, UX-REQ-17)

**Given** freshness thresholds are needed for different data sources
**When** the configuration is checked
**Then** thresholds are configurable per source type: earthquakes (warn: 10min, critical: 30min), predictions (warn: 1h, critical: 3h), news (warn: 15min, critical: 1h), military (warn: 30min, critical: 2h), default (warn: 5min, critical: 1h) — UX-REQ-12

**Tier:** 2

---

### Story 4.3: RelativeTimeFormatter & Stale Warning Bars

As a **user**,
I want to see human-readable timestamps that update in real-time and prominent warnings when data is very old,
So that I know exactly how current each panel's information is.

**Acceptance Criteria:**

**Given** panels display timestamps
**When** the `RelativeTimeFormatter` utility runs
**Then** a single `setInterval` fires every 60s (not per-panel — UX-REQ-13)
**And** it pre-computes bracket thresholds (< 1m, < 5m, < 1h, < 1d) and only updates DOM text when the bracket *changes*
**And** this avoids 26 unnecessary DOM writes per tick (~40 LOC)

**Given** a panel's data is less than 24 hours old
**When** the stale warning bar is evaluated
**Then** no warning bar is visible (UX-REQ-14)

**Given** a panel's data is 24–72 hours old
**When** the warning bar renders
**Then** an amber "Last updated X ago" bar appears inside the panel content area (UX-REQ-14)
**And** the bar has `role="status"` for accessibility (UX-REQ-18)

**Given** a panel's data is > 72 hours old
**When** the warning bar renders
**Then** a red "Last updated X ago" bar appears (UX-REQ-14)
**And** warning bars are always visible to ALL users, not operator-gated

**Given** a panel refreshes with new data while showing stale content
**When** the refresh completes
**Then** new content replaces stale content directly — stale data is never replaced with a loading spinner first (UX-REQ-8)

**Tier:** 2

---

### Story 4.4: Default Panel Order & Correlation Pair Adjacency

As a **user**,
I want panels arranged so that related intelligence domains are next to each other by default,
So that I can cross-reference correlated data at a glance.

**Acceptance Criteria:**

**Given** a new user visits (no persisted localStorage order)
**When** the panel grid renders
**Then** panels load in the fork-specific default sequence from `src/fork/config/default-panel-order.ts` (UX-REQ-52)
**And** priority correlation pairs are adjacent: Military+Prediction, Seismic+Humanitarian, CII+Economic

**Given** a returning user has a persisted panel order in localStorage
**When** the panel grid renders
**Then** the user's persisted order is used — fork defaults never override user preference (UX-REQ-52)

**Given** `InsightsPanel` is in the default layout
**When** the desktop view renders
**Then** `InsightsPanel` is visible above the fold without scrolling — position-locked as P0 requirement (UX-REQ-53)

**Tier:** 2

---

### Story 4.5: Globe Visual Baseline & Empty State Handling

As a **user**,
I want the globe to always show meaningful visual activity and never appear broken,
So that I can distinguish "nothing significant happening" from "data isn't loading."

**Acceptance Criteria:**

**Given** the globe is loading
**When** the initial render occurs
**Then** country boundaries from static TopoJSON are visible immediately — the globe is never visually empty (UX-REQ-54)
**And** `performance.mark('sm-globe-rendered')` fires after first meaningful paint (UX-REQ-38)

**Given** all global threat levels are low (calm period)
**When** the globe renders hotspots
**Then** baseline visual activity is present to distinguish "peaceful" from "data missing" (UX-REQ-58)
**And** severity weighting creates clear visual contrast hierarchy — uniform glow is prevented (UX-REQ-59)

**Given** the search modal is open with no results
**When** the empty state renders
**Then** text displays "No results for '{query}'" with suggestion "Try a country name, event type, or keyword" (UX-REQ-56)

**Given** `InsightsPanel` is generating AI content
**When** the generating state renders
**Then** skeleton loader displays with "Generating world brief..." placeholder text — never empty (UX-REQ-57)

**Tier:** 2

---

## Epic 5: Accessibility & Design System Compliance

### Story 5.1: AriaAnnouncer & Debounced ARIA Live Region

As a **screen reader user**,
I want panel state changes announced in batches rather than individually,
So that I'm informed without being overwhelmed by rapid-fire announcements.

**Acceptance Criteria:**

**Given** multiple panels change state within a short time window
**When** the `AriaAnnouncer` processes the changes
**Then** a single hidden `<div aria-live="polite">` batches announcements within a 2-second debounce window (UX-REQ-15)
**And** the output is "3 panels have stale data" rather than 3 separate announcements

**Given** a single panel changes state in isolation
**When** 2 seconds pass without additional changes
**Then** the individual change is announced (e.g., "Military panel: data stale")

**Given** the `AriaAnnouncer` is present in the DOM
**When** no state changes are occurring
**Then** the live region is empty and does not produce announcements

**Tier:** 2

---

### Story 5.2: prefers-reduced-motion Blanket Rule & Fork Component ARIA Labels

As a **motion-sensitive user**,
I want all fork animations disabled system-wide,
So that the interface respects my OS accessibility preference.

**Acceptance Criteria:**

**Given** the user has `prefers-reduced-motion: reduce` enabled at OS level
**When** any fork component renders
**Then** all animations and transitions are disabled via blanket CSS rule: `@media (prefers-reduced-motion: reduce) { [data-sm-component] { animation: none !important; transition-duration: 0s !important; } }` (UX-REQ-17)
**And** upstream animations are unaffected (they don't use `data-sm-component`)

**Given** a fork interactive element renders
**When** it is inspected for accessibility
**Then** it has an `aria-label` appropriate to its role (UX-REQ-18):
- Stale warning bar → `role="status"`
- No toast/snackbar notifications exist anywhere (UX-REQ-50)

**Given** data freshness is communicated via CSS saturation
**When** accessibility is evaluated
**Then** text timestamp + warning bar provide the same information accessibly — no color-only signaling (UX-REQ-19, UX-REQ-20)

**Tier:** 2

---

### Story 5.3: Responsive Mobile Support & Touch Targets

As a **mobile user**,
I want all fork elements to be usable on my device,
So that the experience works regardless of screen size.

**Acceptance Criteria:**

**Given** the viewport is ≤ 768px
**When** interactive fork elements render
**Then** all touch targets are ≥ 44×44px (UX-REQ-22)

**Given** the viewport is 320px wide (minimum supported)
**When** fork components render
**Then** no horizontal overflow occurs and all content is readable (UX-REQ-23)

**Given** modal rules apply
**When** a modal opens
**Then** only one modal at a time, background scroll locked, Escape always closes, click-outside closes non-critical modals (UX-REQ-51)

**Tier:** 2

---

### Story 5.4: Fork CSS Lint CI Checks & Playwright A11y Tests

As an **operator**,
I want automated checks that catch accessibility and design system violations before merge,
So that fork quality doesn't degrade over time.

**Acceptance Criteria:**

**Given** a PR is opened that modifies `src/fork/`
**When** CI runs the fork CSS lint checks
**Then** it verifies: (1) zero hardcoded hex values in `src/fork/`, (2) `data-sm-*` attributes on fork DOM elements, (3) zero `!important` in fork CSS (except `prefers-reduced-motion`), (4) `aria-label` present on interactive fork elements (UX-REQ-43)

**Given** the Playwright test suite runs
**When** `e2e/accessibility.spec.ts` executes
**Then** `@axe-core/playwright` scans the rendered page and catches WCAG AA contrast failures and missing ARIA attributes (UX-REQ-40)
**And** the test runs on every PR

**Given** the fork component PR checklist (UX-REQ-46)
**When** a PR reviewer checks compliance
**Then** the 18-point checklist is referenced in the PR template

**Tier:** 1

---

## Epic 6: Upstream Sync Workflow

### Story 6.1: Upstream Sync Branch Pattern & Post-Merge Checklist

As an **operator**,
I want a documented, repeatable process for merging upstream changes,
So that I can keep the fork current without risking breakage.

**Acceptance Criteria:**

**Given** a new upstream release is available
**When** I create an `upstream-sync` branch
**Then** upstream changes are merged into this branch (never directly into `main` — ARCH-34)
**And** the process follows: merge → resolve conflicts → full test suite → PR into `main`

**Given** the upstream merge is complete on the sync branch
**When** I run the post-merge checklist
**Then** it verifies: (1) `main.ts` single-line fork hook is intact, (2) `make generate` output matches committed files, (3) `package.json` Sentry dependency conflicts resolved, (4) full test suite passes (ARCH-37)

**Given** the Merge Risk Map is referenced
**When** conflicts arise
**Then** I prioritize by risk: Critical = `src/app/panel-layout.ts`, `src/app/data-loader.ts`; High = `proto/**`, `src/generated/**`, `src/app/event-handlers.ts`; Medium = domain handlers, `package.json`, other `src/app/` modules; Low = `App.ts` (thin shell), `public/`, `index.html` (ARCH-36)
**And** the post-merge checklist is documented in `docs/UPSTREAM_SYNC.md`

**Tier:** 1

---

### Story 6.2: Tier 2 Patch Signature Assertions

As an **operator**,
I want monkey-patches on upstream methods to automatically detect when upstream changes break them,
So that I discover compatibility issues at boot rather than in production.

**Acceptance Criteria:**

**Given** a Tier 2 monkey-patch exists on an upstream method
**When** the application boots
**Then** `console.assert` verifies the original method exists and has expected arity (UX-REQ-42)
**And** assertion failure does NOT crash the app — follows graceful degradation (ARCH-25)

**Given** a patch signature assertion fires (method missing or arity changed)
**When** the operator is in operator mode
**Then** the startup compatibility notification bar appears (amber, dismissible, once per session — UX-REQ-49, implemented in Epic 7)

**Given** each Tier 2 patch has a companion test
**When** the test suite runs
**Then** the signature assertion is tested explicitly (UX-REQ-42)
**And** this catches upstream breaking changes at the unit test level after every sync

**Tier:** 2

---

### Story 6.3: Post-Sync Visual Verification via Playwright Screenshots

As an **operator**,
I want to visually verify fork integrity in under 2 minutes after every upstream merge,
So that I can catch subtle visual regressions that automated tests miss.

**Acceptance Criteria:**

**Given** an upstream merge is complete
**When** I run the Playwright screenshot comparison script
**Then** it captures screenshots of 3 key views: globe home, country drill-down, and OG card
**And** screenshots are compared against baseline images stored in the repo

**Given** a visual difference is detected
**When** the diff is presented
**Then** the operator can accept (update baseline) or reject (investigate regression)
**And** the entire process completes in < 2 minutes (UX-REQ-45)

**Given** the screenshots are captured
**When** DOM assertions also run
**Then** `<style id="fork-theme">` position is verified as last `<style>` in `<head>` (UX-REQ-33)
**And** `data-sm-component` attributes are present on expected fork elements

**Tier:** 1

---

## Epic 7: Operational Monitoring & Observability

### Story 7.1: Sentry Integration (Tier 3)

As an **operator**,
I want client-side error tracking that surfaces crashes invisible to server logs,
So that I can diagnose WebGL context loss, ONNX failures, and service worker issues.

**Acceptance Criteria:**

**Given** `VITE_SENTRY_DSN` environment variable is set
**When** the application initializes
**Then** Sentry SDK loads (~20KB gzipped — ARCH-44) with environment tag from `VITE_VERCEL_ENV` (not `MODE` — ARCH-41)
**And** `beforeBreadcrumb` filters external API fetch noise — only same-origin breadcrumbs captured (ARCH-42)

**Given** `VITE_SENTRY_DSN` is NOT set
**When** the application initializes
**Then** Sentry is silently disabled — zero errors, zero console warnings (ARCH-43, graceful degradation)

**Given** a client-side error occurs
**When** Sentry captures it
**Then** the error is tagged with environment (`preview` or `production`) and fork version

**Tier:** 3 — modifies `package.json` (adds Sentry dependency), creating permanent merge debt. **Justification:** Tier 1/2 insufficient because Sentry requires a package dependency and early initialization before fork hook runs.

---

### Story 7.2: HealthIndicator Per-Panel Status Dots

As an **operator**,
I want to see at-a-glance data source health for every panel,
So that I can spot degraded sources without opening the operator drawer.

**Acceptance Criteria:**

**Given** operator mode is enabled (`localStorage sm-operator-mode` or `?debug=1`)
**When** a panel renders
**Then** an 8px colored dot appears in the panel header (right side) showing freshness: Fresh/teal, Aging/amber, Stale/red, N/A/grey (UX-REQ-47)
**And** the dot has `aria-label="Data source status: {state}"` (UX-REQ-18)

**Given** operator mode is disabled
**When** the panel renders
**Then** no health indicator dots are visible

**Given** a dot's state changes
**When** the screen reader processes it
**Then** the change is announced via `AriaAnnouncer` (not individual `aria-live`) (UX-REQ-46 checklist)

**Tier:** 2

---

### Story 7.3: OperatorBadge + OperatorDrawer with Focus Trap

As an **operator**,
I want a floating badge showing overall system health and a detail drawer I can open on demand,
So that I can monitor all data sources in one place and link to diagnostic tools.

**Acceptance Criteria:**

**Given** operator mode is enabled
**When** the application renders
**Then** a floating badge appears (bottom-right) showing "{N}/{total} sources OK" or "{N} sources degraded" (UX-REQ-48)
**And** the badge has `role="button"`, `aria-label="{N} of {total} sources healthy"`, min 44×44px touch target (UX-REQ-18, UX-REQ-22)

**Given** the operator clicks the badge
**When** the drawer opens
**Then** a lazy-loaded `OperatorDrawer` slides in with per-source status list + Vercel dashboard link (UX-REQ-48)
**And** focus moves to the first element inside the drawer (UX-REQ-16)
**And** Tab cycles within the drawer only (focus trap — UX-REQ-16)
**And** Escape closes the drawer and restores focus to the badge (UX-REQ-16)

**Given** the viewport is ≤ 768px
**When** the drawer opens
**Then** it uses full viewport width (`width: 100vw`) instead of desktop's 320px (UX-REQ-21)

**Given** operator mode is disabled
**When** the application renders
**Then** neither badge nor drawer are present in the DOM

**Tier:** 2

---

### Story 7.4: Startup Compatibility Notification Bar

As an **operator**,
I want to be alerted when upstream changes may have broken fork patches,
So that I can investigate compatibility issues immediately after an upstream sync.

**Acceptance Criteria:**

**Given** a Tier 2 monkey-patch signature assertion fires at boot (method missing or arity changed)
**When** operator mode is enabled
**Then** a dismissible amber bar appears at page top: "Fork compatibility check: {N} patch(es) detected upstream changes. See operator overlay for details." (UX-REQ-49)
**And** the bar has `role="alert"`, `aria-live="assertive"` (UX-REQ-18)
**And** it appears once per session only (dismissed state stored in sessionStorage)

**Given** no signature assertions fire
**When** the application boots
**Then** no compatibility bar is shown

**Given** operator mode is disabled
**When** an assertion fires
**Then** no bar is shown (operator-only feature)

**Tier:** 2

---

## Epic 8: Returning Visitor Experience *(Growth — planned, not estimated)*

### Story 8.1: VisitTracker.ts LocalStorage Service

As a **returning visitor**,
I want the app to know what the world looked like when I last visited,
So that it can show me what's changed.

**Acceptance Criteria:**

**Given** a user visits the application
**When** they leave or close the tab
**Then** `VisitTracker.ts` stores a state snapshot in localStorage under key `sm-visit-snapshot` (~2KB) with versioned schema (`version: number`) (UX-REQ-62)

**Given** the user returns
**When** the app loads
**Then** the stored snapshot is loaded and delta computation runs against current data
**And** on schema version mismatch: migrate if possible, or discard + re-snapshot (never crash — UX-REQ-62)

**Tier:** 2

---

### Story 8.2: HotspotDelta Pulsing Markers

As a **returning visitor**,
I want to see which hotspots are new or escalated since my last visit,
So that I immediately focus on what changed.

**Acceptance Criteria:**

**Given** the `VisitTracker` has a previous snapshot
**When** new or escalated hotspots are detected
**Then** pulsing teal ring markers appear around changed hotspots on the globe (UX-REQ-60)
**And** the pulse runs for 10 seconds via `@keyframes pulse-ring`, then settles to a static teal ring (UX-REQ-29)

**Given** `prefers-reduced-motion` is enabled
**When** delta markers render
**Then** static teal ring only — no pulse animation (UX-REQ-29, UX-REQ-44)

**Given** the device uses mobile SVG fallback (no WebGL)
**When** delta markers render
**Then** pulsing works on D3 SVG renderer identically to DeckGL desktop (UX-REQ-25)

**Tier:** 2

---

### Story 8.3: "What You Missed" Panel

As a **returning visitor**,
I want a summary of key changes since my last visit,
So that I can quickly catch up without scanning every panel.

**Acceptance Criteria:**

**Given** the `VisitTracker` detects changes since last visit
**When** the InsightsPanel renders
**Then** a collapsible "What You Missed" card appears at the top with entries like "Taiwan: CII elevated 62→71", "New hotspot: Red Sea shipping" (UX-REQ-61)

**Given** the user dismisses the card
**When** they continue browsing
**Then** the card stays hidden until the next visit with changes

**Given** the viewport is ≤ 768px (InsightsPanel auto-hides on mobile)
**When** the content renders
**Then** the "What You Missed" card appears as a banner above the panel grid instead (UX-REQ-24)

**Given** it's the user's first visit (no snapshot)
**When** the app loads
**Then** no "What You Missed" card is shown

**Tier:** 2

---

## Epic 9: Enhanced Cross-Panel Correlation *(Growth — planned, not estimated)*

### Story 9.1: Panel-to-Panel Interactive Highlighting

As an **analyst user**,
I want clicking a country in one panel to highlight corresponding data in adjacent panels,
So that I can cross-reference correlated intelligence interactively.

**Acceptance Criteria:**

**Given** the user clicks a country in the CII panel
**When** adjacent correlation pair panels (Economic, Military) are visible
**Then** corresponding data for that country is visually highlighted in those panels (UX-REQ-64)
**And** highlighting follows the accent restraint rule (teal for selection indicator, not information — UX-REQ-31)

**Given** the user clicks elsewhere or presses Escape
**When** the highlighting is active
**Then** highlights are cleared across all panels

**Given** modal rules apply
**When** any correlation interaction triggers a detail view
**Then** one modal at a time, Escape closes, background scroll locked (UX-REQ-51)

**Tier:** 2

---

## Epic 10: Discoverability & SEO *(Growth — planned, not estimated)*

### Story 10.1: Sitemap.xml & JSON-LD Structured Data

As a **search engine**,
I want a sitemap and structured data,
So that Situation Monitor content is properly indexed.

**Acceptance Criteria:**

**Given** a crawler requests `/api/fork/sitemap.js`
**When** the function responds
**Then** a valid sitemap.xml is returned listing all public country and story URLs (ARCH-53)

**Given** the SPA renders
**When** JSON-LD structured data is injected
**Then** it describes the application as a geopolitical intelligence monitor (ARCH-56)
**And** JSON-LD is added via `src/fork/branding.ts` extension (Tier 1)

**Tier:** Sitemap = Tier 2, JSON-LD = Tier 1

---

### Story 10.2: SSR Landing Page

As a **first-time visitor from search**,
I want a fast-loading landing page that explains Situation Monitor,
So that I understand the product before the full SPA loads.

**Acceptance Criteria:**

**Given** a non-bot request hits the landing route
**When** the server responds
**Then** `api/fork/landing.js` serves `public/landing.html` with Situation Monitor branding, key features, and a CTA to enter the full app (ARCH-55)

**Tier:** 2

---

### Story 10.3: Enhanced Story Pages & Mobile Warning Softening

As a **mobile user arriving via deep link**,
I want a welcoming experience rather than a "desktop recommended" warning,
So that I'm not discouraged from exploring the shared content.

**Acceptance Criteria:**

**Given** a mobile user arrives via a deep-link (`?c=` parameter)
**When** the mobile warning modal would normally appear
**Then** it is suppressed — the user goes directly to the country view (UX-REQ-63)

**Given** an organic mobile visitor (no deep-link)
**When** the mobile warning would appear
**Then** a subtle dismissible banner replaces the blocking modal (UX-REQ-63)

**Given** a crawler requests an enhanced `/api/story` URL
**When** the server responds
**Then** the HTML includes richer content, Situation Monitor branding, and structured data (ARCH-54, Tier 3)

**Tier:** 2 + 3

---

### Story 10.4: Lighthouse CI & Automated Upstream Sync Detection

As an **operator**,
I want automated performance monitoring and upstream sync alerting,
So that regressions are caught without manual checking.

**Acceptance Criteria:**

**Given** a PR is opened
**When** CI runs
**Then** `lighthouse-ci` executes and reports scores alongside existing checks (ARCH-57, Tier 3)

**Given** a new upstream release is published
**When** the automated detection workflow runs
**Then** a notification (GitHub issue or workflow alert) is created in the fork repo (ARCH-58, Tier 2)

**Tier:** 3 + 2

---

## Backlog: Upstream Fixes & Data Source Migrations

### Story B.1: ACLED API OAuth2 Migration

As an **operator**,
I want the ACLED integration to use the current OAuth2 authentication flow,
So that conflict, unrest, and risk score data continues flowing after the deprecated API is removed.

**Context:** ACLED deprecated their static access token API. The new API requires OAuth2 with `grant_type=password` to obtain a 24-hour access token + 14-day refresh token. The upstream codebase (3 files) still uses the old `ACLED_ACCESS_TOKEN` Bearer pattern.

**Acceptance Criteria:**

**Given** this story is picked up for implementation
**When** the developer checks the current upstream codebase
**Then** they first verify whether upstream (koala73/worldmonitor) has already migrated to the new ACLED OAuth2 flow
**And** if upstream has fixed it, this story is closed as resolved-upstream with a note on which commit/release included the fix

**Given** upstream has NOT fixed the ACLED authentication
**When** the migration is implemented
**Then** `ACLED_EMAIL` and `ACLED_PASSWORD` environment variables replace `ACLED_ACCESS_TOKEN`
**And** a shared `server/_shared/acled-auth.ts` module handles OAuth2 token fetch, caching (Redis, 23h TTL), and refresh
**And** `POST https://acleddata.com/oauth/token` is called with `grant_type=password`, `client_id=acled`, email, and password
**And** the access token (24h expiry) is cached in Redis under `acled:oauth:token` with the environment key prefix
**And** on cache miss or 401 response, the module re-authenticates automatically
**And** refresh token (14-day expiry) is used when available before falling back to full re-authentication

**Given** the OAuth2 token manager is in place
**When** the three consuming files are updated
**Then** `server/worldmonitor/conflict/v1/list-acled-events.ts`, `server/worldmonitor/unrest/v1/list-unrest-events.ts`, and `server/worldmonitor/intelligence/v1/get-risk-scores.ts` all import the shared auth module
**And** the API endpoint URL and query parameters remain unchanged (only auth mechanism changes)
**And** graceful degradation is preserved — missing credentials return empty arrays, not crashes

**Given** `ACLED_EMAIL` or `ACLED_PASSWORD` is not set
**When** any ACLED-dependent endpoint is called
**Then** it returns an empty result set with no errors (existing graceful degradation behavior)

**Given** the `.env.example` and `fork.env.example` files exist
**When** the migration is complete
**Then** `ACLED_ACCESS_TOKEN` is removed and replaced with `ACLED_EMAIL` and `ACLED_PASSWORD` with descriptions

**Affected files:** `server/worldmonitor/conflict/v1/list-acled-events.ts`, `server/worldmonitor/unrest/v1/list-unrest-events.ts`, `server/worldmonitor/intelligence/v1/get-risk-scores.ts`, `server/_shared/acled-auth.ts` (new), `.env.example`

**Tier:** 3 (modifies upstream server files)

**Priority:** Unprioritized — schedule when ACLED data is needed or old API stops working

---

## Recurring: Upstream Sync Epics

> These epics are generated on-demand when the fork needs to catch up with `upstream/main`. Each sync follows the same 6-story pattern. See the implementation artifact for full details.

### Upstream Sync — March 2026 (PRs #809–#1851)

**Implementation Artifact:** `_spec/implementation-artifacts/epic-upstream-sync-march-2026.md`

**Stories:** S-1 through S-6 (merge → build validation → env audit → fork integrity → E2E → deploy)

**Scope:** 648 commits, 987 files changed, 146K insertions, 53K deletions. Major additions include AI Forecast engine, MCP data panel, AI Widget Builder, Supply Chain restructure, OFAC Sanctions, Radiation Watch, Thermal Escalation, Kalshi predictions, Astro blog, Mintlify docs, PMTiles map migration.
