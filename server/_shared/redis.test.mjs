/**
 * Unit tests for Redis key prefix logic.
 *
 * Tests getKeyPrefix() directly to avoid the module-level cachedPrefix
 * memoization issue in prefixKey(). The prefix derivation logic is what
 * matters — the caching is an optimization detail.
 *
 * Run: npx tsx --test server/_shared/redis.test.mjs
 */

import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';

describe('redis key prefix', () => {
  let savedVercelEnv;

  beforeEach(() => {
    savedVercelEnv = process.env.VERCEL_ENV;
  });

  afterEach(() => {
    if (savedVercelEnv === undefined) {
      delete process.env.VERCEL_ENV;
    } else {
      process.env.VERCEL_ENV = savedVercelEnv;
    }
  });

  it('uses prod: prefix when VERCEL_ENV is production', async () => {
    process.env.VERCEL_ENV = 'production';
    // Import fresh module — getKeyPrefix() is not memoized, reads env each call
    const { getKeyPrefix } = await import('./redis.ts');
    assert.equal(getKeyPrefix(), 'prod:');
  });

  it('uses prod: prefix when VERCEL_ENV is missing', async () => {
    delete process.env.VERCEL_ENV;
    const { getKeyPrefix } = await import('./redis.ts');
    assert.equal(getKeyPrefix(), 'prod:');
  });

  it('uses qa: prefix when VERCEL_ENV is preview', async () => {
    process.env.VERCEL_ENV = 'preview';
    const { getKeyPrefix } = await import('./redis.ts');
    assert.equal(getKeyPrefix(), 'qa:');
  });

  it('uses qa: prefix when VERCEL_ENV is development', async () => {
    process.env.VERCEL_ENV = 'development';
    const { getKeyPrefix } = await import('./redis.ts');
    assert.equal(getKeyPrefix(), 'qa:');
  });

  it('prod: prefix applied to a key produces correct result', async () => {
    process.env.VERCEL_ENV = 'production';
    const { getKeyPrefix } = await import('./redis.ts');
    const prefix = getKeyPrefix();
    assert.equal(`${prefix}summaries:US`, 'prod:summaries:US');
  });

  it('qa: prefix applied to a key produces correct result', async () => {
    process.env.VERCEL_ENV = 'preview';
    const { getKeyPrefix } = await import('./redis.ts');
    const prefix = getKeyPrefix();
    assert.equal(`${prefix}summaries:US`, 'qa:summaries:US');
  });
});
