import { describe, expect, it, vi } from 'vitest';
import type { Bindings, SqlStatement } from '../src/app-context';
import { bindingsFromEnvironment, createVercelApp } from '../server';

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

function readyBindings(): Bindings {
  return {
    DB: {
      prepare: () => new ReadyStatement(),
      batch: async () => [],
    },
    ENVIRONMENT: 'production',
    ALLOWED_ORIGINS: 'https://app.example.test',
    DEVICE_MODE: 'mock',
    REAL_DEVICE_ENABLED: 'false',
    FITRUS_API_BASE_URL: 'https://api.example.test',
    FITRUS_API_KEY: 'test-provider-key',
    AUTH_TOKEN_SECRET: 'test-secret-that-is-longer-than-32-characters',
    APP_VERSION: 'vercel-test',
  };
}

describe('Vercel Hono entrypoint', () => {
  it('forwards the original route to the existing Hono application', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const app = createVercelApp(readyBindings);

    const health = await app.request('/health');
    expect(health.status).toBe(200);
    expect(await health.json()).toMatchObject({
      ok: true,
      service: 'vibecare-api',
      version: 'vercel-test',
    });

    const ready = await app.request('/ready');
    expect(ready.status).toBe(200);
    expect(await ready.json()).toMatchObject({ ready: true });
    vi.restoreAllMocks();
  });

  it('keeps liveness available while readiness fails closed without secrets or DB', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const bindings = bindingsFromEnvironment({});
    const app = createVercelApp(() => bindings);

    expect((await app.request('/health')).status).toBe(200);
    const response = await app.request('/ready');
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      ready: false,
      checks: {
        authSecret: false,
        fitrusApiKey: false,
        corsConfigured: false,
        databaseQuery: false,
        safeDeviceMode: true,
      },
    });
    vi.restoreAllMocks();
  });
});
