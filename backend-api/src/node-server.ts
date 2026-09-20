import { serve } from '@hono/node-server';
import type { Bindings } from './app-context.js';
import { createApp } from './index.js';
import { PostgresDatabase } from './storage/postgres-database.js';
import { postgresPoolConfig } from './storage/postgres-config.js';

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const database = PostgresDatabase.fromConfig(postgresPoolConfig({
  connectionString: required('DATABASE_URL'),
  schema: process.env.DATABASE_SCHEMA,
  sslRequired: process.env.DATABASE_SSL === 'require',
  rejectUnauthorized: process.env.DATABASE_SSL_REJECT_UNAUTHORIZED !== 'false',
  max: Number(process.env.DATABASE_POOL_MAX ?? 10),
}));
const bindings: Bindings = {
  DB: database,
  ENVIRONMENT: process.env.ENVIRONMENT ?? 'development',
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS,
  DEVICE_MODE: process.env.DEVICE_MODE ?? 'mock',
  REAL_DEVICE_ENABLED: process.env.REAL_DEVICE_ENABLED ?? 'false',
  FITRUS_API_BASE_URL: process.env.FITRUS_API_BASE_URL ?? 'https://api.thefitrus.com/fitrus-ml/measure',
  FITRUS_API_KEY: process.env.FITRUS_API_KEY ?? '',
  AUTH_TOKEN_SECRET: required('AUTH_TOKEN_SECRET'),
  APP_VERSION: process.env.APP_VERSION ?? 'development-postgres',
};
const app = createApp();
const port = Number(process.env.PORT ?? 8787);
const schemaReady = await database.prepare(
  'SELECT version FROM schema_migrations WHERE version = ?',
).bind('001_schema').first<string>('version');
if (schemaReady !== '001_schema') {
  await database.close();
  throw new Error('PostgreSQL schema is not migrated to 001_schema');
}
const server = serve({ port, fetch: (request) => app.fetch(request, bindings) }, (info) => {
  console.log(JSON.stringify({ event: 'server_started', port: info.port }));
});

let closing = false;
async function shutdown(signal: string): Promise<void> {
  if (closing) return;
  closing = true;
  console.log(JSON.stringify({ event: 'server_stopping', signal }));
  server.close(async () => {
    await database.close();
    process.exit(0);
  });
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
