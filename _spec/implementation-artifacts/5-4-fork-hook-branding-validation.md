# Story 5.4: Fork Hook and Branding Integrity Validation

Status: ready-for-dev

## Story

As an **operator**,
I want to verify that all fork customizations (branding, CSS overrides, fork hook) still function after the upstream sync,
So that the Situation Monitor identity and fork behavior are preserved.

## Acceptance Criteria

1. **Given** the build passes from Story 5-2
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

## Scope Boundary

This story covers:
- Starting the dev server and verifying the fork hook executes cleanly
- Verifying Situation Monitor branding: page title, meta tags, OG metadata, favicon
- Spot-checking new upstream panels for CSS token compliance with fork `--sm-*` design tokens
- Verifying globe, map layers, and settings UI are intact
- Running a Lighthouse check for CLS = 0
- Fixing any fork regressions found during validation

This story does NOT cover:
- Build/lint fixes (Story 5-2 — must be done first)
- Env var setup for new panels to show live data (Story 5-3)
- E2E test execution (Story 5-5)
- Deploying to Preview (Story 5-6)

## Tasks / Subtasks

- [ ] **Task 1: Verify fork hook execution** (AC: #1, #2)
  - [ ] 1.1 Start dev server: `make dev`
  - [ ] 1.2 Open browser and check browser console — verify `[fork]` log messages indicate successful hook execution
  - [ ] 1.3 Confirm zero `[fork] ...` warning messages (warnings indicate degradation or missing surface)
  - [ ] 1.4 Verify `src/fork/index.ts` import is executing (check that fork customizations are applied)

- [ ] **Task 2: Verify branding integrity** (AC: #1)
  - [ ] 2.1 Check page title is "Situation Monitor" (not upstream "World Monitor")
  - [ ] 2.2 Check `<meta>` description and keywords reflect Situation Monitor branding
  - [ ] 2.3 Check OG metadata: `og:title`, `og:description`, `og:image` are fork-branded
  - [ ] 2.4 Check favicon is the Situation Monitor icon (not upstream default)
  - [ ] 2.5 If any branding is lost, trace the cause to a merge resolution error in 5-1

- [ ] **Task 3: Audit new panels for CSS token compliance** (AC: #3)
  - [ ] 3.1 Identify all new panels added by upstream (Forecast, MCP, Thermal, Sanctions, Radiation, Macro Stress, CorridorRisk, Widgets, etc.)
  - [ ] 3.2 Spot-check at least 5 new panels: open each, verify they use `--sm-*` CSS custom properties
  - [ ] 3.3 Check for hardcoded color values that should be using design tokens
  - [ ] 3.4 Document any panels with color drift for follow-up in Epic 6 (Accessibility & Design System)

- [ ] **Task 4: Verify map, globe, and settings UI** (AC: #4)
  - [ ] 4.1 Open the globe view — verify rendering, rotation, and data layers
  - [ ] 4.2 Open the map view — verify tile rendering, country hover (#1064), sea context menu (#1101)
  - [ ] 4.3 Open settings — verify settings UI loads and fork-specific options are preserved
  - [ ] 4.4 Check for layout shifts or visual glitches in branded areas

- [ ] **Task 5: Lighthouse CLS check** (AC: #4)
  - [ ] 5.1 Run Lighthouse on `localhost` (or use DevTools Performance panel)
  - [ ] 5.2 Verify CLS = 0 (or < 0.1 threshold)
  - [ ] 5.3 If CLS regressions found, trace to upstream layout changes and document

- [ ] **Task 6: Fix fork regressions** (AC: #1–#4)
  - [ ] 6.1 For each issue found, create a fix commit with prefix `[sync] fix fork {description}`
  - [ ] 6.2 Re-verify after each fix
  - [ ] 6.3 If a fix requires modifying upstream code, document as Tier 2 monkey-patch per architecture

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| Fork hook mechanism | Single import in `src/main.ts` → `src/fork/index.ts` | ARCH-37 |
| Fork CSS approach | CSS custom properties `--sm-*` injected by fork hook, cascading to all panels | Architecture branding decision |
| CLS target | CLS = 0 for fork branded areas | UX specification |
| Fork tier system | Tier 1 = fork-only files, Tier 2 = monkey-patches, Tier 3 = upstream modifications | Architecture fork tier system |

### New Panels to Check (from Epic Analysis)

| Panel | Source PRs | Expected CSS Behavior |
|-------|-----------|----------------------|
| Forecast (AI Predictions) | #1579, #1646., #1773+ | Should inherit `--sm-*` tokens |
| MCP Data | #1835, #1845, #1848 | Should inherit `--sm-*` tokens |
| Thermal Escalation | #1747, #1786 | Should inherit `--sm-*` tokens |
| OFAC Sanctions | #1739 | Should inherit `--sm-*` tokens |
| Radiation Watch | #1735 | Should inherit `--sm-*` tokens |
| Macro Stress Signals | #1719 | Should inherit `--sm-*` tokens |
| Energy Complex | #1749 | Should inherit `--sm-*` tokens |
| CorridorRisk | #1616 | Should inherit `--sm-*` tokens |
| Satellite Surveillance | #1278, #1342 | Globe visual — check token usage |
| Weather Radar (map layer) | #1356 | Map layer — check overlay styling |

### Depends On

- Story 5-2 must be complete (clean build)
- Story 5-3 is helpful but not blocking (panels may show empty/stale states without API keys — that's fine for branding validation)

### Commit Convention

Fix commits use prefix: `[sync] fix fork {description}`
