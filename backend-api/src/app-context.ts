import type { Context } from 'hono';
import type { Hono } from 'hono';

export type Bindings = {
  DB: D1Database;
  ENVIRONMENT: string;
  DEVICE_MODE?: string;
  REAL_DEVICE_ENABLED?: string;
  FITRUS_API_BASE_URL: string;
  FITRUS_API_KEY: string;
  AUTH_TOKEN_SECRET: string;
};

export type AppEnvironment = { Bindings: Bindings };
export type AppContext = Context<AppEnvironment>;
export type VibeCareApp = Hono<AppEnvironment>;
