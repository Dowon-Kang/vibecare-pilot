import assert from 'node:assert/strict';
import { execFile, spawn, type ChildProcess } from 'node:child_process';
import { createHmac, randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { after, before, test } from 'node:test';
import { promisify } from 'node:util';
import { Pool } from 'pg';
import { hashPin } from '../src/auth.js';
import { PostgresDatabase } from '../src/storage/postgres-database.js';
import { postgresPoolConfig } from '../src/storage/postgres-config.js';

// This suite deliberately refuses managed/production databases and never uses FITRUS.
const connectionString = process.env.POSTGRES_TEST_URL;
assert.ok(connectionString, 'POSTGRES_TEST_URL is required; use a disposable local vibecare_test database');
const databaseUrl = new URL(connectionString);
assert.ok(['postgres:', 'postgresql:'].includes(databaseUrl.protocol));
assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(databaseUrl.hostname), 'Only loopback PostgreSQL is allowed');
assert.equal(databaseUrl.pathname, '/vibecare_test', 'The database must be named vibecare_test');

const secret = 'synthetic-http-integration-secret-only';
const pool = new Pool(postgresPoolConfig({ connectionString, schema: 'vibecare' }));
const database = new PostgresDatabase(pool);
const run = promisify(execFile);
let server: ChildProcess | undefined;
let baseUrl = '';
let serverLogs = '';
let tokenA = '';
let tokenB = '';
let sessionId = '';
const deviceId = `SIM-${randomUUID()}`;
const idempotencyKey = randomUUID();
const authorizePayload = {
  measurementIds: ['DEV-BIA-001', 'DEV-BIA-002', 'DEV-BIA-003', 'DEV-BIA-004'],
  sourceDeviceId: 'FITRUS-DEVELOPMENT', deviceId, algorithmVersion: 'pilot-0.9.1',
  bodyPart: 'wholeBody', safety: { acutePain: false, dizziness: false, clinicianHold: false },
};

async function request(path: string, token?: string, body?: unknown, key?: string): Promise<Response> {
  return fetch(baseUrl + path, {
    method: body === undefined ? 'GET' : 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(key ? { 'Idempotency-Key': key } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(5_000),
  });
}

async function json(response: Response, status: number): Promise<Record<string, unknown>> {
  const body = await response.json() as Record<string, unknown>;
  assert.equal(response.status, status, JSON.stringify(body));
  return body;
}

before(async () => {
  const environment = {
    ...process.env, DATABASE_URL: connectionString, DATABASE_SCHEMA: 'vibecare',
    DATABASE_SSL: '', ENVIRONMENT: 'development', ALLOW_DEVELOPMENT_SEED: 'true',
    AUTH_TOKEN_SECRET: secret, DEVICE_MODE: 'mock', REAL_DEVICE_ENABLED: 'false',
    FITRUS_API_KEY: '', FITRUS_API_BASE_URL: 'https://example.invalid',
    ALLOWED_ORIGINS: 'http://localhost:3000', PORT: '0', APP_VERSION: 'handoff-integration',
  };
  for (const script of ['src/storage/migrate-postgres.ts', 'src/storage/seed-development.ts']) {
    await run(process.execPath, ['--import', 'tsx', script], { env: environment, timeout: 30_000 });
  }
  const salt = 'c3ludGhldGljLXNhbHQ';
  await pool.query(`INSERT INTO participants(id, participant_code, age, sex, height_cm)
    VALUES ('participant-integration-002', 'USER-002', 72, 'female', 150)
    ON CONFLICT (id) DO NOTHING`);
  await pool.query(`INSERT INTO pin_credentials(participant_id, salt, pin_hash)
    VALUES ('participant-integration-002', $1, $2)
    ON CONFLICT (participant_id) DO UPDATE SET failed_attempts=0, locked_until=NULL`,
  [salt, await hashPin('123456', salt)]);

  server = spawn(process.execPath, ['--import', 'tsx', 'src/node-server.ts'], {
    env: environment, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const child = server;
  await new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(`Node server startup timed out: ${serverLogs}`)), 15_000);
    let pending = '';
    child.stderr?.on('data', (chunk: Buffer) => { serverLogs = (serverLogs + chunk.toString()).slice(-4_000); });
    child.stdout?.on('data', (chunk: Buffer) => {
      pending += chunk.toString();
      const lines = pending.split(/\r?\n/);
      pending = lines.pop() ?? '';
      for (const line of lines) {
        serverLogs = (serverLogs + line + '\n').slice(-4_000);
        try {
          const event = JSON.parse(line) as { event?: string; port?: number };
          if (event.event === 'server_started' && event.port) {
            baseUrl = `http://127.0.0.1:${event.port}`;
            clearTimeout(timeout);
            resolve();
          }
        } catch { /* Non-JSON diagnostics remain available on failure. */ }
      }
    });
    child.once('error', (error) => { clearTimeout(timeout); reject(error); });
    child.once('exit', (code) => {
      clearTimeout(timeout);
      if (!baseUrl) reject(new Error(`Node server exited (${code}): ${serverLogs}`));
    });
  });
  const loginA = await json(await request('/v1/auth/pin', undefined, { participantCode: 'USER-001', pin: '123456' }), 200);
  const loginB = await json(await request('/v1/auth/pin', undefined, { participantCode: 'USER-002', pin: '123456' }), 200);
  tokenA = String(loginA.accessToken);
  tokenB = String(loginB.accessToken);
}, { timeout: 75_000 });

after(async () => {
  if (server && server.exitCode === null && server.signalCode === null) {
    const exited = once(server, 'exit');
    const timeout = setTimeout(() => server?.kill('SIGKILL'), 5_000);
    server.kill('SIGTERM');
    try { await exited; } finally { clearTimeout(timeout); }
  }
  await database.close();
});

test('real Node HTTP server reports health, PostgreSQL readiness and the migrated rule', async () => {
  assert.equal((await json(await request('/health'), 200)).version, 'handoff-integration');
  assert.equal((await json(await request('/ready'), 200)).ready, true);
  assert.equal((await json(await request('/v1/algorithm-rules/current', tokenA), 200)).version, 'pilot-0.9.1');
});

test('measurement -> authorization -> Mock start/retry -> stop -> feedback persists in PostgreSQL', async () => {
  const history = await json(await request('/v1/participants/me/measurement-set/current', tokenA), 200);
  assert.equal((history.history as unknown[]).length, 4);
  assert.deepEqual(new Set(history.selectedMeasurementIds as string[]), new Set(authorizePayload.measurementIds));
  const permit = await json(await request('/v1/recommendations/authorize', tokenA, authorizePayload), 201);
  assert.equal(permit.mode, 'mock');
  assert.equal((permit.result as Record<string, unknown>).physicalExecution, 'PROHIBITED');
  const start = { authorizationId: permit.authorizationId, deviceId };
  const started = await json(await request('/v1/device-sessions', tokenA, start, idempotencyKey), 201);
  sessionId = String(started.sessionId);
  assert.equal((started.command as Record<string, unknown>).executionMode, 'SIMULATOR_ONLY');
  assert.equal((await json(await request('/v1/device-sessions', tokenA, start, idempotencyKey), 200)).sessionId, sessionId);
  assert.equal((await json(await request(`/v1/device-sessions/${sessionId}/stop`, tokenA, { reason: 'completed' }), 200)).status, 'COMPLETED');
  const feedback = { sessionId, rpe: 2, pain: 0, dizziness: false };
  assert.equal((await json(await request('/v1/session-feedback', tokenA, feedback), 200)).saved, true);
  assert.equal((await json(await request('/v1/session-feedback', tokenA, feedback), 200)).saved, true);
  assert.equal((await json(await request('/v1/session-feedback', tokenA, { ...feedback, pain: 1 }), 409)).error, 'FEEDBACK_ALREADY_SAVED');
  const stored = await pool.query(`SELECT ds.status, sf.rpe, sf.pain FROM device_sessions ds
    JOIN session_feedback sf ON sf.session_id = ds.id WHERE ds.id=$1`, [sessionId]);
  assert.deepEqual(stored.rows[0], { status: 'COMPLETED', rpe: 2, pain: 0 });
});

test('a second PIN account cannot read measurements or change the first account session', async () => {
  const history = await json(await request('/v1/participants/me/measurement-set/current', tokenB), 200);
  assert.deepEqual(history.history, []);
  assert.equal((await json(await request('/v1/recommendations/authorize', tokenB, authorizePayload), 409)).error, 'MEASUREMENT_SET_STALE');
  assert.equal((await json(await request(`/v1/device-sessions/${sessionId}/stop`, tokenB, { reason: 'completed' }), 404)).error, 'SESSION_NOT_FOUND');
  assert.equal((await json(await request('/v1/session-feedback', tokenB, { sessionId, rpe: 2, pain: 0, dizziness: false }), 404)).error, 'SESSION_NOT_FOUND');
});

test('expired/tampered access tokens and expired Mock authorizations are rejected over HTTP', async () => {
  const payload = Buffer.from(JSON.stringify({ sub: 'participant-development-001', kind: 'access', exp: 1, refreshVersion: 0 })).toString('base64url');
  const expired = `${payload}.${createHmac('sha256', secret).update(payload).digest('base64url')}`;
  await json(await request('/v1/participants/me/measurement-set/current', expired), 401);
  await json(await request('/v1/participants/me/measurement-set/current', `${tokenA}x`), 401);
  const permit = await json(await request('/v1/recommendations/authorize', tokenA, authorizePayload), 201);
  await pool.query('UPDATE execution_authorizations SET expires_at=$1 WHERE id=$2', [new Date(0).toISOString(), permit.authorizationId]);
  assert.equal((await json(await request('/v1/device-sessions', tokenA, { authorizationId: permit.authorizationId, deviceId }, randomUUID()), 409)).error, 'AUTHORIZATION_EXPIRED');
});

test('concurrent incorrect PINs lock once without losing increments or extending the lock', async () => {
  const responses = await Promise.all(Array.from({ length: 8 }, () => request('/v1/auth/pin', undefined, { participantCode: 'USER-002', pin: '000000' })));
  assert.ok(responses.some((response) => response.status === 423));
  assert.ok(responses.every((response) => [401, 423].includes(response.status)));
  const result = await pool.query("SELECT failed_attempts, locked_until FROM pin_credentials WHERE participant_id='participant-integration-002'");
  assert.equal(result.rows[0].failed_attempts, 0);
  assert.ok(Date.parse(result.rows[0].locked_until) > Date.now());
  const locked = await json(await request('/v1/auth/pin', undefined, { participantCode: 'USER-002', pin: '123456' }), 423);
  assert.equal(locked.lockedUntil, result.rows[0].locked_until);
});

test('a failed PostgreSQL batch rolls back earlier writes', async () => {
  const id = `rollback-${randomUUID()}`;
  await assert.rejects(database.batch([
    database.prepare("INSERT INTO participants(id, participant_code, age, sex, height_cm) VALUES (?, ?, 72, 'female', 150)").bind(id, id),
    database.prepare('INSERT INTO pin_credentials(participant_id, salt, pin_hash) VALUES (?, ?, ?)').bind('missing-integration-participant', 'synthetic', 'synthetic'),
  ]));
  assert.equal(await database.prepare('SELECT COUNT(*) AS count FROM participants WHERE id=?').bind(id).first('count'), '0');
});
