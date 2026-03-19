# Story 5.3: Environment Variable Audit and Configuration Update

Status: ready-for-dev

## Story

As an **operator**,
I want all new environment variables required by upstream features to be documented and configured,
So that new panels and services don't fail silently in Preview or Production.

## Acceptance Criteria

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

## Scope Boundary

This story covers:
- Auditing all new `process.env.*` and `import.meta.env.*` references introduced by upstream
- Verifying Redis key prefix compliance (ARCH-29)
- Updating `fork.env.example` with all new variables
- Documenting new Railway seed services and their cron schedules
- Producing a categorized env var report (required vs optional, by domain)

This story does NOT cover:
- Actually configuring env vars in Vercel dashboard (manual operator task)
- Provisioning new API keys (separate operational task)
- Build validation (Story 5-2)
- Fork branding checks (Story 5-4)

## Tasks / Subtasks

- [ ] **Task 1: Audit new environment variable references** (AC: #1)
  - [ ] 1.1 Diff `process.env.` references: `git diff develop..HEAD -- '*.ts' '*.js' '*.mjs' | grep '+.*process\.env\.'`
  - [ ] 1.2 Diff `import.meta.env.` references: `git diff develop..HEAD -- '*.ts' '*.js' | grep '+.*import\.meta\.env\.'`
  - [ ] 1.3 Categorize each new var: domain, required vs optional, description, source PR
  - [ ] 1.4 Produce the env var report table (see Expected New Env Vars below)

- [ ] **Task 2: Verify Redis key prefix compliance** (AC: #3)
  - [ ] 2.1 Grep for new `UPSTASH_*` references and new Redis key patterns
  - [ ] 2.2 Verify all new Redis key access uses `prefixedKey()` or the wrapper functions (`getCachedJson`, `setCachedJson`, `cachedFetchJson`, `getCachedJsonBatch`)
  - [ ] 2.3 Flag any direct Redis calls that bypass the prefix wrapper
  - [ ] 2.4 If violations found, document them for fix in Story 5-2 or a follow-up commit

- [ ] **Task 3: Update `fork.env.example`** (AC: #2)
  - [ ] 3.1 Add all new environment variables with descriptive comments
  - [ ] 3.2 Group by domain/service (Forecast, Sanctions, Radiation, etc.)
  - [ ] 3.3 Mark each as `# REQUIRED` or `# OPTIONAL — panel will show stale/empty without this`
  - [ ] 3.4 Verify existing fork-specific vars are still present and accurate

- [ ] **Task 4: Document new Railway seed services** (AC: #4)
  - [ ] 4.1 Identify new seed scripts in `scripts/` or `server/` directories
  - [ ] 4.2 For each new service, document: name, purpose, required env vars, cron schedule
  - [ ] 4.3 Note which services are Railway-hosted vs Vercel serverless

- [ ] **Task 5: Produce final env var report** (AC: #1)
  - [ ] 5.1 Compile the full report at the bottom of this story file
  - [ ] 5.2 Include: variable name, domain, required/optional, description, source PR

## Dev Notes

### Architecture Constraints

| Constraint | Rule | Source |
|---|---|---|
| Redis prefix | All Redis key access must use `prefixedKey()` wrapper — `prod:` / `qa:` prefixes | ARCH-29 |
| API key storage | Keys stored exclusively in Vercel env vars, never in source | ARCH security decision |
| Fork env docs | `fork.env.example` documents all fork-specific vars | Story 1-1 established this |

### Expected New Env Vars (from Epic Analysis)

| Service | Likely Env Vars | Source PRs | Required? |
|---------|----------------|------------|-----------|
| Forecast/LLM | `GROQ_API_KEY`, `OPENROUTER_API_KEY`, LLM model overrides | #1579, #1751 | Optional — panel degrades gracefully |
| Sanctions/OFAC | OFAC data source keys | #1739 | Optional — panel shows stale data |
| Radiation Watch | Radiation data source keys, Safecast API | #1735 | Optional |
| Thermal Escalation | Thermal data source config | #1747 | Optional |
| CorridorRisk | `CORRIDORRISK_API_KEY` | #1616 | Optional |
| Wingbits | `WINGBITS_API_KEY` | #1240, #1816, #1839 | Optional — fallback for OpenSky |
| MCP | MCP server connection config | #1835 | Optional — user-configured |
| Widgets/Exa | `EXA_API_KEY` | #1782 | Optional — PRO tier feature |
| Mintlify Docs | Mintlify API key | #1444 | Optional — /docs route |
| IndexNow/SEO | IndexNow key | #1833 | Optional — SEO feature |
| CoinPaprika | CoinPaprika API config | #1092 | Optional |
| Kalshi | Kalshi API config | #1355 | Optional |
| Freight Indices | SCFI/CCFI/BDI data source config | #1666 | Optional |
| R2 Storage | `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT` | #1831, #1832 | Optional — trace export |

### Depends On

- Story 5-1 must be complete (merged upstream-sync branch)
- Can run in parallel with Story 5-2

### Commit Convention

Commits use prefix: `[sync] env audit — {description}`
