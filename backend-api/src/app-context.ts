import type { Context } from 'hono';
import type { Hono } from 'hono';

/**
 * Minimal SQL port used by the application layer.
 *
 * D1 satisfies this interface today. An AWS adapter must provide the same
 * parameterized prepare/bind/first/all/run/batch semantics without exposing a
 * vendor client to routes.
 */
export interface SqlStatement {
  bind(...values: unknown[]): SqlStatement;
  first<T = Record<string, unknown>>(column?: string): Promise<T | null>;
  all<T = Record<string, unknown>>(): Promise<{ results: T[] }>;
  run(): Promise<unknown>;
}

export interface SqlDatabase {
  prepare(sql: string): SqlStatement;
  batch(statements: SqlStatement[]): Promise<unknown[]>;
}

export type Bindings = {
  DB: SqlDatabase;
  ENVIRONMENT: string;
  ALLOWED_ORIGINS?: string;
  DEVICE_MODE?: string;
  REAL_DEVICE_ENABLED?: string;
  FITRUS_API_BASE_URL: string;
  FITRUS_API_KEY: string;
  AUTH_TOKEN_SECRET: string;
  APP_VERSION?: string;
};

export type AppEnvironment = {
  Bindings: Bindings;
  Variables: {
    requestId: string;
    requestStartedAt: number;
  };
};
export type AppContext = Context<AppEnvironment>;
export type VibeCareApp = Hono<AppEnvironment>;
