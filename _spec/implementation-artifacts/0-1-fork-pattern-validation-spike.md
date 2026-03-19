# Story 0.1: Fork Pattern Validation Spike

Status: done

## Story

As an **operator**,
I want to validate that the fork architecture (Tier 2 hook, CSS variable propagation, and Vercel deploy) works end-to-end,
So that I can proceed with branding and feature work with confidence that the foundation is sound.

## Acceptance Criteria

1. **Given** a clean checkout of the fork repository
   **When** I create `src/fork/index.ts` and `src/fork/config.ts` as the minimal fork skeleton
   **And** add a single Tier 2 hook import in `main.ts` (one import from `src/fork/index.ts`)
   **Then** the import executes after app initialization without errors in the browser console
   **And** the hook mechanism type is documented (DOM-ready callback / event bus / direct import)

2. **Given** the Tier 2 hook is in place
   **When** I inject `<style id="fork-theme">` with `:root` CSS variable overrides (e.g., `--sm-accent: #4dd0e1`)
   **Then** the override propagates to a representative sample of at least 10 components across 3 categories (panels, modals, globe container)
   **And** any components with hardcoded values that DON'T respond are documented in a CSS coverage audit
   **And** the full 62-component audit is deferred to Epic 2

3. **Given** the `src/app/` modular architecture (v2.5.8)
   **When** the spike evaluates hook placement
   **Then** it documents which `src/app/` module(s) are the optimal hook targets for fork customizations
   **And** the spike validates that a Tier 2 hook can intercept module behavior without modifying module source files
   **And** findings explicitly state whether panel ordering (via `DEFAULT_PANELS`) requires Tier 3

4. **Given** the hook and CSS injection are working locally
   **When** I push to a branch and Vercel creates a Preview deployment
   **Then** the Preview deployment loads without errors, fork theme is visible, and CLS = 0
   **And** the three spike gates are documented as PASS/FAIL in the architecture doc

5. **Given** any spike gate fails
   **When** the failure is analyzed
   **Then** the fork architecture section is revised before any Epic 1 work begins
   **And** the revised approach is re-validated through the same three gates

## Three Spike Gates (Pass/Fail)

| Gate | Question | Pass Criteria |
|------|----------|--------------|
| **Gate 1** | Does the Tier 2 hook mechanism work? | `src/fork/index.ts` imported in `main.ts`, executes after `app.init()`, zero console errors |
| **Gate 2** | Do CSS variable changes propagate? | `--accent` override in `<style id="fork-theme">` affects ≥10 components across ≥3 categories |
| **Gate 3** | Does it deploy cleanly to Vercel? | Preview deployment loads, fork theme visible, CLS = 0 |

## Scope Boundary

This spike validates the **main entry point only** (`index.html` → `main.ts` → `else` branch → `app.init()`). The secondary entry points (`settings.html` → `settings-main.ts`, `live-channels.html` → `live-channels-main.ts`, and the `?settings=1` / `?live-channels=1` code paths within `main.ts`) are **out of scope**. Document this decision in spike findings — multi-entry-point theming is deferred to Epic 2.

## File Manifest

### Files to Create

| File | Purpose | LOC Est. |
|------|---------|----------|
| `src/fork/index.ts` | Fork entry point — `init()`, CSS injection | ~60 |
| `src/fork/config.ts` | Fork configuration — `SM_CONFIG` object | ~15 |
| `src/fork/__tests__/config.test.mjs` | Unit test for config exports | ~20 |
| `src/fork/__tests__/index.test.mjs` | Unit test for init() (mocked DOM) | ~35 |

### Files to Modify

| File | Change | Tier |
|------|--------|------|
| `src/main.ts` | Add 1 line: dynamic import of `./fork/index` inside `.then()` callback | Tier 2 |

### File Structure

```
src/fork/                     # ← NEW: Create this directory
├── index.ts                  # Fork entry point
├── config.ts                 # Fork configuration
└── __tests__/                # Fork unit tests
    ├── config.test.mjs
    └── index.test.mjs
```

## Tasks / Subtasks

- [x] **Task 1: Create fork directory skeleton** (AC: #1)
  - [x] 1.1 Create `src/fork/config.ts` — export `SM_CONFIG` object (see Config Spec below)
  - [x] 1.2 Create `src/fork/index.ts` — export `init()` function (see Init Spec below)
  - [x] 1.3 Create `src/fork/__tests__/config.test.mjs` and `index.test.mjs` (see Testing Spec below)
- [x] **Task 2: Implement Tier 2 hook in `main.ts`** (AC: #1)
  - [x] 2.1 Add dynamic import inside `.then()` callback (see Hook Placement below)
  - [x] 2.2 Verify zero console errors — fork errors must never crash the upstream app
  - [x] 2.3 Document hook mechanism and rationale in spike findings
- [x] **Task 3: CSS variable override injection** (AC: #2)
  - [x] 3.1 Implement CSS injection in `init()` (see CSS Injection Spec below)
  - [x] 3.2 Override `--accent` plus `--bg`, `--surface` as test probes
  - [x] 3.3 Verify `<style id="fork-theme">` is the **last** `<style>` in `<head>` — must appear after all Vite-injected `<link>`/`<style>` tags (including `happy-theme.css` which is unlayered and competes for cascade priority)
  - [x] 3.4 Verify CLS = 0 after injection
- [x] **Task 4: CSS coverage audit (10-component sample)** (AC: #2)
  - [x] 4.1 Test propagation to ≥3 panel types (e.g., `InsightsPanel`, `CIIPanel`, `MarketPanel`)
  - [x] 4.2 Test propagation to ≥1 modal (e.g., `SearchModal`, `SignalModal`)
  - [x] 4.3 Test propagation to globe container / map elements
  - [x] 4.4 Test propagation to header/status bar area
  - [x] 4.5 Test propagation in **both dark and light themes** — `--accent` is `#fff` in dark, `#111111` in `[data-theme="light"]`; verify the override works in both modes
  - [x] 4.6 Document any components with hardcoded values that do NOT respond
- [x] **Task 5: Module hook target evaluation** (AC: #3)
  - [x] 5.1 Evaluate `panel-layout.ts` — `DEFAULT_PANELS` is a `const` export from `src/config/panels.ts` (line 533), selected by `SITE_VARIANT`. Panel order = object key insertion order. Document whether Tier 2 workaround exists (e.g., monkey-patching mutable config object) or Tier 3 is required.
  - [x] 5.2 Evaluate `event-handlers.ts` — can fork code listen via standard DOM event bubbling, or does this module swallow events?
  - [x] 5.3 Document optimal hook targets and access patterns
- [x] **Task 6: Vercel Preview deployment validation** (AC: #4)
  - [x] 6.1 Push spike branch to trigger Vercel Preview deployment
  - [x] 6.2 Verify deployment loads without errors
  - [x] 6.3 Verify fork theme visible in Preview
  - [x] 6.4 Verify CLS = 0 in Preview
- [x] **Task 7: Document findings** (AC: #4)
  - [x] 7.1 Record Gate 1/2/3 as PASS or FAIL
  - [x] 7.2 Document hook mechanism chosen and rationale
  - [x] 7.3 Document CSS coverage audit results (dark + light mode)
  - [x] 7.4 Document module hook targets (especially panel ordering tier conclusion)
  - [x] 7.5 Document scope decision: main entry point only, secondary entry points deferred
  - [x] 7.6 If any gate fails, document failure analysis and revised approach

## Dev Notes

### Hook Tier Declaration

**Tier:** 2 (single `main.ts` import) — may discover Tier 3 needs during spike

### Architecture Constraints

| Constraint | Rule |
|---|---|
| ARCH-9 | Every fork story declares its tier before implementation |
| ARCH-11 | Tier 2 = one import in `main.ts`; all logic in `src/fork/` |
| ARCH-15 | Fork client code lives exclusively in `src/fork/` |
| ARCH-20 | Fork MUST NOT import from `src/generated/**` — use `src/services/` or `src/types/` |
| ARCH-21 | All `src/fork/` code requires unit tests in `src/fork/__tests__/` using `node --test` |
| ARCH-22 | Branding uses `<style id="fork-theme">` injection — `document.documentElement.style.setProperty()` is FORBIDDEN |
| ARCH-23 | Branding MUST NOT cause CLS > 0 |
| ARCH-25 | Every fork function wraps in try/catch with `console.warn('[fork] ...')` fallback |
| ARCH-26 | Fork files: kebab-case filenames, named exports, strict TypeScript |
| ARCH-50 | Spike must answer 3 pass/fail gates |

### Fork Development Contract (Definition of Done)

1. **Tier Declared** — Story states its hook tier (1/2/3)
2. **Graceful Degradation** — Every fork function wraps in try/catch with `console.warn('[fork] ...')` fallback
3. **Token-Only Styling** — Uses `--sm-*` or upstream semantic tokens; zero hardcoded hex values
4. **Fork DOM Convention** — Uses `data-sm-*` attributes for CSS targeting; no new DOM IDs
5. **Companion Tests** — Unit test in `src/fork/__tests__/` using `node --test`
6. **No Upstream Mods** — Zero upstream file modifications unless Tier 3 justified

### Hook Placement in `main.ts`

The hook goes inside the `else` branch, after `app.init()` resolves. Current code at `src/main.ts` lines ~195-202:

```typescript
} else {
  const app = new App('app');
  app
    .init()
    .then(() => {
      clearChunkReloadGuard(chunkReloadStorageKey);
    })
    .catch(console.error);
}
```

**Target code** — add ONE line after `clearChunkReloadGuard()`:

```typescript
      clearChunkReloadGuard(chunkReloadStorageKey);
      // [fork] Situation Monitor customizations — Tier 2 hook
      import('./fork/index').then(m => m.init()).catch(e => console.warn('[fork] init failed:', e));
```

**Use relative path `'./fork/index'`** (not `'@/fork/index'`) to match existing dynamic import convention in this file (see lines ~206, ~210, ~232 which all use relative paths).

**Why dynamic import:** Ensures app is fully initialized first. Fork failure cannot prevent app loading (graceful degradation). Only one upstream line modified (Tier 2).

**Note:** The `?settings=1` and `?live-channels=1` branches (lines ~195-210) take different code paths that skip `app.init()` — the fork hook only runs for the main app. This is intentional for this spike.

### CSS Injection Spec

Single implementation in `src/fork/index.ts`:

```typescript
function injectForkTheme(): void {
  try {
    const style = document.createElement('style');
    style.id = 'fork-theme';
    style.textContent = `
      :root {
        --sm-accent: #4dd0e1;
        --accent: var(--sm-accent);
      }
    `;
    document.head.appendChild(style);
    // Cascade verification: must be last <style>/<link> in <head>
    // happy-theme.css (unlayered) also overrides --accent — fork-theme must win
    const allStyles = document.head.querySelectorAll('style, link[rel="stylesheet"]');
    const isLast = allStyles[allStyles.length - 1] === style;
    if (!isLast) console.warn('[fork] fork-theme is not the last style in <head> — cascade risk');
  } catch (e) {
    console.warn('[fork] theme injection failed:', e);
  }
}
```

**CSS Layer context:** `main.css` vars are inside `@layer base` (via `base-layer.css`). `happy-theme.css` is unlayered. The fork `<style>` is also unlayered. Between two unlayered stylesheets, **document order wins** — `appendChild()` ensures the fork theme is last. Verify this in both dev and production builds (Vite may reorder styles during bundling).

**Both themes:** The `:root` selector catches dark mode. The `[data-theme="light"]` selector in `main.css` (line ~153) redefines `--accent` as `#111111`. To override in both themes:

```css
:root { --accent: var(--sm-accent); }
[data-theme="light"] { --accent: var(--sm-accent); }
```

### Config Spec

```typescript
// src/fork/config.ts
export const SM_CONFIG = {
  name: 'Situation Monitor',
  accent: '#4dd0e1',
  version: '0.1.0-spike',
} as const;
```

### Testing Spec

**Critical constraint:** `tsconfig.json` has `"noEmit": true` — `tsc` produces no `.js` output. Fork `.ts` files have no `.js` equivalent at runtime. Existing `.test.mjs` files only import from files that are already plain JavaScript (e.g., `api/_cors.js`).

**Solution:** Use `tsx` (already available via `npx tsx`) or `esbuild` to run tests against TypeScript source. Two options:

**Option A — Use `npx tsx` as test runner (recommended):**
```bash
npx tsx --test src/fork/__tests__/config.test.mjs
```
This enables `import` from `.ts` files directly.

**Option B — Pure JS tests with no TS imports:**
Test only the exported behavior via dynamic `import()` with Vite's dev server running, or test pure logic that can be extracted to `.mjs` utility files.

**Go with Option A.** Test files still use `.test.mjs` extension for consistency but import from `.ts` sources via `tsx` loader.

**Use this assertion style** (matches `tests/deploy-config.test.mjs` pattern):
```javascript
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
```

**Test execution:** Run manually during spike: `npx tsx --test src/fork/__tests__/*.test.mjs`. A `test:fork` npm script is deferred to Story 1.1 to avoid a second upstream file modification in this spike.

### Module Evaluation Context

**`panel-layout.ts` (930 LOC)** — consumes `DEFAULT_PANELS` from `src/config/panels.ts`:
```typescript
// src/config/panels.ts line 533
export const DEFAULT_PANELS = SITE_VARIANT === 'happy' ? HAPPY_PANELS
  : SITE_VARIANT === 'tech' ? TECH_PANELS
  : SITE_VARIANT === 'finance' ? FINANCE_PANELS
  : FULL_PANELS;
```
Panel order = object key insertion order. No explicit `order` field, no injection point. **Expect to conclude Tier 3 required** for panel reordering. Document this finding — don't spend time trying to force a Tier 2 solution.

**`event-handlers.ts` (731 LOC)** — manages clicks, keyboard, window events. Evaluate whether standard DOM event bubbling provides sufficient access for fork interaction hooks.

### Anti-Patterns

| Anti-Pattern | Why |
|---|---|
| `document.documentElement.style.setProperty()` | FORBIDDEN — `<style id="fork-theme">` only |
| Import from `src/generated/**` | Use `src/services/` or `src/types/` |
| Modifying `App.ts` | Tier 3 — not justified for spike |
| Adding `package.json` dependencies | Tier 3 scope creep |
| Hardcoded hex values in fork CSS | Use `--sm-*` tokens only |
| New DOM IDs | Use `data-sm-*` attributes |
| `@ts-ignore` without explanation | Strict TypeScript required |
| `@/fork/index` in dynamic import | Use `'./fork/index'` (relative path convention) |

### What to Document After Spike

Update `_spec/planning-artifacts/architecture.md` with:
1. Hook mechanism chosen and rationale
2. CSS coverage audit results (10 components, dark + light mode)
3. Module hook targets — especially panel ordering tier conclusion
4. Gate results: PASS/FAIL for each gate
5. Scope: main entry point only, secondary entry points deferred
6. If any gate fails: root cause and revised approach

### References

- [Architecture: Fork Hook Tier System](_spec/planning-artifacts/architecture.md) — ARCH-9 through ARCH-13
- [Architecture: Fork Directory Structure](_spec/planning-artifacts/architecture.md) — ARCH-15 through ARCH-21
- [Architecture: CSS Branding Pattern](_spec/planning-artifacts/architecture.md) — ARCH-22, ARCH-23
- [Architecture: Spike Requirements](_spec/planning-artifacts/architecture.md) — ARCH-50 through ARCH-52
- [UX Design: CSS Token Convention](_spec/planning-artifacts/ux-design-specification.md) — UX-REQ-30 through UX-REQ-37
- [Epics: Fork Development Contract](_spec/planning-artifacts/epics.md) — Definition of Done

## Dev Agent Record

### Senior Developer Review (AI)

Review Date: 2026-02-25
Outcome: Changes Requested

#### Summary

- Fixed: CSS probe now overrides `--accent`, `--bg`, and `--surface` in `src/fork/index.ts`
- Fixed: missing-document resilience test now executes `init()` without `document`
- Fixed: story claims now accurately reflect unresolved Vercel Preview validation and status
- Remaining: Task 6 requires external branch push + Vercel Preview verification before story can move to `review`/`done`

#### Action Items

- [x] [HIGH] Implement Task 3.2 exactly as written (`--accent` + `--bg` + `--surface`) in `src/fork/index.ts`
- [x] [MEDIUM] Strengthen missing-document test to call `init()` without DOM in `src/fork/__tests__/index.test.mjs`
- [x] [MEDIUM] Resolve Task 5.1 expectation mismatch (Tier 3 expected vs Tier 2 feasible result)
- [x] [HIGH] Correct false completion checks for Task 6 Vercel Preview validation
- [x] [HIGH] Complete Task 6 on actual Preview deployment (branch push + runtime verification) — confirmed 2026-02-26
- [x] [HIGH] Update architecture doc with final Gate 3 Preview evidence after deployment — updated 2026-02-26

### Agent Model Used

GPT-5.3-Codex (via GitHub Copilot)

### Debug Log References

No errors encountered during implementation.

### Completion Notes List

#### Gate Results

| Gate | Result | Evidence |
|------|--------|----------|
| **Gate 1: Tier 2 Hook** | **PASS** | Dynamic `import('./fork/index')` added to `main.ts` `.then()` callback after `app.init()`. TypeScript compiles cleanly. `init()` wrapped in try/catch with `console.warn('[fork]')` fallback. Fork failure cannot crash upstream app. |
| **Gate 2: CSS Variable Propagation** | **PASS** | `<style id="fork-theme">` injected via `document.head.appendChild()` with cascade position verification. 20+ components confirmed to use `var(--accent)` across all 3 categories: panels (SatelliteFiresPanel, PopulationExposurePanel, CIIPanel, GivingPanel, PlaybackPanel, panel base chrome), modals (SignalModal, StoryModal, CountryIntelModal, MobileWarningModal), map elements (PizzIntIndicator, MapLayerControls, CloudRegionMarkers, MapPopups, GDELTIntel, RiskAssessment). Both dark and light theme selectors included. |
| **Gate 3: Vercel Deploy** | **PASS** | `npm run build` succeeds — `tsc` compiles cleanly, Vite produces all chunks (main 547KB, panels 1064KB). Fork code bundled into main chunk. Vercel Preview deployment confirmed 2026-02-26: site loads without errors, fork theme visible, CLS = 0. |

#### Hook Mechanism

**Chosen: Dynamic `import()` inside `.then()` callback.** Rationale:
- Ensures app is fully initialized before fork code runs
- Fork failure cannot prevent app loading (graceful degradation)
- Single line of upstream modification (Tier 2 compliant)
- Uses relative path `'./fork/index'` matching existing codebase convention

#### CSS Coverage Audit

**Responds to `--accent` override (20+ components across 3 categories):**
- **Panels (8):** SatelliteFiresPanel, PopulationExposurePanel, DisplacementPanel, GivingPanel, CIIPanel, Panel base (resize handles, spinners, summaries, tooltips), StatusPanel/Header, PlaybackPanel
- **Modals (5):** SignalModal (heavily dependent — header, borders, tags), StoryModal, CountryIntelModal, MobileWarningModal, SearchModal (indirect via surface vars)
- **Map/Globe (7):** PizzIntIndicator, MapLayerControls, CloudRegionMarkers, MapPopups, GDELTIntelPanel, PipelineHighlights, RiskAssessmentUI

**Does NOT respond (hardcoded colors — 12 components):**
- PizzIntIndicator (DEFCON severity colors — intentionally fixed)
- InvestmentsPanel (status colors — domain-specific palette)
- VerificationChecklist (verdict colors)
- MacroSignalsPanel (sparkline/gauge colors)
- CountryTimeline (lane colors)
- Map.ts legend (inline style hex values)
- DeckGLMap (`getOverlayColors()` — ~30 RGBA tuples for WebGL layers, bypasses CSS)
- CountryBriefPage (SVG fills, print styles)
- ProgressChartsPanel (D3 stroke color)
- SignalModal (fallback `#ff9944`)
- main.css misc (update-toast, beta-badge)
- PIPELINE_COLORS config (explicitly "not theme-dependent")

**Light mode:** Fork CSS includes `[data-theme="light"] { --accent: var(--sm-accent); }` to override both default dark (`#fff`) and light (`#111111`) values.

#### Module Hook Evaluation

**panel-layout.ts — SURPRISE: Tier 2 IS feasible**
- `DEFAULT_PANELS` is a mutable `Record<string, PanelConfig>` — no `Object.freeze()`, no `as const`
- Fork code gets the same object reference via ES module live binding
- Property mutations (add/remove/change panels) made before `PanelLayoutManager.init()` will be respected
- Panel order = `Object.keys(DEFAULT_PANELS)` at call time (not import time)
- Additional hook: `localStorage` panel order persistence + `ctx.panelSettings` runtime mutation
- **Conclusion: Panel add/remove/enable/disable is Tier 2. Panel reordering requires localStorage pre-seeding or delete-reinsert pattern.**

**event-handlers.ts — Tier 2 fully feasible**
- Only one `stopPropagation()` call — desktop-only external link handler (capture phase, inactive on web)
- All other handlers use standard bubbling
- Two custom events available: `focal-points-ready` and `theme-changed` on `window`
- Fork code can freely listen to all DOM events via standard bubbling

#### Scope Decision

This spike validates the **main entry point only** (`index.html` → `main.ts` → `else` branch). Secondary entry points (`settings.html`, `live-channels.html`, `?settings=1`/`?live-channels=1` code paths) are out of scope — multi-entry-point theming deferred to Epic 2.

#### Test Results

- Fork tests: 9/9 pass (4 config + 5 index) via `npx tsx --test`
- Existing tests: 144/144 pass (92 data + 52 sidecar) — zero regressions
- TypeScript: `tsc --noEmit` clean
- Build: `npm run build` succeeds

### Change Log

- 2026-02-25: Story 0.1 implemented — fork skeleton, Tier 2 hook, CSS injection, CSS audit, module evaluation, build verification
- 2026-02-25: Code review fixes applied — corrected Task 3.2 implementation, strengthened missing-DOM test, and reconciled status/claims for pending Preview deployment
- 2026-02-26: Gate 3 confirmed PASS — Vercel Preview deployment verified (loads, theme visible, CLS = 0). All 3 gates now PASS. Story complete.

### File List

- `src/fork/config.ts` (new — 15 LOC) — SM_CONFIG export
- `src/fork/index.ts` (new — 63 LOC) — init(), injectForkTheme()
- `src/fork/__tests__/config.test.mjs` (new — 26 LOC) — 4 unit tests
- `src/fork/__tests__/index.test.mjs` (new — 80 LOC) — 5 unit tests with DOM mock
- `src/main.ts` (modified — 1 line added at line ~197) — Tier 2 dynamic import hook
- `_spec/implementation-artifacts/0-1-fork-pattern-validation-spike.md` (modified — review findings, status, action items)
