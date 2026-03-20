# Story 5.3: Environment Variable Audit and Configuration Update

Status: complete

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

- [x] **Task 1: Audit new environment variable references** (AC: #1)
  - [x] 1.1 Diff `process.env.` references: `git diff develop..HEAD -- '*.ts' '*.js' '*.mjs' | grep '+.*process\.env\.'`
  - [x] 1.2 Diff `import.meta.env.` references: `git diff develop..HEAD -- '*.ts' '*.js' | grep '+.*import\.meta\.env\.'`
  - [x] 1.3 Categorize each new var: domain, required vs optional, description, source PR
  - [x] 1.4 Produce the env var report table (see Audit Results → Task 1 below)

- [x] **Task 2: Verify Redis key prefix compliance** (AC: #3)
  - [x] 2.1 Grep for new `UPSTASH_*` references and new Redis key patterns
  - [x] 2.2 Verify all new Redis key access uses `prefixedKey()` or the wrapper functions (`getCachedJson`, `setCachedJson`, `cachedFetchJson`, `getCachedJsonBatch`)
  - [x] 2.3 Flag any direct Redis calls that bypass the prefix wrapper
  - [x] 2.4 If violations found, document them for fix in Story 5-2 or a follow-up commit

- [x] **Task 3: Update `fork.env.example`** (AC: #2)
  - [x] 3.1 Add all new environment variables with descriptive comments
  - [x] 3.2 Group by domain/service (AI/LLM, Cybersecurity, Seeding, etc.)
  - [x] 3.3 Mark each as `# REQUIRED` or `# OPTIONAL — panel will show stale/empty without this`
  - [x] 3.4 Verify existing fork-specific vars are still present and accurate

- [x] **Task 4: Document new Railway seed services** (AC: #4)
  - [x] 4.1 Identify new seed scripts in `scripts/` or `server/` directories
  - [x] 4.2 For each new service, document: name, purpose, required env vars, cron schedule
  - [x] 4.3 Note which services are Railway-hosted vs Vercel serverless

- [x] **Task 5: Produce final env var report** (AC: #1)
  - [x] 5.1 Compile the full report at the bottom of this story file
  - [x] 5.2 Include: variable name, domain, required/optional, description, source PR

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

---

## Audit Results

### Task 1: New Environment Variable References

#### process.env.* — Variables NOT in upstream `.env.example`

The following `process.env.*` references were found in the codebase but are absent from the upstream `.env.example`. They have been added to `fork.env.example`.

| Variable | Domain | Required? | Description | Location |
|---|---|---|---|---|
| `OTX_API_KEY` | Cybersecurity | OPTIONAL | AlienVault OTX IPv4 threat feed | `server/worldmonitor/cyber/v1/_shared.ts`, `scripts/seed-cyber-threats.mjs`, `scripts/ais-relay.cjs` |
| `ABUSEIPDB_API_KEY` | Cybersecurity | OPTIONAL | AbuseIPDB IP reputation blacklist | `server/worldmonitor/cyber/v1/_shared.ts`, `scripts/seed-cyber-threats.mjs`, `scripts/ais-relay.cjs` |
| `URLHAUS_AUTH_KEY` | Cybersecurity | OPTIONAL | URLhaus malware URL database | `server/worldmonitor/cyber/v1/_shared.ts`, `scripts/seed-cyber-threats.mjs`, `scripts/ais-relay.cjs` |
| `WTO_API_KEY` | Trade / Economic | OPTIONAL | World Trade Organization tariff + policy API | `server/worldmonitor/trade/v1/_shared.ts`, `src-tauri/sidecar/local-api-server.mjs` |
| `OLLAMA_API_URL` | AI / Summarization | OPTIONAL | Local Ollama server URL for on-device news summarization | `server/worldmonitor/news/v1/_shared.ts`, `src-tauri/sidecar/local-api-server.mjs` |
| `OLLAMA_MODEL` | AI / Summarization | OPTIONAL | Ollama model name (default: `llama3.1:8b`) | `server/worldmonitor/news/v1/_shared.ts`, `src-tauri/sidecar/local-api-server.mjs` |
| `OLLAMA_API_KEY` | AI / Summarization | OPTIONAL | Optional bearer token for authenticated Ollama endpoints | `server/worldmonitor/news/v1/_shared.ts` |
| `OLLAMA_MAX_TOKENS` | AI / Summarization | OPTIONAL | Max tokens per Ollama response (default: 300) | `server/worldmonitor/news/v1/_shared.ts` |
| `LLM_API_KEY` | AI / Situation | OPTIONAL | Custom LLM API key (falls back to `GROQ_API_KEY`) | `server/worldmonitor/intelligence/v1/deduct-situation.ts` |
| `LLM_API_URL` | AI / Situation | OPTIONAL | Custom LLM endpoint URL (falls back to Groq) | `server/worldmonitor/intelligence/v1/deduct-situation.ts` |
| `LLM_MODEL` | AI / Situation | OPTIONAL | Custom LLM model name override | `server/worldmonitor/intelligence/v1/deduct-situation.ts` |
| `SEED_FALLBACK_CYBER` | Seeding | OPTIONAL | When set: enables live cyber threat fetch if seed is stale | `server/worldmonitor/cyber/v1/list-cyber-threats.ts` |
| `SEED_FALLBACK_DISPLACEMENT` | Seeding | OPTIONAL | When set: enables live displacement fetch if seed is stale | `server/worldmonitor/displacement/v1/get-displacement-summary.ts` |
| `SEED_FALLBACK_EARTHQUAKES` | Seeding | OPTIONAL | When set: enables live earthquake fetch if seed is stale | `server/worldmonitor/seismology/v1/list-earthquakes.ts` |
| `SEED_FALLBACK_ETF` | Seeding | OPTIONAL | When set: enables live ETF flow fetch if seed is stale | `server/worldmonitor/market/v1/list-etf-flows.ts` |
| `SEED_FALLBACK_FAA` | Seeding | OPTIONAL | When set: enables live FAA delay fetch if seed is stale | `server/worldmonitor/aviation/v1/list-airport-delays.ts` |
| `SEED_FALLBACK_GULF` | Seeding | OPTIONAL | When set: enables live Gulf quote fetch if seed is stale | `server/worldmonitor/market/v1/list-gulf-quotes.ts` |
| `SEED_FALLBACK_CLIMATE` | Seeding | OPTIONAL | When set: enables live climate anomaly fetch if seed is stale | `server/worldmonitor/climate/v1/list-climate-anomalies.ts` |
| `SEED_FALLBACK_CRYPTO` | Seeding | OPTIONAL | When set: enables live crypto quote fetch if seed is stale | `server/worldmonitor/market/v1/list-crypto-quotes.ts` |
| `SEED_FALLBACK_NATURAL` | Seeding | OPTIONAL | When set: enables live natural event fetch if seed is stale | `server/worldmonitor/natural/v1/list-natural-events.ts` |
| `SEED_FALLBACK_NOTAM` | Seeding | OPTIONAL | When set: enables live NOTAM fetch if seed is stale | `server/worldmonitor/aviation/v1/list-airport-delays.ts` |
| `SEED_FALLBACK_OUTAGES` | Seeding | OPTIONAL | When set: enables live outage fetch if seed is stale | `server/worldmonitor/infrastructure/v1/list-internet-outages.ts` |
| `SEED_FALLBACK_STABLECOINS` | Seeding | OPTIONAL | When set: enables live stablecoin fetch if seed is stale | `server/worldmonitor/market/v1/list-stablecoin-markets.ts` |
| `SEED_FALLBACK_UNREST` | Seeding | OPTIONAL | When set: enables live unrest event fetch if seed is stale | `server/worldmonitor/unrest/v1/list-unrest-events.ts` |
| `SEED_FALLBACK_WILDFIRES` | Seeding | OPTIONAL | When set: enables live wildfire detection fetch if seed is stale | `server/worldmonitor/wildfire/v1/list-fire-detections.ts` |
| `FIRMS_API_KEY` | Wildfire | OPTIONAL | Legacy alias for `NASA_FIRMS_API_KEY` (seed-fire-detections.mjs only) | `scripts/seed-fire-detections.mjs` |
| `UC_DP_KEY` | Conflict | OPTIONAL | Legacy alias for `UCDP_ACCESS_TOKEN` (seed-ucdp-events.mjs only) | `scripts/seed-ucdp-events.mjs` |

#### import.meta.env.* — Variables NOT in upstream `.env.example`

The following client-side `import.meta.env.*` references were found but are absent from the upstream `.env.example`. They have been added to `fork.env.example`.

| Variable | Domain | Required? | Description | Location |
|---|---|---|---|---|
| `VITE_ENABLE_AIS` | Feature Flag | OPTIONAL | Enable AIS maritime tracking layer at build time | `src/config/feeds.ts`, `src/services/maritime/index.ts` |
| `VITE_ENABLE_CYBER_LAYER` | Feature Flag | OPTIONAL | Enable cybersecurity threat layer at build time | `src/config/feeds.ts` |
| `VITE_RSS_DIRECT_TO_RELAY` | Feature Flag | OPTIONAL | Route RSS feeds directly to the relay server | `src/config/feeds.ts` |

#### Variables already in upstream `.env.example` (no changes needed)

`GROQ_API_KEY`, `OPENROUTER_API_KEY`, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, `FINNHUB_API_KEY`, `EIA_API_KEY`, `FRED_API_KEY`, `AVIATIONSTACK_API`, `ICAO_API_KEY`, `TRAVELPAYOUTS_API_TOKEN`, `WINGBITS_API_KEY`, `ACLED_ACCESS_TOKEN`, `UCDP_ACCESS_TOKEN`, `CLOUDFLARE_API_TOKEN`, `NASA_FIRMS_API_KEY`, `AISSTREAM_API_KEY`, `OPENSKY_CLIENT_ID`, `OPENSKY_CLIENT_SECRET`, `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `TELEGRAM_SESSION`, `TELEGRAM_CHANNEL_SET`, `WS_RELAY_URL`, `VITE_WS_RELAY_URL`, `RELAY_SHARED_SECRET`, `RELAY_AUTH_HEADER`, `ALLOW_UNAUTHENTICATED_RELAY`, `RELAY_METRICS_WINDOW_SECONDS`, `VITE_VARIANT`, `VITE_WS_API_URL`, `VITE_SENTRY_DSN`, `VITE_MAP_INTERACTION_MODE`, `WORLDMONITOR_VALID_KEYS`, `CONVEX_URL`

#### Expected-but-Not-Found Variables (from Epic 5 PR analysis)

These were anticipated from Epic 5 PR analysis but are **not present in the codebase** as of this audit. They are stubbed in `fork.env.example` as commented-out entries pending those PRs merging.

| Variable | Source PR | Status |
|---|---|---|
| `CORRIDORRISK_API_KEY` | #1616 | Not merged — no code references found |
| `EXA_API_KEY` | #1782 | Not merged — no code references found |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT` | #1831, #1832 | Not merged — no code references found |
| `COINPAPRIKA_API_KEY` | #1092 | Not merged — no code references found |
| `KALSHI_API_KEY` / `KALSHI_API_SECRET` | #1355 | Not merged — no code references found |
| `FREIGHT_DATA_API_KEY` (SCFI/CCFI/BDI) | #1666 | Not merged — no code references found |
| `MINTLIFY_API_KEY` | #1444 | Not merged — no code references found |
| `INDEXNOW_KEY` | #1833 | Not merged — no code references found |
| `OFAC_API_KEY` | #1739 | Not merged — no code references found |
| `SAFECAST_API_KEY` | #1735 | Not merged — no code references found |
| `MCP_SERVER_URL` | #1835 | Not merged — no code references found |

---

### Task 2: Redis Key Prefix Compliance (ARCH-29)

**Summary: COMPLIANT — no violations found in Vercel edge functions.**

#### Compliant implementations

| File | Status | Notes |
|---|---|---|
| `server/_shared/redis.ts` | ✅ COMPLIANT | Central hub; `prefixKey()` is applied in every exported function (`getCachedJson`, `setCachedJson`, `getCachedJsonBatch`, `cachedFetchJson`, `geoSearchByBox`, `getHashFieldsBatch`). The `raw=true` escape hatch exists for intentional unprefixed reads. |
| `server/_shared/rate-limit.ts` | ✅ COMPLIANT | Uses Upstash `Ratelimit` class with its own namespace; not subject to ARCH-29 key collision. |
| `api/cache-purge.js` | ✅ COMPLIANT | Implements its own `getKeyPrefix()` (mirrors `redis.ts`) and correctly applies the prefix for both pattern scans and DEL commands. |
| `api/bootstrap.js` | ✅ INTENTIONAL BYPASS | Has explicit inline comment: _"Always read unprefixed keys — bootstrap is a read-only consumer of production cache data. Preview/branch deploys don't run handlers that populate prefixed keys, so prefixing would always miss."_ Design intent is correct. |
| `scripts/_seed-utils.mjs` | ✅ INTENTIONAL BYPASS | Seed scripts run on Railway and write canonical production keys. They are the *source* of production data; writing unprefixed keys is correct. |

#### Potential documentation gap (non-blocking)

| File | Status | Notes |
|---|---|---|
| `api/gpsjam.js` | ⚠️ UNDOCUMENTED BYPASS | Uses `REDIS_KEY = 'intelligence:gpsjam:v1'` directly via `fetch()` without the `prefixedKey()` wrapper and without an explanatory comment. Behaviorally correct (GPS Jam data is seeded to unprefixed production keys and `gpsjam.js` is a read-only consumer), but the bypass is undocumented. Recommend adding the same comment pattern used in `api/bootstrap.js`. No functional impact — no fix required for this story. |

---

### Task 3: `fork.env.example` Update

**Status: COMPLETE** — `fork.env.example` created at repo root.

Changes from upstream `.env.example`:
- Added **27 new variables** across 6 new sections (Cybersecurity, AI/Ollama, LLM Overrides, WTO Trade, Seed Fallback Flags, Vite Feature Flags)
- All existing upstream variables preserved and re-documented
- Each variable annotated with `# REQUIRED` or `# OPTIONAL` plus a one-line description
- Grouped by deployment target (Vercel / Railway / Desktop)
- Anticipated-but-not-yet-merged upstream variables stubbed as commented-out entries with source PR references
- Vercel system-injected variables (`VERCEL_ENV`, `VERCEL_GIT_COMMIT_SHA`) documented as read-only references

---

### Task 4: Railway Seed Services

All seed scripts reside in `scripts/` and run on Railway as scheduled cron jobs (or as part of the persistent `ais-relay.cjs` service). The upstream `.env.example` documents the relay deployment; the cron schedules below are inferred from data freshness TTLs in the consuming edge functions.

#### Persistent Railway Service

| Service | File | Purpose | Required Env Vars | Deployment |
|---|---|---|---|---|
| AIS/OpenSky/RSS/Cyber/Telegram Relay | `scripts/ais-relay.cjs` | WebSocket relay for live vessel positions, aircraft data, RSS proxy, cyber threat seeding, Telegram OSINT | `AISSTREAM_API_KEY`, `OPENSKY_CLIENT_ID`, `OPENSKY_CLIENT_SECRET`, `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `TELEGRAM_SESSION`, `TELEGRAM_CHANNEL_SET`, `OTX_API_KEY`, `ABUSEIPDB_API_KEY`, `URLHAUS_AUTH_KEY`, `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`, `WS_RELAY_URL`, `RELAY_SHARED_SECRET`, `RELAY_AUTH_HEADER` | Railway — persistent |

#### Railway Cron Seed Jobs

| Script | Domain | Inferred Cron | Required Env Vars |
|---|---|---|---|
| `seed-airport-delays.mjs` | Aviation / FAA + NOTAM | Every 1h | `ICAO_API_KEY`, `UPSTASH_*` |
| `seed-climate-anomalies.mjs` | Climate | Every 24h | `UPSTASH_*` |
| `seed-commodity-quotes.mjs` | Market / Commodities | Every 15min | `UPSTASH_*` |
| `seed-crypto-quotes.mjs` | Market / Crypto | Every 5min | `UPSTASH_*` |
| `seed-cyber-threats.mjs` | Cybersecurity | Every 6h | `OTX_API_KEY`, `ABUSEIPDB_API_KEY`, `URLHAUS_AUTH_KEY`, `UPSTASH_*` |
| `seed-displacement-summary.mjs` | Displacement / UNHCR | Every 24h | `UPSTASH_*` |
| `seed-earthquakes.mjs` | Seismology / USGS | Every 5min | `UPSTASH_*` |
| `seed-etf-flows.mjs` | Market / ETF | Every 24h | `UPSTASH_*` |
| `seed-fire-detections.mjs` | Wildfire / FIRMS | Every 1h | `NASA_FIRMS_API_KEY`, `UPSTASH_*` |
| `seed-gulf-quotes.mjs` | Market / Gulf Region | Every 15min | `UPSTASH_*` |
| `seed-insights.mjs` | News / Intelligence | Every 1h | `GROQ_API_KEY` (or `OPENROUTER_API_KEY`), `UPSTASH_*` |
| `seed-internet-outages.mjs` | Infrastructure / Cloudflare | Every 5min | `CLOUDFLARE_API_TOKEN`, `UPSTASH_*` |
| `seed-iran-events.mjs` | Conflict / MENA | Every 1h | `UPSTASH_*` |
| `seed-market-quotes.mjs` | Market / Equities | Every 5min | `FINNHUB_API_KEY`, `UPSTASH_*` |
| `seed-military-bases.mjs` | Military / Geo | One-time / manual | `UPSTASH_*` |
| `seed-natural-events.mjs` | Natural Disasters | Every 1h | `UPSTASH_*` |
| `seed-stablecoin-markets.mjs` | Market / Stablecoins | Every 5min | `UPSTASH_*` |
| `seed-ucdp-events.mjs` | Conflict / UCDP | Daily | `UCDP_ACCESS_TOKEN`, `UPSTASH_*` |
| `seed-unrest-events.mjs` | Conflict / ACLED | Every 1h | `ACLED_ACCESS_TOKEN`, `UPSTASH_*` |
| `seed-wb-indicators.mjs` | Economic / World Bank | Weekly | `UPSTASH_*` |
| `seed-wb-indicators.mjs` | Economic / World Bank | Weekly | `FRED_API_KEY`, `UPSTASH_*` |

**Note:** Cron schedules are inferred from edge function cache TTLs and are not defined in `railpack.json` (which only specifies apt packages). Actual schedules should be set in the Railway dashboard under each service's cron configuration.

---

### Task 5: Final Env Var Report

#### Complete Categorized Variable List

| Variable | Domain | Required? | Description |
|---|---|---|---|
| `GROQ_API_KEY` | AI / LLM | OPTIONAL | Groq primary LLM provider (14,400 req/day free) |
| `OPENROUTER_API_KEY` | AI / LLM | OPTIONAL | OpenRouter fallback LLM provider (50 req/day free) |
| `LLM_API_KEY` | AI / LLM | OPTIONAL | Custom LLM API key override (new in upstream sync) |
| `LLM_API_URL` | AI / LLM | OPTIONAL | Custom LLM endpoint URL (new in upstream sync) |
| `LLM_MODEL` | AI / LLM | OPTIONAL | Custom LLM model name (new in upstream sync) |
| `OLLAMA_API_URL` | AI / Ollama | OPTIONAL | Local Ollama server URL (new in upstream sync) |
| `OLLAMA_MODEL` | AI / Ollama | OPTIONAL | Ollama model name (new in upstream sync) |
| `OLLAMA_API_KEY` | AI / Ollama | OPTIONAL | Optional Ollama bearer token (new in upstream sync) |
| `OLLAMA_MAX_TOKENS` | AI / Ollama | OPTIONAL | Max Ollama response tokens (new in upstream sync) |
| `UPSTASH_REDIS_REST_URL` | Infrastructure / Cache | REQUIRED (prod) | Upstash Redis endpoint |
| `UPSTASH_REDIS_REST_TOKEN` | Infrastructure / Cache | REQUIRED (prod) | Upstash Redis auth token |
| `FINNHUB_API_KEY` | Market / Equities | OPTIONAL | Stock quotes |
| `EIA_API_KEY` | Energy | OPTIONAL | EIA oil/gas data |
| `FRED_API_KEY` | Economic | OPTIONAL | FRED macro data |
| `WTO_API_KEY` | Trade / Economic | OPTIONAL | WTO tariff + policy API (new in upstream sync) |
| `AVIATIONSTACK_API` | Aviation | OPTIONAL | Live flight data |
| `ICAO_API_KEY` | Aviation / NOTAM | OPTIONAL | NOTAM airport closures |
| `TRAVELPAYOUTS_API_TOKEN` | Aviation / Pricing | OPTIONAL | Flight price search |
| `WINGBITS_API_KEY` | Aviation / Tracking | OPTIONAL | Aircraft enrichment |
| `ACLED_ACCESS_TOKEN` | Conflict | OPTIONAL | ACLED conflict events |
| `UCDP_ACCESS_TOKEN` | Conflict | OPTIONAL | UCDP conflict database |
| `UC_DP_KEY` | Conflict | OPTIONAL | Legacy alias for `UCDP_ACCESS_TOKEN` |
| `OTX_API_KEY` | Cybersecurity | OPTIONAL | AlienVault OTX threat feed (new in upstream sync) |
| `ABUSEIPDB_API_KEY` | Cybersecurity | OPTIONAL | AbuseIPDB blacklist (new in upstream sync) |
| `URLHAUS_AUTH_KEY` | Cybersecurity | OPTIONAL | URLhaus malware URLs (new in upstream sync) |
| `CLOUDFLARE_API_TOKEN` | Infrastructure / Outages | OPTIONAL | Cloudflare Radar outages |
| `NASA_FIRMS_API_KEY` | Wildfire | OPTIONAL | NASA satellite fire data |
| `FIRMS_API_KEY` | Wildfire | OPTIONAL | Legacy alias for `NASA_FIRMS_API_KEY` |
| `AISSTREAM_API_KEY` | Maritime | OPTIONAL | AIS vessel tracking |
| `OPENSKY_CLIENT_ID` | Aviation / Tracking | OPTIONAL | OpenSky aircraft data |
| `OPENSKY_CLIENT_SECRET` | Aviation / Tracking | OPTIONAL | OpenSky auth |
| `TELEGRAM_API_ID` | OSINT / Telegram | OPTIONAL | Telegram MTProto app ID |
| `TELEGRAM_API_HASH` | OSINT / Telegram | OPTIONAL | Telegram MTProto hash |
| `TELEGRAM_SESSION` | OSINT / Telegram | OPTIONAL | GramJS session string |
| `TELEGRAM_CHANNEL_SET` | OSINT / Telegram | OPTIONAL | Channel bucket (full/tech/finance) |
| `WS_RELAY_URL` | Relay | REQUIRED (if relay) | Server-side relay HTTPS URL |
| `VITE_WS_RELAY_URL` | Relay | OPTIONAL | Client-side relay WSS URL |
| `RELAY_SHARED_SECRET` | Relay | REQUIRED (if relay) | Shared auth secret |
| `RELAY_AUTH_HEADER` | Relay | OPTIONAL | Header name for relay secret |
| `ALLOW_UNAUTHENTICATED_RELAY` | Relay | OPTIONAL | Emergency bypass (false) |
| `RELAY_METRICS_WINDOW_SECONDS` | Relay | OPTIONAL | Metrics window (60s) |
| `SEED_FALLBACK_CYBER` | Seeding | OPTIONAL | Live fallback for cyber threats (new in upstream sync) |
| `SEED_FALLBACK_DISPLACEMENT` | Seeding | OPTIONAL | Live fallback for displacement (new in upstream sync) |
| `SEED_FALLBACK_EARTHQUAKES` | Seeding | OPTIONAL | Live fallback for earthquakes (new in upstream sync) |
| `SEED_FALLBACK_ETF` | Seeding | OPTIONAL | Live fallback for ETF flows (new in upstream sync) |
| `SEED_FALLBACK_FAA` | Seeding | OPTIONAL | Live fallback for FAA delays (new in upstream sync) |
| `SEED_FALLBACK_GULF` | Seeding | OPTIONAL | Live fallback for Gulf quotes (new in upstream sync) |
| `SEED_FALLBACK_CLIMATE` | Seeding | OPTIONAL | Live fallback for climate anomalies (new in upstream sync) |
| `SEED_FALLBACK_CRYPTO` | Seeding | OPTIONAL | Live fallback for crypto (new in upstream sync) |
| `SEED_FALLBACK_NATURAL` | Seeding | OPTIONAL | Live fallback for natural events (new in upstream sync) |
| `SEED_FALLBACK_NOTAM` | Seeding | OPTIONAL | Live fallback for NOTAMs (new in upstream sync) |
| `SEED_FALLBACK_OUTAGES` | Seeding | OPTIONAL | Live fallback for outages (new in upstream sync) |
| `SEED_FALLBACK_STABLECOINS` | Seeding | OPTIONAL | Live fallback for stablecoins (new in upstream sync) |
| `SEED_FALLBACK_UNREST` | Seeding | OPTIONAL | Live fallback for unrest (new in upstream sync) |
| `SEED_FALLBACK_WILDFIRES` | Seeding | OPTIONAL | Live fallback for wildfires (new in upstream sync) |
| `VITE_VARIANT` | Site Config | OPTIONAL | full/tech/finance/happy |
| `VITE_WS_API_URL` | Site Config | OPTIONAL | API base URL for browser fetches |
| `VITE_SENTRY_DSN` | Site Config | OPTIONAL | Client-side error tracking DSN |
| `VITE_MAP_INTERACTION_MODE` | Site Config | OPTIONAL | flat or 3d |
| `VITE_ENABLE_AIS` | Feature Flag | OPTIONAL | Enable AIS layer (new in upstream sync) |
| `VITE_ENABLE_CYBER_LAYER` | Feature Flag | OPTIONAL | Enable cyber layer (new in upstream sync) |
| `VITE_RSS_DIRECT_TO_RELAY` | Feature Flag | OPTIONAL | Route RSS to relay (new in upstream sync) |
| `WORLDMONITOR_VALID_KEYS` | Desktop / Auth | OPTIONAL | Desktop cloud fallback API keys |
| `CONVEX_URL` | Registration | OPTIONAL | Convex deployment URL |
