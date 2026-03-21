// ========================================================================
// Constants
// ========================================================================

export const UPSTREAM_TIMEOUT_MS = 10_000;

// Temporal baseline constants
export const BASELINE_TTL = 7776000; // 90 days in seconds
export const MIN_SAMPLES = 10;
export const Z_THRESHOLD_LOW = 1.5;
export const Z_THRESHOLD_MEDIUM = 2.0;
export const Z_THRESHOLD_HIGH = 3.0;

export const VALID_BASELINE_TYPES = [
  'military_flights', 'vessels', 'protests', 'news', 'ais_gaps', 'satellite_fires',
];

// ========================================================================
// Temporal baseline helpers
// ========================================================================

export interface BaselineEntry {
  mean: number;
  m2: number;
  sampleCount: number;
  lastUpdated: string;
}

export function makeBaselineKey(type: string, region: string, weekday: number, month: number): string {
  return `baseline:${type}:${region}:${weekday}:${month}`;
}

export function getBaselineSeverity(zScore: number): string {
  if (zScore >= Z_THRESHOLD_HIGH) return 'critical';
  if (zScore >= Z_THRESHOLD_MEDIUM) return 'high';
  if (zScore >= Z_THRESHOLD_LOW) return 'medium';
  return 'normal';
}

// ========================================================================
// Batch JSON read helper — delegates to shared Redis wrapper
// getCachedJson / setCachedJson / getCachedJsonBatch are in ../../../_shared/redis.ts
// All Redis access MUST route through that wrapper for prefix enforcement.
// ========================================================================

import { getCachedJsonBatch } from '../../../_shared/redis';

/**
 * Batch-reads JSON values for the given keys.
 * Returns an ordered array (one entry per input key, null for missing/failed).
 * Keys are prefixed automatically by the shared Redis wrapper (prod: / qa:).
 */
export async function mgetJson(keys: string[]): Promise<(unknown | null)[]> {
  if (keys.length === 0) return [];
  const map = await getCachedJsonBatch(keys);
  return keys.map(k => map.get(k) ?? null);
}
