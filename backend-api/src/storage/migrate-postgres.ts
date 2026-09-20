import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';
import { postgresPoolConfig } from './postgres-config.js';

const connectionString = process.env.DATABASE_URL?.trim();
if (!connectionString) throw new Error('DATABASE_URL is required');
const schemaPath = fileURLToPath(new URL('../../../deployment/local/postgres/001_schema.sql', import.meta.url));
const pool = new Pool(postgresPoolConfig({
  connectionString,
  schema: process.env.DATABASE_SCHEMA,
  sslRequired: process.env.DATABASE_SSL === 'require',
  rejectUnauthorized: process.env.DATABASE_SSL_REJECT_UNAUTHORIZED !== 'false',
  max: 1,
}));
try {
  await pool.query(await readFile(schemaPath, 'utf8'));
  console.log(JSON.stringify({ event: 'postgres_migration_complete', migration: '001_schema.sql' }));
} finally {
  await pool.end();
}
