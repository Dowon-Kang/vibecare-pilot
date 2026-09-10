import { cors } from 'hono/cors';
import type { MiddlewareHandler } from 'hono';
import type { AppContext, AppEnvironment, Bindings } from './app-context';

const requestIdPattern = /^[A-Za-z0-9._:-]{8,128}$/;

export function requestId(context: AppContext): string {
  return context.get('requestId');
}

export function runtimeMiddleware(): MiddlewareHandler<AppEnvironment> {
  return async (context, next) => {
    const supplied = context.req.header('X-Request-Id');
    const correlationId = supplied && requestIdPattern.test(supplied)
      ? supplied
      : crypto.randomUUID();
    const startedAt = Date.now();
    context.set('requestId', correlationId);
    context.set('requestStartedAt', startedAt);
    context.header('X-Request-Id', correlationId);
    context.header('X-Content-Type-Options', 'nosniff');
    context.header('Referrer-Policy', 'no-referrer');
    context.header('Cache-Control', 'no-store');

    try {
      await next();
    } finally {
      console.log(JSON.stringify({
        event: 'http_request',
        requestId: correlationId,
        method: context.req.method,
        path: new URL(context.req.url).pathname,
        status: context.res.status,
        durationMs: Date.now() - startedAt,
        environment: context.env.ENVIRONMENT || 'unknown',
      }));
    }
  };
}

export function corsMiddleware(): MiddlewareHandler<AppEnvironment> {
  return cors({
    origin: (origin, context) => {
      if (!origin) return undefined;
      const allowed = (context.env.ALLOWED_ORIGINS ?? '')
        .split(',')
        .map((value: string) => value.trim())
        .filter(Boolean);
      return allowed.includes(origin) ? origin : undefined;
    },
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    allowHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'X-Request-Id'],
    exposeHeaders: ['X-Request-Id'],
    maxAge: 600,
  });
}

export function configurationChecks(env: Bindings): Record<string, boolean> {
  const allowedEnvironments = new Set(['development', 'test', 'staging', 'production']);
  const environment = env.ENVIRONMENT?.trim().toLowerCase();
  const hardenedEnvironment = environment === 'staging' || environment === 'production';
  return {
    environment: allowedEnvironments.has(environment),
    database: Boolean(env.DB),
    authSecret: (env.AUTH_TOKEN_SECRET?.length ?? 0) >= 32,
    fitrusBaseUrl: isHttpsUrl(env.FITRUS_API_BASE_URL, !hardenedEnvironment),
    fitrusApiKey: !hardenedEnvironment || Boolean(env.FITRUS_API_KEY),
    safeDeviceMode:
      (env.DEVICE_MODE ?? 'mock') === 'mock' && env.REAL_DEVICE_ENABLED !== 'true',
    corsConfigured: !hardenedEnvironment || Boolean(env.ALLOWED_ORIGINS?.trim()),
  };
}

export async function readiness(env: Bindings): Promise<{
  ready: boolean;
  checks: Record<string, boolean>;
}> {
  const checks = configurationChecks(env);
  try {
    checks.databaseQuery = Number(await env.DB.prepare('SELECT 1 AS ok').first<number>('ok')) === 1;
  } catch {
    checks.databaseQuery = false;
  }
  return { ready: Object.values(checks).every(Boolean), checks };
}

function isHttpsUrl(value: string | undefined, allowHttp: boolean): boolean {
  try {
    const url = new URL(value ?? '');
    return url.protocol === 'https:' || (allowHttp && url.protocol === 'http:');
  } catch {
    return false;
  }
}
