import { describe, expect, it } from 'vitest';
import { assertDevelopmentSeedAllowed } from '../src/storage/development-seed-policy';

describe('development seed policy', () => {
  it('allows only explicit development seeding against a loopback database', () => {
    expect(() => assertDevelopmentSeedAllowed({
      environment: 'development',
      allowSeed: 'true',
      databaseUrl: 'postgresql://user:password@127.0.0.1:5432/vibecare',
    })).not.toThrow();
    expect(() => assertDevelopmentSeedAllowed({
      environment: 'development',
      allowSeed: 'false',
      databaseUrl: 'postgresql://user:password@127.0.0.1:5432/vibecare',
    })).toThrow('ALLOW_DEVELOPMENT_SEED');
    expect(() => assertDevelopmentSeedAllowed({
      environment: 'production',
      allowSeed: 'true',
      databaseUrl: 'postgresql://user:password@127.0.0.1:5432/vibecare',
    })).toThrow('development');
    expect(() => assertDevelopmentSeedAllowed({
      environment: 'development',
      allowSeed: 'true',
      databaseUrl: 'postgresql://user:password@db.example.com:5432/vibecare',
    })).toThrow('loopback');
  });
});
