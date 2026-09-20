import type { PoolConfig } from 'pg';

const SCHEMA_NAME_PATTERN = /^[a-z_][a-z0-9_]*$/;

export function postgresSchemaName(value = process.env.DATABASE_SCHEMA): string {
  const schema = value?.trim() || 'vibecare';
  if (!SCHEMA_NAME_PATTERN.test(schema)) {
    throw new Error('DATABASE_SCHEMA must be a lowercase PostgreSQL identifier');
  }
  return schema;
}

export function postgresPoolConfig(options: {
  connectionString: string;
  schema?: string;
  sslRequired?: boolean;
  rejectUnauthorized?: boolean;
  max?: number;
}): PoolConfig {
  const schema = postgresSchemaName(options.schema);
  return {
    connectionString: options.connectionString,
    options: `-c search_path=${schema},public`,
    ssl: options.sslRequired
      ? { rejectUnauthorized: options.rejectUnauthorized !== false }
      : undefined,
    max: options.max ?? 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  };
}
