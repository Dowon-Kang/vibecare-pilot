import { describe, expect, it } from 'vitest';
import { postgresPoolConfig, postgresSchemaName } from '../src/storage/postgres-config';

describe('PostgreSQL connection configuration', () => {
  it('uses the private vibecare schema by default', () => {
    expect(postgresSchemaName(undefined)).toBe('vibecare');
    expect(postgresPoolConfig({ connectionString: 'postgresql://localhost/test' }).options)
      .toBe('-c search_path=vibecare,public');
  });

  it('rejects schema values that could alter connection options', () => {
    expect(() => postgresSchemaName('vibecare -c role=postgres')).toThrow('DATABASE_SCHEMA');
    expect(() => postgresSchemaName('Public')).toThrow('DATABASE_SCHEMA');
  });

  it('keeps TLS certificate verification enabled unless explicitly disabled', () => {
    expect(postgresPoolConfig({
      connectionString: 'postgresql://example.test/postgres',
      sslRequired: true,
    }).ssl).toEqual({ rejectUnauthorized: true });
  });
});
