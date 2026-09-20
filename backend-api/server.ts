import { Hono } from 'hono';
import type { Bindings, SqlDatabase, SqlStatement } from './src/app-context.js';
import { createApp } from './src/index.js';
import { PostgresDatabase } from './src/storage/postgres-database.js';
import { postgresPoolConfig } from './src/storage/postgres-config.js';

type Environment = Record<string, string | undefined>;

class UnavailableStatement implements SqlStatement {
  bind(): SqlStatement {
    return this;
  }

  async first<T>(): Promise<T | null> {
    throw new Error('DATABASE_URL is not configured');
  }

  async all<T>(): Promise<{ results: T[] }> {
    throw new Error('DATABASE_URL is not configured');
  }

  async run(): Promise<unknown> {
    throw new Error('DATABASE_URL is not configured');
  }
}

const unavailableDatabase: SqlDatabase = {
  prepare: () => new UnavailableStatement(),
  batch: async () => { throw new Error('DATABASE_URL is not configured'); },
};

let postgresDatabase: PostgresDatabase | undefined;

function databaseFromEnvironment(environment: Environment): SqlDatabase {
  const connectionString = environment.DATABASE_URL?.trim();
  if (!connectionString) return unavailableDatabase;

  postgresDatabase ??= PostgresDatabase.fromConfig(postgresPoolConfig({
    connectionString,
    schema: environment.DATABASE_SCHEMA,
    sslRequired: environment.DATABASE_SSL === 'require',
    rejectUnauthorized: environment.DATABASE_SSL_REJECT_UNAUTHORIZED !== 'false',
    max: Number(environment.DATABASE_POOL_MAX ?? 1),
  }));
  return postgresDatabase;
}

export function bindingsFromEnvironment(
  environment: Environment = process.env,
): Bindings {
  return {
    DB: databaseFromEnvironment(environment),
    ENVIRONMENT: environment.ENVIRONMENT ?? 'production',
    ALLOWED_ORIGINS: environment.ALLOWED_ORIGINS,
    DEVICE_MODE: environment.DEVICE_MODE ?? 'mock',
    REAL_DEVICE_ENABLED: environment.REAL_DEVICE_ENABLED ?? 'false',
    FITRUS_API_BASE_URL:
      environment.FITRUS_API_BASE_URL ?? 'https://api.thefitrus.com/fitrus-ml/measure',
    FITRUS_API_KEY: environment.FITRUS_API_KEY ?? '',
    AUTH_TOKEN_SECRET: environment.AUTH_TOKEN_SECRET ?? '',
    APP_VERSION: environment.APP_VERSION ?? 'vercel',
  };
}

export function createVercelApp(
  bindingFactory: () => Bindings = () => bindingsFromEnvironment(),
): Hono {
  const entrypoint = new Hono();
  const application = createApp();

  entrypoint.all('*', (context) => application.fetch(context.req.raw, bindingFactory()));
  return entrypoint;
}

export default createVercelApp();
