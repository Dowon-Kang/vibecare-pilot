import { describe, expect, it, vi } from 'vitest';
import type { Bindings, SqlStatement } from '../src/app-context';
import { createApp } from '../src/index';
import { configurationChecks } from '../src/runtime';

class ReadyStatement implements SqlStatement {
  bind(): SqlStatement {
    return this;
  }

  async first<T>(column?: string): Promise<T | null> {
    return (column === 'ok' ? 1 : { ok: 1 }) as T;
  }

  async all<T>(): Promise<{ results: T[] }> {
    return { results: [] };
  }

  async run(): Promise<unknown> {
    return { success: true };
  }
}

const environment = (overrides: Partial<Bindings> = {}): Bindings => ({
  DB: {
    prepare: () => new ReadyStatement(),
    batch: async () => [],
  },
  ENVIRONMENT: 'test',
  DEVICE_MODE: 'mock',
  REAL_DEVICE_ENABLED: 'false',
  FITRUS_API_BASE_URL: 'https://example.invalid',
  FITRUS_API_KEY: '',
  AUTH_TOKEN_SECRET: 'test-secret-at-least-32-characters',
  ALLOWED_ORIGINS: 'https://app.example.test',
  APP_VERSION: 'test-version',
  ...overrides,
});

describe('runtime boundary', () => {
  it('separates liveness from dependency readiness', async () => {
    const app = createApp();
    const health = await app.request('/health', undefined, environment());
    expect(health.status).toBe(200);
    expect(await health.json()).toMatchObject({ ok: true, version: 'test-version' });

    const ready = await app.request('/ready', undefined, environment());
    expect(ready.status).toBe(200);
    expect(await ready.json()).toMatchObject({
      ready: true,
      checks: { databaseQuery: true, safeDeviceMode: true },
    });
  });

  it('fails readiness closed when the database cannot be queried', async () => {
    const app = createApp();
    const env = environment({
      DB: {
        prepare: () => { throw new Error('unavailable'); },
        batch: async () => [],
      },
    });
    const response = await app.request('/ready', undefined, env);
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      ready: false,
      checks: { databaseQuery: false },
    });
  });

  it('propagates a safe request ID and only allows configured browser origins', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const app = createApp();
    const allowed = await app.request('/health', {
      headers: {
        Origin: 'https://app.example.test',
        'X-Request-Id': 'request-12345678',
      },
    }, environment());
    expect(allowed.headers.get('X-Request-Id')).toBe('request-12345678');
    expect(allowed.headers.get('Access-Control-Allow-Origin')).toBe('https://app.example.test');

    const denied = await app.request('/health', {
      headers: { Origin: 'https://untrusted.example.test' },
    }, environment());
    expect(denied.headers.get('Access-Control-Allow-Origin')).toBeNull();
    vi.restoreAllMocks();
  });

  it('requires production secrets, HTTPS provider URL, CORS and mock device mode', () => {
    expect(configurationChecks(environment({
      ENVIRONMENT: 'production',
      AUTH_TOKEN_SECRET: 'short',
      FITRUS_API_BASE_URL: 'http://provider.invalid',
      FITRUS_API_KEY: '',
      ALLOWED_ORIGINS: '',
      DEVICE_MODE: 'real',
      REAL_DEVICE_ENABLED: 'true',
    }))).toMatchObject({
      authSecret: false,
      fitrusBaseUrl: false,
      fitrusApiKey: false,
      corsConfigured: false,
      safeDeviceMode: false,
    });
  });

  it('rejects unknown environment names instead of falling back to development rules', () => {
    expect(configurationChecks(environment({
      ENVIRONMENT: 'prod',
      FITRUS_API_BASE_URL: 'http://provider.invalid',
    }))).toMatchObject({ environment: false });

    expect(configurationChecks(environment({ ENVIRONMENT: 'staging' })))
      .toMatchObject({ environment: true });
  });
});
