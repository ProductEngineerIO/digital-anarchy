#!/usr/bin/env bash
# =============================================================================
# validate-endpoints.sh
#
# Endpoint smoke test for Situation Monitor.
# Verifies that all API route paths resolve (no 404 / network error).
# Designed to run against `vercel dev` (default port 3000) for API routes,
# and against the Vite dev server (default port 4173) for frontend routes.
#
# Usage:
#   ./scripts/validate-endpoints.sh [options]
#
# Options:
#   --frontend-url URL   Base URL for frontend routes  (default: http://127.0.0.1:4173)
#   --api-url URL        Base URL for API routes        (default: http://127.0.0.1:3000)
#   --skip-api           Skip API route checks (frontend-only mode)
#   --fail-on-404        Exit non-zero only on HTTP 404 (not on 401/403/500 — those mean route exists)
#   -h / --help          Show this help message
#
# Notes:
#   - API routes (api/) are Vercel Edge Functions; they only run under `vercel dev` or
#     in the Vercel deployment. They will NOT be reachable via `npm run dev` alone.
#   - 401 / 403 / 500 responses mean the route EXISTS but requires an API key or has
#     a data error — these are EXPECTED in local dev without .env configured.
#   - 404 means the route is missing (build or routing error).
#   - Only 404 and connection-refused are treated as failures by default.
# =============================================================================

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
FRONTEND_URL="http://127.0.0.1:4173"
API_URL="http://127.0.0.1:3000"
SKIP_API=false
FAIL_ON_404=true

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass()  { echo -e "  ${GREEN}✓${RESET} $*"; }
fail()  { echo -e "  ${RED}✗${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}~${RESET} $*"; }
info()  { echo -e "  ${CYAN}→${RESET} $*"; }
header(){ echo -e "\n${BOLD}$*${RESET}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --frontend-url) FRONTEND_URL="$2"; shift 2;;
    --api-url)      API_URL="$2";      shift 2;;
    --skip-api)     SKIP_API=true;     shift;;
    --fail-on-404)  FAIL_ON_404=true;  shift;;
    -h|--help)
      sed -n '/^# Usage:/,/^# =====/p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
WARN=0
SKIP=0

# ── Helper: probe a single URL ────────────────────────────────────────────────
# Usage: probe_get <label> <url> [expected_pass_codes]
# expected_pass_codes: space-separated HTTP codes treated as PASS (default "200 301 302 307 308")
probe_get() {
  local label="$1"
  local url="$2"
  local pass_codes="${3:-200 301 302 307 308}"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" == "000" ]]; then
    fail "$label — CONNECTION REFUSED (server not running?)"
    ((FAIL++))
    return
  fi

  # Check if code is in pass_codes
  if echo "$pass_codes" | grep -qw "$http_code"; then
    pass "$label — HTTP $http_code"
    ((PASS++))
    return
  fi

  # 404 is always a hard failure
  if [[ "$http_code" == "404" ]]; then
    fail "$label — HTTP 404 (route missing!)"
    ((FAIL++))
    return
  fi

  # 401/403/500 etc. = route exists, API key missing or data error (expected)
  warn "$label — HTTP $http_code (route exists, likely missing API key)"
  ((WARN++))
}

# Usage: probe_post <label> <url> <json_body> [expected_pass_codes]
probe_post() {
  local label="$1"
  local url="$2"
  local body="$3"
  local pass_codes="${4:-200 201}"

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" == "000" ]]; then
    fail "$label — CONNECTION REFUSED (server not running?)"
    ((FAIL++))
    return
  fi

  if echo "$pass_codes" | grep -qw "$http_code"; then
    pass "$label — HTTP $http_code"
    ((PASS++))
    return
  fi

  if [[ "$http_code" == "404" ]]; then
    fail "$label — HTTP 404 (route missing!)"
    ((FAIL++))
    return
  fi

  warn "$label — HTTP $http_code (route exists, likely missing API key or auth)"
  ((WARN++))
}

# ── Usage: skip a route ───────────────────────────────────────────────────────
skip_route() {
  local label="$1"
  local reason="$2"
  info "$label — SKIPPED ($reason)"
  ((SKIP++))
}

# =============================================================================
# FRONTEND ROUTES  (Vite dev server — port 4173)
# =============================================================================
header "Frontend Routes  [ $FRONTEND_URL ]"

probe_get "GET /"                        "$FRONTEND_URL/"                       "200"
probe_get "GET /manifest.webmanifest"    "$FRONTEND_URL/manifest.webmanifest"   "200"
probe_get "GET /offline.html"            "$FRONTEND_URL/offline.html"           "200 404"   # may not exist in dev
probe_get "GET /sw.js"                   "$FRONTEND_URL/sw.js"                  "200 404"   # SW only in prod build
probe_get "GET /tests/map-harness.html"  "$FRONTEND_URL/tests/map-harness.html" "200"
probe_get "GET /tests/runtime-harness.html" "$FRONTEND_URL/tests/runtime-harness.html" "200"
probe_get "GET /tests/mobile-map-harness.html" "$FRONTEND_URL/tests/mobile-map-harness.html" "200"
probe_get "GET /tests/mobile-map-integration-harness.html" "$FRONTEND_URL/tests/mobile-map-integration-harness.html" "200"

# =============================================================================
# API ROUTES  (vercel dev — port 3000)
# Requires: vercel dev (or vercel build + serve)
# Expected: many will return 401/403/500 without API keys — that's OK
# Failure:  only 404 (route missing) counts as a hard failure
# =============================================================================
if [[ "$SKIP_API" == "true" ]]; then
  header "API Routes  [ SKIPPED (--skip-api flag set) ]"
  info "Run without --skip-api against 'vercel dev' to test API routes."
else
  header "API Routes  [ $API_URL ]"
  echo -e "  ${YELLOW}Note:${RESET} 401/403/500 = route exists but needs API key (expected in local dev)."
  echo -e "  ${RED}Only 404${RESET} = route missing (real failure).\n"

  # ── Static / simple GET endpoints ─────────────────────────────────────────
  probe_get  "GET  /api/version"            "$API_URL/api/version"            "200 401 403 500"
  probe_get  "GET  /api/bootstrap"          "$API_URL/api/bootstrap"          "200 401 403 500"
  probe_get  "GET  /api/seed-health"        "$API_URL/api/seed-health"        "200 401 403 500"
  probe_get  "GET  /api/geo"                "$API_URL/api/geo"                "200 401 403 500"
  probe_get  "GET  /api/gpsjam"             "$API_URL/api/gpsjam"             "200 401 403 500"
  probe_get  "GET  /api/opensky"            "$API_URL/api/opensky"            "200 401 403 500"
  probe_get  "GET  /api/oref-alerts"        "$API_URL/api/oref-alerts"        "200 401 403 500"
  probe_get  "GET  /api/polymarket"         "$API_URL/api/polymarket"         "200 401 403 500"
  probe_get  "GET  /api/rss-proxy"          "$API_URL/api/rss-proxy"          "200 400 401 403 500"
  probe_get  "GET  /api/ais-snapshot"       "$API_URL/api/ais-snapshot"       "200 401 403 500"
  probe_get  "GET  /api/telegram-feed"      "$API_URL/api/telegram-feed"      "200 401 403 500"
  probe_get  "GET  /api/download"           "$API_URL/api/download"           "200 302 400 401 403 500"
  probe_get  "GET  /api/og-story"           "$API_URL/api/og-story"           "200 400 401 403 500"
  probe_get  "GET  /api/story"              "$API_URL/api/story"              "200 400 401 403 500"
  probe_get  "GET  /api/fwdstart"           "$API_URL/api/fwdstart"           "200 401 403 500"
  probe_get  "GET  /api/register-interest"  "$API_URL/api/register-interest"  "200 400 401 403 405 500"
  probe_get  "GET  /api/data/city-coords"   "$API_URL/api/data/city-coords"   "200 401 403 500"
  probe_get  "GET  /api/enrichment/company" "$API_URL/api/enrichment/company" "200 400 401 403 500"
  probe_get  "GET  /api/enrichment/signals" "$API_URL/api/enrichment/signals" "200 400 401 403 500"
  probe_get  "GET  /api/youtube/embed"      "$API_URL/api/youtube/embed"      "200 400 401 403 500"
  probe_get  "GET  /api/youtube/live"       "$API_URL/api/youtube/live"       "200 400 401 403 500"
  probe_get  "GET  /api/eia"                "$API_URL/api/eia"                "200 400 401 403 500"

  # ── RPC domain gateways (POST with empty body — will get 400/415 if route exists) ─
  # Accept: 200, 400 (invalid body), 401 (auth), 403 (forbidden), 405 (method), 415 (content-type), 500
  RPC_ACCEPT="200 400 401 403 405 415 422 500"

  probe_post "POST /api/aviation/v1/rpc"         "$API_URL/api/aviation/v1/rpc"         "{}" "$RPC_ACCEPT"
  probe_post "POST /api/climate/v1/rpc"           "$API_URL/api/climate/v1/rpc"           "{}" "$RPC_ACCEPT"
  probe_post "POST /api/conflict/v1/rpc"          "$API_URL/api/conflict/v1/rpc"          "{}" "$RPC_ACCEPT"
  probe_post "POST /api/cyber/v1/rpc"             "$API_URL/api/cyber/v1/rpc"             "{}" "$RPC_ACCEPT"
  probe_post "POST /api/displacement/v1/rpc"      "$API_URL/api/displacement/v1/rpc"      "{}" "$RPC_ACCEPT"
  probe_post "POST /api/economic/v1/rpc"          "$API_URL/api/economic/v1/rpc"          "{}" "$RPC_ACCEPT"
  probe_post "POST /api/giving/v1/rpc"            "$API_URL/api/giving/v1/rpc"            "{}" "$RPC_ACCEPT"
  probe_post "POST /api/infrastructure/v1/rpc"    "$API_URL/api/infrastructure/v1/rpc"    "{}" "$RPC_ACCEPT"
  probe_post "POST /api/intelligence/v1/rpc"      "$API_URL/api/intelligence/v1/rpc"      "{}" "$RPC_ACCEPT"
  probe_post "POST /api/maritime/v1/rpc"          "$API_URL/api/maritime/v1/rpc"          "{}" "$RPC_ACCEPT"
  probe_post "POST /api/market/v1/rpc"            "$API_URL/api/market/v1/rpc"            "{}" "$RPC_ACCEPT"
  probe_post "POST /api/military/v1/rpc"          "$API_URL/api/military/v1/rpc"          "{}" "$RPC_ACCEPT"
  probe_post "POST /api/natural/v1/rpc"           "$API_URL/api/natural/v1/rpc"           "{}" "$RPC_ACCEPT"
  probe_post "POST /api/news/v1/rpc"              "$API_URL/api/news/v1/rpc"              "{}" "$RPC_ACCEPT"
  probe_post "POST /api/positive-events/v1/rpc"   "$API_URL/api/positive-events/v1/rpc"   "{}" "$RPC_ACCEPT"
  probe_post "POST /api/prediction/v1/rpc"        "$API_URL/api/prediction/v1/rpc"        "{}" "$RPC_ACCEPT"
  probe_post "POST /api/research/v1/rpc"          "$API_URL/api/research/v1/rpc"          "{}" "$RPC_ACCEPT"
  probe_post "POST /api/seismology/v1/rpc"        "$API_URL/api/seismology/v1/rpc"        "{}" "$RPC_ACCEPT"
  probe_post "POST /api/supply-chain/v1/rpc"      "$API_URL/api/supply-chain/v1/rpc"      "{}" "$RPC_ACCEPT"
  probe_post "POST /api/trade/v1/rpc"             "$API_URL/api/trade/v1/rpc"             "{}" "$RPC_ACCEPT"
  probe_post "POST /api/unrest/v1/rpc"            "$API_URL/api/unrest/v1/rpc"            "{}" "$RPC_ACCEPT"
  probe_post "POST /api/wildfire/v1/rpc"          "$API_URL/api/wildfire/v1/rpc"          "{}" "$RPC_ACCEPT"

  # ── Specific RPC methods: intelligence/deduct-situation ───────────────────
  probe_post "POST /api/intelligence/v1/deduct-situation" \
    "$API_URL/api/intelligence/v1/deduct-situation" \
    '{"query":"smoke test"}' \
    "$RPC_ACCEPT"

  # ── Generic [domain] gateway ──────────────────────────────────────────────
  probe_post "POST /api/[domain]/v1/rpc (generic)" \
    "$API_URL/api/test-domain/v1/rpc" \
    "{}" \
    "200 400 401 403 404 405 415 500"  # 404 acceptable here (unknown domain)
fi

# =============================================================================
# SUMMARY
# =============================================================================
TOTAL=$((PASS + FAIL + WARN + SKIP))

echo ""
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Endpoint Smoke Test Results${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "  Total checked : $TOTAL"
echo -e "  ${GREEN}Passed${RESET}        : $PASS"
echo -e "  ${YELLOW}Warned${RESET}        : $WARN  (route exists, API key missing)"
echo -e "  ${CYAN}Skipped${RESET}       : $SKIP"
echo -e "  ${RED}Failed${RESET}        : $FAIL  (404 / connection refused)"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}✗ SMOKE TEST FAILED — $FAIL route(s) returned 404 or connection refused.${RESET}"
  echo   "  Check that the dev server is running and routes are correctly defined."
  exit 1
else
  echo -e "${GREEN}${BOLD}✓ SMOKE TEST PASSED — all routes resolved (warned routes need API keys in Vercel).${RESET}"
  exit 0
fi
