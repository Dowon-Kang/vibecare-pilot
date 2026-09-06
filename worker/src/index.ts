import { Hono, type Context } from 'hono';
import { z } from 'zod';
import { issueToken, verifyPin, verifyToken } from './auth';
import {
  calculateRecommendation,
  defaultRuleSet,
  type AlgorithmRuleSet,
  type CanonicalMeasurement,
} from './algorithm';
import { FitrusClient, type FitrusMeasurementKind } from './fitrus-client';

type Bindings = {
  DB: D1Database;
  ENVIRONMENT: string;
  DEVICE_MODE?: string;
  REAL_DEVICE_ENABLED?: string;
  FITRUS_API_BASE_URL: string;
  FITRUS_API_KEY: string;
  AUTH_TOKEN_SECRET: string;
};

type AppContext = Context<{ Bindings: Bindings }>;
const app = new Hono<{ Bindings: Bindings }>();

const pinSchema = z.object({ participantCode: z.string().min(1), pin: z.string().regex(/^\d{6}$/) });
const refreshSchema = z.object({ refreshToken: z.string().min(20) });
const safetySchema = z.object({
  acutePain: z.boolean(),
  dizziness: z.boolean(),
  clinicianHold: z.boolean(),
});
const authorizeSchema = z.object({
  measurementIds: z.array(z.string().min(1)).length(4),
  safety: safetySchema,
  deviceId: z.string().min(1),
  algorithmVersion: z.string().min(1),
});
const fitrusKindSchema = z.enum([
  'bodyFat', 'bloodPressure', 'heartRate', 'stress', 'stressV2', 'bodyTemperature',
]);
const fitrusProxySchema = z.object({
  deviceId: z.string().min(1),
  measuredAt: z.iso.datetime().optional(),
  payload: z.record(z.string(), z.unknown()),
});
const sessionSchema = z.object({ authorizationId: z.string().min(1), deviceId: z.string().min(1) });
const eventSchema = z.object({
  eventType: z.enum(['ACK', 'RUNNING', 'STOPPING', 'COMPLETED', 'ERROR', 'DISCONNECTED']),
  payload: z.record(z.string(), z.unknown()).default({}),
});
const feedbackSchema = z.object({
  sessionId: z.string().min(1),
  rpe: z.number().int().min(0).max(10).nullable().optional(),
  pain: z.number().int().min(0).max(10).nullable().optional(),
  dizziness: z.boolean(),
  discomfort: z.string().max(500).nullable().optional(),
});

const jsonBody = async (c: AppContext) => c.req.json().catch(() => null);

async function accessParticipantId(c: AppContext): Promise<string | null> {
  const authorization = c.req.header('Authorization');
  if (!authorization?.startsWith('Bearer ') || (c.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32) return null;
  const claims = await verifyToken(c.env.AUTH_TOKEN_SECRET, authorization.slice(7), 'access');
  return claims?.sub ?? null;
}

async function loadRuleSet(c: AppContext): Promise<AlgorithmRuleSet> {
  const row = await c.env.DB.prepare(
    `SELECT rules_json FROM algorithm_rule_sets
      WHERE enabled = 1 AND active_from <= ?
      ORDER BY active_from DESC LIMIT 1`,
  ).bind(new Date().toISOString()).first<{ rules_json: string }>();
  if (!row) return defaultRuleSet;
  return JSON.parse(row.rules_json) as AlgorithmRuleSet;
}

const bodyValues = (row: Record<string, unknown>) => ({
  weightKg: Number(row.weight_kg),
  bmi: Number(row.bmi),
  bodyFatPct: Number(row.body_fat_pct),
  fatMassKg: Number(row.fat_mass_kg),
  skeletalMuscleMassKg: Number(row.skeletal_muscle_mass_kg),
  basalMetabolicRateKcal: row.basal_metabolic_rate_kcal == null ? null : Number(row.basal_metabolic_rate_kcal),
  bodyWaterPct: row.body_water_pct == null ? null : Number(row.body_water_pct),
  proteinKg: row.protein_kg == null ? null : Number(row.protein_kg),
  mineralKg: row.mineral_kg == null ? null : Number(row.mineral_kg),
  ecwRatio: row.ecw_ratio == null ? null : Number(row.ecw_ratio),
  waistCm: row.waist_cm == null ? null : Number(row.waist_cm),
  visceralFatLevel: row.visceral_fat_level == null ? null : Number(row.visceral_fat_level),
});

const canonicalMeasurement = (row: Record<string, unknown>): CanonicalMeasurement => ({
  id: String(row.id),
  participantId: String(row.participant_id),
  deviceId: String(row.device_id),
  qualityPassed: Number(row.quality_passed) === 1,
  weightKg: Number(row.weight_kg),
  bmi: Number(row.bmi),
  bodyFatPct: Number(row.body_fat_pct),
  fatMassKg: Number(row.fat_mass_kg),
  skeletalMuscleMassKg: Number(row.skeletal_muscle_mass_kg),
});

app.get('/health', (c) => c.json({ ok: true, service: 'vibecare-api', deviceMode: c.env.DEVICE_MODE ?? 'mock' }));

app.post('/v1/auth/pin', async (c) => {
  const parsed = pinSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  if ((c.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32) return c.json({ error: 'AUTH_NOT_CONFIGURED' }, 503);
  const row = await c.env.DB.prepare(
    `SELECT p.id, p.participant_code, p.age, p.sex, p.height_cm,
            pc.salt, pc.pin_hash, pc.failed_attempts, pc.locked_until, pc.refresh_version
       FROM participants p JOIN pin_credentials pc ON pc.participant_id = p.id
      WHERE p.participant_code = ?`,
  ).bind(parsed.data.participantCode.trim().toUpperCase()).first<Record<string, unknown>>();
  if (!row) return c.json({ error: 'INVALID_CREDENTIALS' }, 401);
  if (row.locked_until && Date.parse(String(row.locked_until)) > Date.now()) {
    return c.json({ error: 'ACCOUNT_LOCKED', lockedUntil: row.locked_until }, 423);
  }
  const valid = await verifyPin(parsed.data.pin, String(row.salt), String(row.pin_hash));
  if (!valid) {
    const failures = Number(row.failed_attempts) + 1;
    const lockedUntil = failures >= 5 ? new Date(Date.now() + 15 * 60_000).toISOString() : null;
    await c.env.DB.prepare(
      'UPDATE pin_credentials SET failed_attempts = ?, locked_until = ? WHERE participant_id = ?',
    ).bind(failures >= 5 ? 0 : failures, lockedUntil, row.id).run();
    return c.json({ error: lockedUntil ? 'ACCOUNT_LOCKED' : 'INVALID_CREDENTIALS', lockedUntil }, lockedUntil ? 423 : 401);
  }
  await c.env.DB.prepare(
    'UPDATE pin_credentials SET failed_attempts = 0, locked_until = NULL WHERE participant_id = ?',
  ).bind(row.id).run();
  const refreshVersion = Number(row.refresh_version);
  const [accessToken, refreshToken] = await Promise.all([
    issueToken(c.env.AUTH_TOKEN_SECRET, String(row.id), 'access', refreshVersion),
    issueToken(c.env.AUTH_TOKEN_SECRET, String(row.id), 'refresh', refreshVersion),
  ]);
  return c.json({
    participant: {
      id: row.id,
      code: row.participant_code,
      age: row.age,
      sex: row.sex,
      heightCm: row.height_cm,
    },
    accessToken,
    refreshToken,
    expiresInSec: 900,
  });
});

app.post('/v1/auth/refresh', async (c) => {
  const parsed = refreshSchema.safeParse(await jsonBody(c));
  if (!parsed.success || (c.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32) return c.json({ error: 'INVALID_REQUEST' }, 400);
  const claims = await verifyToken(c.env.AUTH_TOKEN_SECRET, parsed.data.refreshToken, 'refresh');
  if (!claims) return c.json({ error: 'INVALID_REFRESH_TOKEN' }, 401);
  const row = await c.env.DB.prepare(
    'SELECT refresh_version FROM pin_credentials WHERE participant_id = ?',
  ).bind(claims.sub).first<{ refresh_version: number }>();
  if (!row || Number(row.refresh_version) !== claims.refreshVersion) {
    return c.json({ error: 'REFRESH_TOKEN_REVOKED' }, 401);
  }
  return c.json({
    accessToken: await issueToken(c.env.AUTH_TOKEN_SECRET, claims.sub, 'access', claims.refreshVersion),
    expiresInSec: 900,
  });
});

app.get('/v1/algorithm-rules/current', async (c) => {
  if (!await accessParticipantId(c)) return c.json({ error: 'UNAUTHORIZED' }, 401);
  return c.json(await loadRuleSet(c));
});

app.post('/v1/fitrus/measurements/:kind', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const kind = fitrusKindSchema.safeParse(c.req.param('kind'));
  const body = fitrusProxySchema.safeParse(await jsonBody(c));
  if (!kind.success || !body.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  if (!c.env.FITRUS_API_KEY) return c.json({ error: 'FITRUS_NOT_CONFIGURED' }, 503);
  const requestId = crypto.randomUUID();
  const response = await new FitrusClient(
    c.env.FITRUS_API_KEY,
    c.env.FITRUS_API_BASE_URL,
  ).measure(kind.data as FitrusMeasurementKind, body.data.payload, { requestId });
  const rawId = crypto.randomUUID();
  await c.env.DB.prepare(
    `INSERT INTO fitrus_raw_measurements
      (id, participant_id, kind, source_device_id, request_id, response_json, measured_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).bind(
    rawId,
    participantId,
    kind.data,
    body.data.deviceId,
    requestId,
    JSON.stringify(response),
    body.data.measuredAt ?? new Date().toISOString(),
  ).run();
  return c.json({ requestId, rawMeasurementId: rawId, normalized: false, providerResponse: response }, 201);
});

app.get('/v1/participants/me/measurement-set/current', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const deviceId = c.req.query('deviceId') ?? await c.env.DB.prepare(
    'SELECT device_id FROM bia_measurements WHERE participant_id = ? ORDER BY measured_at DESC LIMIT 1',
  ).bind(participantId).first<string>('device_id');
  if (!deviceId) return c.json({ history: [], selectedMeasurementIds: [], syncedAt: new Date().toISOString() });
  const rows = await c.env.DB.prepare(
    `SELECT * FROM bia_measurements
      WHERE participant_id = ? AND device_id = ?
      ORDER BY measured_at DESC LIMIT 20`,
  ).bind(participantId, deviceId).all<Record<string, unknown>>();
  const seen = new Set<string>();
  const selected = rows.results.filter((row) => {
    const id = String(row.id);
    const core = canonicalMeasurement(row);
    if (seen.has(id) || !core.qualityPassed) return false;
    seen.add(id);
    return [core.weightKg, core.bmi, core.bodyFatPct, core.fatMassKg, core.skeletalMuscleMassKg]
      .every((value) => Number.isFinite(value) && value > 0);
  }).slice(0, 4);
  return c.json({
    history: rows.results.map((row) => ({
      id: row.id,
      participantId: row.participant_id,
      deviceId: row.device_id,
      measuredAt: row.measured_at,
      qualityPassed: Number(row.quality_passed) === 1,
      values: bodyValues(row),
    })),
    selectedMeasurementIds: selected.map((row) => String(row.id)),
    syncedAt: new Date().toISOString(),
  });
});

app.get('/v1/participants/me/vitals', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const rows = await c.env.DB.prepare(
    `SELECT id, kind, measured_at, values_json, units_json
       FROM vital_measurements WHERE participant_id = ?
       ORDER BY measured_at DESC LIMIT 50`,
  ).bind(participantId).all<Record<string, unknown>>();
  return c.json({ items: rows.results.map((row) => ({
    id: row.id,
    kind: row.kind,
    measuredAt: row.measured_at,
    values: JSON.parse(String(row.values_json)),
    units: JSON.parse(String(row.units_json)),
  })) });
});

app.post('/v1/recommendations/authorize', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const parsed = authorizeSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({ error: 'INVALID_REQUEST', details: parsed.error.issues }, 400);
  const participant = await c.env.DB.prepare(
    'SELECT id, age, sex, height_cm FROM participants WHERE id = ?',
  ).bind(participantId).first<Record<string, unknown>>();
  if (!participant) return c.json({ error: 'PARTICIPANT_NOT_FOUND' }, 404);
  const placeholders = parsed.data.measurementIds.map(() => '?').join(',');
  const rows = await c.env.DB.prepare(
    `SELECT * FROM bia_measurements WHERE id IN (${placeholders})`,
  ).bind(...parsed.data.measurementIds).all<Record<string, unknown>>();
  const currentRows = await c.env.DB.prepare(
    `SELECT id FROM bia_measurements
      WHERE participant_id = ? AND device_id = ? AND quality_passed = 1
        AND weight_kg > 0 AND bmi > 0 AND body_fat_pct > 0
        AND fat_mass_kg > 0 AND skeletal_muscle_mass_kg > 0
      ORDER BY measured_at DESC LIMIT 4`,
  ).bind(participantId, parsed.data.deviceId).all<{ id: string }>();
  const requestedIds = new Set(parsed.data.measurementIds);
  if (currentRows.results.length !== 4 || currentRows.results.some((row) => !requestedIds.has(String(row.id)))) {
    return c.json({
      error: 'MEASUREMENT_SET_STALE',
      currentMeasurementIds: currentRows.results.map((row) => String(row.id)),
    }, 409);
  }
  const ruleSet = await loadRuleSet(c);
  if (parsed.data.algorithmVersion !== ruleSet.version) {
    return c.json({ error: 'ALGORITHM_VERSION_MISMATCH', currentRuleSet: ruleSet }, 409);
  }
  const result = calculateRecommendation({
    profile: {
      participantId,
      age: Number(participant.age),
      sex: String(participant.sex) as 'female' | 'male',
      heightCm: Number(participant.height_cm),
    },
    measurements: rows.results.map(canonicalMeasurement),
    safety: parsed.data.safety,
    ruleSet,
  });
  const measurementSetId = crypto.randomUUID();
  const recommendationId = crypto.randomUUID();
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO measurement_sets
        (id, participant_id, device_id, measurement_ids_json, average_json, algorithm_version)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).bind(
      measurementSetId,
      participantId,
      parsed.data.deviceId,
      JSON.stringify(parsed.data.measurementIds),
      JSON.stringify(result.average),
      result.algorithmVersion,
    ),
    c.env.DB.prepare(
      `INSERT INTO recommendations
        (id, participant_id, measurement_set_id, algorithm_version, status, result_json)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).bind(
      recommendationId,
      participantId,
      measurementSetId,
      result.algorithmVersion,
      result.status,
      JSON.stringify(result),
    ),
  ]);
  if (result.status !== 'READY') return c.json({ authorized: false, recommendationId, result }, 409);
  const authorizationId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 60_000).toISOString();
  await c.env.DB.prepare(
    `INSERT INTO execution_authorizations
      (id, participant_id, device_id, algorithm_version, recommendation_json, expires_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).bind(authorizationId, participantId, parsed.data.deviceId, result.algorithmVersion, JSON.stringify(result), expiresAt).run();
  return c.json({ authorized: true, authorizationId, recommendationId, expiresAt, result }, 201);
});

app.post('/v1/device-sessions', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const idempotencyKey = c.req.header('Idempotency-Key');
  if (!idempotencyKey || idempotencyKey.length < 16) return c.json({ error: 'IDEMPOTENCY_KEY_REQUIRED' }, 400);
  const parsed = sessionSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  const existing = await c.env.DB.prepare(
    'SELECT id, status, command_json FROM device_sessions WHERE idempotency_key = ?',
  ).bind(idempotencyKey).first<Record<string, unknown>>();
  if (existing) return c.json({ sessionId: existing.id, status: existing.status, command: JSON.parse(String(existing.command_json)) });
  const authorization = await c.env.DB.prepare(
    `SELECT * FROM execution_authorizations
      WHERE id = ? AND participant_id = ? AND device_id = ?`,
  ).bind(parsed.data.authorizationId, participantId, parsed.data.deviceId).first<Record<string, unknown>>();
  if (!authorization) return c.json({ error: 'AUTHORIZATION_NOT_FOUND' }, 404);
  if (authorization.used_at) return c.json({ error: 'AUTHORIZATION_ALREADY_USED' }, 409);
  if (Date.parse(String(authorization.expires_at)) <= Date.now()) return c.json({ error: 'AUTHORIZATION_EXPIRED' }, 409);
  const mode = c.env.DEVICE_MODE ?? (c.env.REAL_DEVICE_ENABLED === 'true' ? 'real' : 'mock');
  if (mode === 'real') return c.json({ error: 'DEVICE_PROTOCOL_NOT_CONFIGURED' }, 501);
  const recommendation = JSON.parse(String(authorization.recommendation_json)) as {
    recommendation: { durationSec: number; frequencyHz: number; intensityPct: number };
    algorithmVersion: string;
  };
  const sessionId = crypto.randomUUID();
  const now = new Date().toISOString();
  const command = {
    authorizationId: parsed.data.authorizationId,
    participantId,
    deviceId: parsed.data.deviceId,
    ...recommendation.recommendation,
    algorithmVersion: recommendation.algorithmVersion,
    issuedAt: now,
    expiresAt: authorization.expires_at,
    idempotencyKey,
  };
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE execution_authorizations SET used_at = ? WHERE id = ? AND used_at IS NULL').bind(now, authorization.id),
    c.env.DB.prepare(
      `INSERT INTO device_sessions
        (id, authorization_id, idempotency_key, status, started_at, command_json)
       VALUES (?, ?, ?, 'RUNNING', ?, ?)`,
    ).bind(sessionId, authorization.id, idempotencyKey, now, JSON.stringify(command)),
    c.env.DB.prepare(
      `INSERT INTO command_events (id, session_id, event_type, payload_json)
       VALUES (?, ?, 'ACK', ?)`,
    ).bind(crypto.randomUUID(), sessionId, JSON.stringify({ mode: 'mock', acknowledgedAt: now })),
  ]);
  return c.json({ sessionId, status: 'RUNNING', mode: 'mock', command }, 201);
});

app.post('/v1/device-sessions/:id/events', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const parsed = eventSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  const session = await ownedSession(c, c.req.param('id'), participantId);
  if (!session) return c.json({ error: 'SESSION_NOT_FOUND' }, 404);
  await c.env.DB.prepare(
    'INSERT INTO command_events (id, session_id, event_type, payload_json) VALUES (?, ?, ?, ?)',
  ).bind(crypto.randomUUID(), session.id, parsed.data.eventType, JSON.stringify(parsed.data.payload)).run();
  return c.json({ accepted: true }, 202);
});

app.post('/v1/device-sessions/:id/stop', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const session = await ownedSession(c, c.req.param('id'), participantId);
  if (!session) return c.json({ error: 'SESSION_NOT_FOUND' }, 404);
  const body = z.object({ reason: z.string().min(1).max(100) }).safeParse(await jsonBody(c));
  if (!body.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  const now = new Date().toISOString();
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE device_sessions SET status = 'STOPPED', stopped_at = ?, stop_reason = ? WHERE id = ?`,
    ).bind(now, body.data.reason, session.id),
    c.env.DB.prepare(
      `INSERT INTO command_events (id, session_id, event_type, payload_json) VALUES (?, ?, 'STOPPING', ?)`,
    ).bind(crypto.randomUUID(), session.id, JSON.stringify({ reason: body.data.reason, at: now })),
  ]);
  return c.json({ sessionId: session.id, status: 'STOPPED', stoppedAt: now });
});

app.post('/v1/session-feedback', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const parsed = feedbackSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  const session = await ownedSession(c, parsed.data.sessionId, participantId);
  if (!session) return c.json({ error: 'SESSION_NOT_FOUND' }, 404);
  await c.env.DB.prepare(
    `INSERT INTO session_feedback (session_id, rpe, pain, dizziness, discomfort)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(session_id) DO UPDATE SET
       rpe = excluded.rpe, pain = excluded.pain, dizziness = excluded.dizziness,
       discomfort = excluded.discomfort`,
  ).bind(
    session.id,
    parsed.data.rpe ?? null,
    parsed.data.pain ?? null,
    parsed.data.dizziness ? 1 : 0,
    parsed.data.discomfort ?? null,
  ).run();
  return c.json({ saved: true });
});

async function ownedSession(c: AppContext, sessionId: string, participantId: string) {
  return c.env.DB.prepare(
    `SELECT ds.id, ds.status FROM device_sessions ds
      JOIN execution_authorizations ea ON ea.id = ds.authorization_id
      WHERE ds.id = ? AND ea.participant_id = ?`,
  ).bind(sessionId, participantId).first<Record<string, unknown>>();
}

app.onError((error, c) => {
  console.error('request_failed', { name: error.name, message: error.message });
  return c.json({ error: 'INTERNAL_ERROR' }, 500);
});

export default app;
