import { feedbackAdjustment } from './feedback';
import { Hono, type Context } from 'hono';
import { z } from 'zod';
import { issueToken, verifyPin, verifyToken } from './auth';
import {
  applyRequestedIntensity,
  calculateRecommendation,
  type AlgorithmRuleSet,
  type CanonicalMeasurement,
} from './algorithm';
import { FitrusClient, type FitrusMeasurementKind } from './fitrus-client';
import { ruleSchema } from './rule-schema';

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
  measurementIds: z.array(z.string().min(1)).length(4).refine((ids) => new Set(ids).size === 4),
  safety: safetySchema,
  deviceId: z.string().min(1),
  sourceDeviceId: z.string().min(1).optional(),
  algorithmVersion: z.string().min(1),
  requestedIntensityPct: z.number().int().min(1).max(100).optional(),
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
  rpe: z.number().int().min(0).max(10),
  pain: z.number().int().min(0).max(10),
  dizziness: z.boolean(),
  intensityRating: z.enum(['weak', 'suitable', 'strong']).optional(),
  durationRating: z.enum(['weak', 'suitable', 'strong']).optional(),
  frequencyRating: z.enum(['weak', 'suitable', 'strong']).optional(),
  discomfort: z.string().max(500).nullable().optional(),
  earlyStopped:z.boolean().optional(),
  actualDurationSec:z.number().nonnegative().nullable().optional(),
  measuredPeakG:z.number().nonnegative().nullable().optional(),
  measuredRmsG:z.number().nonnegative().nullable().optional(),
});

const jsonBody = async (c: AppContext) => c.req.json().catch(() => null);

async function accessParticipantId(c: AppContext): Promise<string | null> {
  const authorization = c.req.header('Authorization');
  if (!authorization?.startsWith('Bearer ') || (c.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32) return null;
  const claims = await verifyToken(c.env.AUTH_TOKEN_SECRET, authorization.slice(7), 'access');
  return claims?.sub ?? null;
}

async function loadRuleSet(c: AppContext): Promise<AlgorithmRuleSet | null> {
  const row = await c.env.DB.prepare(
    `SELECT version, rules_json FROM algorithm_rule_sets
      WHERE enabled = 1 AND active_from <= ?
      ORDER BY active_from DESC LIMIT 1`,
  ).bind(new Date().toISOString()).first<{ version: string; rules_json: string }>();
  if (!row) return null;
  try {
    const parsed = ruleSchema.safeParse(JSON.parse(row.rules_json));
    return parsed.success && parsed.data.version === row.version &&
      Date.parse(parsed.data.activeFrom) <= Date.now() ? parsed.data : null;
  } catch { return null; }
}

// Keep the displayed selection and the authorization selection identical.
const latestValidSql = `SELECT * FROM bia_measurements
  WHERE participant_id = ? AND device_id = ? AND quality_passed = 1
    AND weight_kg > 0 AND weight_kg < 1e308 AND bmi > 0 AND bmi < 1e308
    AND body_fat_pct > 0 AND body_fat_pct <= 100
    AND fat_mass_kg > 0 AND fat_mass_kg <= weight_kg
    AND skeletal_muscle_mass_kg > 0 AND skeletal_muscle_mass_kg <= weight_kg
  ORDER BY measured_at DESC, id DESC LIMIT 4`;

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
  if (typeof row.locked_until === 'string' && Date.parse(row.locked_until) > Date.now()) {
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
  const rules = await loadRuleSet(c);
  return rules ? c.json(rules) : c.json({ error: 'ALGORITHM_UNAVAILABLE' }, 503);
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
      ORDER BY measured_at DESC, id DESC LIMIT 20`,
  ).bind(participantId, deviceId).all<Record<string, unknown>>();
  const selected = (await c.env.DB.prepare(latestValidSql).bind(participantId, deviceId)
    .all<Record<string, unknown>>()).results;
  const history = [...new Map([...rows.results, ...selected].map((row) => [String(row.id), row])).values()];
  return c.json({
    history: history.map((row) => ({
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
    participantId,
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
  const sourceDeviceId = parsed.data.sourceDeviceId ?? parsed.data.deviceId;
  const currentRows = await c.env.DB.prepare(latestValidSql)
    .bind(participantId, sourceDeviceId).all<{ id: string }>();
  const requestedIds = new Set(parsed.data.measurementIds);
  if (currentRows.results.length !== 4 || currentRows.results.some((row) => !requestedIds.has(String(row.id)))) {
    return c.json({
      error: 'MEASUREMENT_SET_STALE',
      currentMeasurementIds: currentRows.results.map((row) => String(row.id)),
    }, 409);
  }
  const ruleSet = await loadRuleSet(c);
  if (!ruleSet) return c.json({ error: 'ALGORITHM_UNAVAILABLE' }, 503);
  if (parsed.data.algorithmVersion !== ruleSet.version) {
    return c.json({ error: 'ALGORITHM_VERSION_MISMATCH', currentRuleSet: ruleSet }, 409);
  }
  let result = calculateRecommendation({
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
  const adjustment = await readFeedbackAdjustment(c, participantId);
  if (adjustment && result.recommendation) {
    if (adjustment.requiresReview || adjustment.intensityCap < ruleSet.output.minimumPct) {
      result = {...result, status:'BLOCKED', executionStatus:'BLOCKED', reasonCodes:[...result.reasonCodes,'FEEDBACK_HOLD'], recommendation:null, warnings:[...result.warnings, adjustment.reason]};
    } else {
      result = {...result, recommendation:{...result.recommendation, intensityPct:Math.min(result.recommendation.intensityPct, adjustment.intensityCap)}};
    }
  }
  try {
    result = applyRequestedIntensity(result, parsed.data.requestedIntensityPct, ruleSet);
  } catch (error) {
    if (!(error instanceof RangeError)) throw error;
    return c.json({
      error: 'INTENSITY_OUTSIDE_SAFE_RANGE',
      minimumPct: ruleSet.output.minimumPct,
      maximumPct: result.recommendation?.intensityPct ?? null,
    }, 409);
  }
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
      sourceDeviceId,
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
  const mode = c.env.DEVICE_MODE ?? (c.env.REAL_DEVICE_ENABLED === 'true' ? 'real' : 'mock');
  if (mode !== 'mock') return c.json({authorized:false, error:'CALIBRATION_REQUIRED', recommendationId, result},409);
  const authorizationId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 60_000).toISOString();
  await c.env.DB.prepare(
    `INSERT INTO execution_authorizations
      (id, participant_id, device_id, algorithm_version, recommendation_json, expires_at)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).bind(authorizationId, participantId, parsed.data.deviceId, result.algorithmVersion, JSON.stringify(result), expiresAt).run();
  return c.json({ authorized: true, mode:'mock', authorizationId, recommendationId, expiresAt, result }, 201);
});

app.post('/v1/device-sessions', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const idempotencyKey = c.req.header('Idempotency-Key');
  if (!idempotencyKey || idempotencyKey.length < 16) return c.json({ error: 'IDEMPOTENCY_KEY_REQUIRED' }, 400);
  const parsed = sessionSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  const existing = await c.env.DB.prepare(
    `SELECT ds.id, ds.status, ds.command_json, ds.authorization_id, ea.participant_id, ea.device_id
       FROM device_sessions ds JOIN execution_authorizations ea ON ea.id = ds.authorization_id
       WHERE ds.idempotency_key = ?`,
  ).bind(idempotencyKey).first<Record<string, unknown>>();
  if (existing) {
    if (existing.participant_id !== participantId || existing.authorization_id !== parsed.data.authorizationId ||
        existing.device_id !== parsed.data.deviceId) return c.json({ error: 'IDEMPOTENCY_CONFLICT' }, 409);
    return c.json({ sessionId: existing.id, status: existing.status, command: JSON.parse(String(existing.command_json)) });
  }
  const authorization = await c.env.DB.prepare(
    `SELECT * FROM execution_authorizations
      WHERE id = ? AND participant_id = ? AND device_id = ?`,
  ).bind(parsed.data.authorizationId, participantId, parsed.data.deviceId).first<Record<string, unknown>>();
  if (!authorization) return c.json({ error: 'AUTHORIZATION_NOT_FOUND' }, 404);
  if (authorization.used_at) return c.json({ error: 'AUTHORIZATION_ALREADY_USED' }, 409);
  if (Date.parse(String(authorization.expires_at)) <= Date.now()) return c.json({ error: 'AUTHORIZATION_EXPIRED' }, 409);
  const mode = c.env.DEVICE_MODE ?? (c.env.REAL_DEVICE_ENABLED === 'true' ? 'real' : 'mock');
  if (mode !== 'mock') return c.json({ error: 'DEVICE_PROTOCOL_NOT_CONFIGURED' }, 501);
  const rules = await loadRuleSet(c);
  if (!rules) return c.json({ error: 'ALGORITHM_UNAVAILABLE' }, 503);
  if (rules.version !== authorization.algorithm_version) return c.json({ error: 'ALGORITHM_VERSION_MISMATCH' }, 409);
  const recommendation = JSON.parse(String(authorization.recommendation_json)) as {
    recommendation: { durationSec: number; frequencyHz: number; intensityPct: number };
    algorithmVersion: string;
  };
  const adjustment = await readFeedbackAdjustment(c, participantId);
  if (adjustment && (adjustment.requiresReview || recommendation.recommendation.intensityPct > adjustment.intensityCap)) {
    return c.json({error:'FEEDBACK_ADJUSTMENT_CHANGED'},409);
  }
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
  if (['STOPPED', 'COMPLETED'].includes(String(session.status))) return c.json({ error: 'SESSION_TERMINAL' }, 409);
  const now = new Date().toISOString();
  await c.env.DB.batch([
    c.env.DB.prepare('INSERT INTO command_events (id, session_id, event_type, payload_json) VALUES (?, ?, ?, ?)')
      .bind(crypto.randomUUID(), session.id, parsed.data.eventType, JSON.stringify(parsed.data.payload)),
    c.env.DB.prepare(`UPDATE device_sessions SET status = CASE WHEN ? = 'COMPLETED' THEN 'COMPLETED' ELSE status END,
      completed_at = CASE WHEN ? = 'COMPLETED' THEN ? ELSE completed_at END WHERE id = ?`)
      .bind(parsed.data.eventType, parsed.data.eventType, now, session.id),
  ]);
  return c.json({ accepted: true }, 202);
});

app.post('/v1/device-sessions/:id/stop', async (c) => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({ error: 'UNAUTHORIZED' }, 401);
  const session = await ownedSession(c, c.req.param('id'), participantId);
  if (!session) return c.json({ error: 'SESSION_NOT_FOUND' }, 404);
  const body = z.object({ reason: z.string().min(1).max(100) }).safeParse(await jsonBody(c));
  if (!body.success) return c.json({ error: 'INVALID_REQUEST' }, 400);
  if (['STOPPED', 'COMPLETED'].includes(String(session.status))) {
    return c.json({ sessionId: session.id, status: session.status, stoppedAt: session.stopped_at ?? session.completed_at });
  }
  const now = new Date().toISOString();
  const status = body.data.reason === 'completed' ? 'COMPLETED' : 'STOPPED';
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE device_sessions SET status = ?, stopped_at = ?, stop_reason = ?, completed_at = ? WHERE id = ?`,
    ).bind(status, now, body.data.reason, status === 'COMPLETED' ? now : null, session.id),
    c.env.DB.prepare(
      `INSERT INTO command_events (id, session_id, event_type, payload_json) VALUES (?, ?, 'STOPPING', ?)`,
    ).bind(crypto.randomUUID(), session.id, JSON.stringify({ reason: body.data.reason, at: now })),
  ]);
  return c.json({ sessionId: session.id, status, stoppedAt: now });
});

async function readFeedbackAdjustment(c: AppContext, participantId: string) {
  const row = await c.env.DB.prepare('SELECT * FROM feedback_adjustments WHERE participant_id = ?').bind(participantId).first<Record<string,unknown>>();
  return row ? {intensityCap:Number(row.intensity_cap), requiresReview:Number(row.requires_review) === 1,
    reason:String(row.reason), reasonCode:String(row.reason_code), policyVersion:String(row.policy_version), sourceSessionId:String(row.source_session_id)} : null;
}
app.get('/v1/feedback-adjustment', async c => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({error:'UNAUTHORIZED'},401);
  return c.json({adjustment:await readFeedbackAdjustment(c,participantId)});
});
app.post('/v1/session-feedback', async c => {
  const participantId = await accessParticipantId(c);
  if (!participantId) return c.json({error:'UNAUTHORIZED'},401);
  const parsed = feedbackSchema.safeParse(await jsonBody(c));
  if (!parsed.success) return c.json({error:'INVALID_REQUEST'},400);
  const session = await ownedSession(c,parsed.data.sessionId,participantId);
  if (!session) return c.json({error:'SESSION_NOT_FOUND'},404);
  if (!['STOPPED','COMPLETED'].includes(String(session.status))) return c.json({error:'SESSION_NOT_FINISHED'},409);
  const existing = await c.env.DB.prepare('SELECT * FROM session_feedback WHERE session_id=?').bind(session.id).first<Record<string,unknown>>();
  const earlyStopped = session.status === 'STOPPED' || parsed.data.earlyStopped === true;
  const execution = {earlyStopped, actualDurationSec:parsed.data.actualDurationSec ?? null,
    measuredPeakG:parsed.data.measuredPeakG ?? null, measuredRmsG:parsed.data.measuredRmsG ?? null, source:'participant_report'};
  if (existing) {
    if (existing.execution_json && existing.execution_json !== JSON.stringify(execution)) return c.json({error:'FEEDBACK_ALREADY_SAVED'},409);
    if (existing.rpe !== parsed.data.rpe || existing.pain !== parsed.data.pain || Number(existing.dizziness) !== Number(parsed.data.dizziness) ||
      (existing.intensity_rating ?? null) !== (parsed.data.intensityRating ?? null) ||
      (existing.duration_rating ?? null) !== (parsed.data.durationRating ?? null) ||
      (existing.frequency_rating ?? null) !== (parsed.data.frequencyRating ?? null) ||
      (existing.discomfort ?? null) !== (parsed.data.discomfort ?? null)) return c.json({error:'FEEDBACK_ALREADY_SAVED'},409);
    return c.json({saved:true,adjustment:await readFeedbackAdjustment(c,participantId)});
  }
  const commandRow = await c.env.DB.prepare('SELECT command_json FROM device_sessions WHERE id=?').bind(session.id).first<{command_json:string}>();
  const command = JSON.parse(commandRow!.command_json) as {intensityPct:number};
  const previous = await readFeedbackAdjustment(c,participantId);
  const adjustment = feedbackAdjustment({...parsed.data,earlyStopped},command.intensityPct,previous?.intensityCap,previous?.requiresReview);
  await c.env.DB.batch([
    c.env.DB.prepare(`INSERT INTO session_feedback(
      session_id,rpe,pain,dizziness,intensity_rating,duration_rating,frequency_rating,discomfort,execution_json
    ) VALUES(?,?,?,?,?,?,?,?,?)`).bind(
      session.id,parsed.data.rpe,parsed.data.pain,Number(parsed.data.dizziness),
      parsed.data.intensityRating ?? null,parsed.data.durationRating ?? null,
      parsed.data.frequencyRating ?? null,parsed.data.discomfort ?? null,JSON.stringify(execution)),
    c.env.DB.prepare(`INSERT INTO feedback_adjustments(participant_id,source_session_id,intensity_cap,requires_review,reason,policy_version,updated_at) VALUES(?,?,?,?,?,?,?)
      ON CONFLICT(participant_id) DO UPDATE SET source_session_id=excluded.source_session_id,
      intensity_cap=MIN(feedback_adjustments.intensity_cap,excluded.intensity_cap),
      requires_review=MAX(feedback_adjustments.requires_review,excluded.requires_review),reason=excluded.reason,
      policy_version=excluded.policy_version,updated_at=excluded.updated_at`).bind(participantId,session.id,adjustment.intensityCap,Number(adjustment.requiresReview),adjustment.reason,adjustment.policyVersion,new Date().toISOString()),
    c.env.DB.prepare('UPDATE feedback_adjustments SET reason_code=? WHERE participant_id=?').bind(adjustment.reasonCode,participantId),
  ]);
  return c.json({saved:true,adjustment:await readFeedbackAdjustment(c,participantId)});
});

async function ownedSession(c: AppContext, sessionId: string, participantId: string) {
  return c.env.DB.prepare(
    `SELECT ds.id, ds.status, ds.stopped_at, ds.completed_at FROM device_sessions ds
      JOIN execution_authorizations ea ON ea.id = ds.authorization_id
      WHERE ds.id = ? AND ea.participant_id = ?`,
  ).bind(sessionId, participantId).first<Record<string, unknown>>();
}

app.onError((error, c) => {
  if (error.message.includes('DEVICE_BUSY')) return c.json({ error: 'DEVICE_BUSY' }, 409);
  if (error.message.includes('UNIQUE constraint failed: device_sessions')) {
    return c.json({ error: 'SESSION_CONFLICT' }, 409);
  }
  console.error('request_failed', { name: error.name, message: error.message });
  return c.json({ error: 'INTERNAL_ERROR' }, 500);
});

export default app;
