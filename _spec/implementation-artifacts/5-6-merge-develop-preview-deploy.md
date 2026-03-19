# Story 5.6: Merge to Develop and Deploy to Preview

Status: ready-for-dev

## Story

As an **operator**,
I want the validated upstream-sync branch merged into `develop` and deployed to Vercel Preview,
So that the full upstream feature set is available for QA validation.

## Acceptance Criteria

1. **Given** all previous stories (5-1 through 5-5) are complete and passing
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

## Scope Boundary

This story covers:
- Opening a PR from `upstream-sync/2026-03-18` → `develop`
- Verifying CI passes on the PR
- Merging the PR
- Verifying the Vercel Preview deployment loads
- Running smoke tests against the Preview deployment
- Documenting any panels that need API keys not yet configured

This story does NOT cover:
- Production promotion (separate operational decision)
- Configuring new API keys in Vercel (manual operator task, guided by Story 5-3 env audit)
- Writing new E2E tests for upstream features (future work)
- Retrospective (separate epic-5-retrospective)

## Tasks / Subtasks

- [ ] **Task 1: Open PR** (AC: #1)
  - [ ] 1.1 Push `upstream-sync/2026-03-18` to origin if not already pushed
  - [ ] 1.2 Open PR: `upstream-sync/2026-03-18` → `develop`
  - [ ] 1.3 PR title: `[sync] merge upstream PRs #809–#1851 (648 commits)`
  - [ ] 1.4 PR description: summarize the sync — link to epic-5 file, list story completion status
  - [ ] 1.5 Add labels if applicable (e.g., `upstream-sync`, `large`)

- [ ] **Task 2: Verify CI passes** (AC: #1)
  - [ ] 2.1 Wait for CI pipeline to complete
  - [ ] 2.2 Verify all checks pass: lint, unit tests, build, proto check
  - [ ] 2.3 If CI fails, debug — likely a difference between local and CI environments (env vars, Node version, etc.)
  - [ ] 2.4 Fix any CI-specific failures and push

- [ ] **Task 3: Merge PR** (AC: #4)
  - [ ] 3.1 Use merge commit (not squash) to preserve upstream commit history
  - [ ] 3.2 Merge commit message: `[sync] merge upstream PRs #809–#1851`
  - [ ] 3.3 Delete the `upstream-sync/2026-03-18` branch after merge

- [ ] **Task 4: Verify Preview deployment** (AC: #2)
  - [ ] 4.1 Wait for Vercel to create the Preview deployment from the merge to `develop`
  - [ ] 4.2 Open the Preview URL — verify the app loads without errors
  - [ ] 4.3 Check browser console for JavaScript errors
  - [ ] 4.4 Verify Situation Monitor branding is displayed (not upstream branding)
  - [ ] 4.5 Navigate to at least 3 new panels to verify they render (may show empty/stale data without API keys)

- [ ] **Task 5: Smoke test Preview deployment** (AC: #3)
  - [ ] 5.1 Run endpoint smoke test against the Preview URL
  - [ ] 5.2 Expect: all existing endpoints return 200 or valid responses
  - [ ] 5.3 Expect: new endpoints may return error/empty if API keys aren't configured in Preview
  - [ ] 5.4 Document which endpoints need API key configuration

- [ ] **Task 6: Document deployment results** (AC: #2, #3)
  - [ ] 6.1 Record Preview URL and deployment status
  - [ ] 6.2 List panels that are fully functional vs those needing API keys
  - [ ] 6.3 List any runtime errors found in Preview that weren't caught locally
  - [ ] 6.4 Update sprint-status.yaml to mark epic-5 stories as done

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| Merge strategy | Use merge commit, not squash — preserve full upstream history | Upstream sync strategy |
| Branch pattern | `upstream-sync/{date}` branch per architecture | Architecture: Upstream Sync Strategy |
| CI pipeline | Must pass lint, test, build, proto check | Epic 1 CI pipeline (if configured) |
| Preview environment | Vercel auto-deploys from `develop` branch | Vercel project configuration |
| Commit prefix | `[sync] merge upstream PRs #809–#1851` | Epic commit convention |

### Preview Deployment Expectations

- The app should load and display the Situation Monitor branding
- Panels without configured API keys will show empty/stale/error states — this is expected
- New routes (`/blog`, `/docs`, `/pro`) may or may not be active depending on upstream build config
- The globe, map, and core navigation should all function

### Panels Likely Needing API Keys for Full Functionality

| Panel | Required Env Var(s) | Configured? |
|-------|--------------------|----|
| Forecast | `GROQ_API_KEY`, `OPENROUTER_API_KEY` | TBD |
| Sanctions | OFAC source keys | TBD |
| Radiation | Safecast API keys | TBD |
| Thermal | Thermal source config | TBD |
| CorridorRisk | `CORRIDORRISK_API_KEY` | TBD |
| Wingbits | `WINGBITS_API_KEY` | TBD |
| MCP | MCP server config | TBD (user-configured) |
| Widgets/Exa | `EXA_API_KEY` | TBD |

Fill in from Story 5-3 env audit results.

### Depends On

- All stories 5-1 through 5-5 must be complete and passing

### Commit Convention

Merge commit: `[sync] merge upstream PRs #809–#1851`
