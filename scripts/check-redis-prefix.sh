#!/usr/bin/env bash
# =============================================================================
# check-redis-prefix.sh — Redis prefix enforcement guard
# =============================================================================
# Checks that no server handler file bypasses the Redis wrapper in
# server/_shared/redis.ts. All Redis access must go through the exported
# wrapper functions: getCachedJson / setCachedJson / cachedFetchJson /
# cachedFetchJsonWithMeta / getCachedJsonBatch / geoSearchByBox /
# getHashFieldsBatch.
#
# Exit codes:
#   0 — no violations found
#   1 — one or more violations detected (with descriptive output)
#
# This script is wired into CI in Story 1.2.
# =============================================================================

set -euo pipefail

violations=0

echo "🔍 Checking Redis prefix enforcement..."

# ── Check 1: Direct Upstash env var access outside redis.ts ──────────────────
# Any handler or shared file (other than redis.ts itself) that reads
# UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN is bypassing the wrapper.
if grep -rn 'UPSTASH_REDIS_REST_URL\|UPSTASH_REDIS_REST_TOKEN' \
    server/worldmonitor/ \
    server/cors.ts \
    server/error-mapper.ts \
    server/router.ts \
    2>/dev/null; then
  echo ""
  echo "❌ Direct Redis env var access found outside server/_shared/redis.ts"
  echo "   All Redis operations must use the wrapper functions from redis.ts."
  violations=$((violations + 1))
fi

# ── Check 2: Direct fetch calls to Redis / Upstash URLs outside redis.ts ──────
# A fetch() call referencing 'redis' or 'upstash' in a handler is a bypass.
if grep -rn 'fetch.*redis\|fetch.*upstash' \
    server/worldmonitor/ \
    2>/dev/null; then
  echo ""
  echo "❌ Direct fetch to Redis/Upstash found outside server/_shared/redis.ts"
  echo "   Use getCachedJson / setCachedJson / cachedFetchJson etc. instead."
  violations=$((violations + 1))
fi

# ── Result ────────────────────────────────────────────────────────────────────
echo ""
if [ "$violations" -eq 0 ]; then
  echo "✅ Redis prefix enforcement: all access routes through server/_shared/redis.ts"
  exit 0
else
  echo "❌ Found $violations Redis access violation(s) — see output above"
  exit 1
fi
