import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { Pool } from 'pg';

const connectionString = process.env.POSTGRES_TEST_URL;
assert.ok(connectionString, 'POSTGRES_TEST_URL is required');
const url = new URL(connectionString);
assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname), 'Only disposable loopback PostgreSQL is allowed');
assert.equal(url.pathname, '/vibecare_test');

test('daily guide RPC enforces own measurements, bounded history, invalid-latest and ambiguous-link rules', async () => {
  const pool = new Pool({ connectionString });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`
      do $$ begin
        if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
        if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
      end $$;
      create schema if not exists auth;
      create table auth.users(id uuid primary key,is_anonymous boolean not null default false);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated,anon;
      create table public.visit_bookings(id text primary key,participant_id text not null);
    `);
    await client.query(await readFile(new URL('../../deployment/supabase/002_auth_participation.sql', import.meta.url), 'utf8'));
    await client.query(await readFile(new URL('../supabase/migrations/20261017063007_daily_guide_context.sql', import.meta.url), 'utf8'));
    await client.query(await readFile(new URL('./daily-guide-rls.sql', import.meta.url), 'utf8'));
    await client.query(await readFile(new URL('../supabase/migrations/20261017090311_external_measurement_intake.sql', import.meta.url), 'utf8'));
    await client.query(await readFile(new URL('./external-measurement-intake.sql', import.meta.url), 'utf8'));
  } finally {
    await client.query('ROLLBACK');
    client.release();
    await pool.end();
  }
});
