import { readFeedbackAdjustment } from '../feedback-store';
import { accessParticipantId, jsonBody } from '../http';
import { eventSchema, sessionSchema, stopSchema } from '../request-schemas';
import { loadRuleSet } from '../rule-store';
import { ownedSession } from '../session-store';
import type { VibeCareApp } from '../app-context';

export function registerSessionRoutes(app: VibeCareApp): void {
  app.post('/v1/device-sessions', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const idempotencyKey = context.req.header('Idempotency-Key');
    if (!idempotencyKey || idempotencyKey.length < 16) {
      return context.json({ error: 'IDEMPOTENCY_KEY_REQUIRED' }, 400);
    }
    const parsed = sessionSchema.safeParse(await jsonBody(context));
    if (!parsed.success) return context.json({ error: 'INVALID_REQUEST' }, 400);

    const existing = await context.env.DB.prepare(
      `SELECT ds.id, ds.status, ds.command_json, ds.authorization_id,
              ea.participant_id, ea.device_id
         FROM device_sessions ds JOIN execution_authorizations ea
           ON ea.id = ds.authorization_id
        WHERE ds.idempotency_key = ?`,
    ).bind(idempotencyKey).first<Record<string, unknown>>();
    if (existing) {
      if (
        existing.participant_id !== participantId ||
        existing.authorization_id !== parsed.data.authorizationId ||
        existing.device_id !== parsed.data.deviceId
      ) {
        return context.json({ error: 'IDEMPOTENCY_CONFLICT' }, 409);
      }
      return context.json({
        sessionId: existing.id,
        status: existing.status,
        command: JSON.parse(String(existing.command_json)),
      });
    }

    const authorization = await context.env.DB.prepare(
      `SELECT * FROM execution_authorizations
        WHERE id = ? AND participant_id = ? AND device_id = ?`,
    ).bind(
      parsed.data.authorizationId,
      participantId,
      parsed.data.deviceId,
    ).first<Record<string, unknown>>();
    if (!authorization) return context.json({ error: 'AUTHORIZATION_NOT_FOUND' }, 404);
    if (authorization.used_at) {
      return context.json({ error: 'AUTHORIZATION_ALREADY_USED' }, 409);
    }
    if (Date.parse(String(authorization.expires_at)) <= Date.now()) {
      return context.json({ error: 'AUTHORIZATION_EXPIRED' }, 409);
    }
    const mode = context.env.DEVICE_MODE ??
      (context.env.REAL_DEVICE_ENABLED === 'true' ? 'real' : 'mock');
    if (mode !== 'mock') {
      return context.json({ error: 'DEVICE_PROTOCOL_NOT_CONFIGURED' }, 501);
    }
    const rules = await loadRuleSet(context);
    if (!rules) return context.json({ error: 'ALGORITHM_UNAVAILABLE' }, 503);
    if (rules.version !== authorization.algorithm_version) {
      return context.json({ error: 'ALGORITHM_VERSION_MISMATCH' }, 409);
    }

    const recommendation = JSON.parse(String(authorization.recommendation_json)) as {
      recommendation: { durationSec: number; frequencyHz: number; intensityPct: number };
      algorithmVersion: string;
    };
    const adjustment = await readFeedbackAdjustment(context, participantId);
    if (
      adjustment &&
      (adjustment.requiresReview ||
        recommendation.recommendation.intensityPct > adjustment.intensityCap)
    ) {
      return context.json({ error: 'FEEDBACK_ADJUSTMENT_CHANGED' }, 409);
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
    await context.env.DB.batch([
      context.env.DB.prepare(
        'UPDATE execution_authorizations SET used_at = ? WHERE id = ? AND used_at IS NULL',
      ).bind(now, authorization.id),
      context.env.DB.prepare(
        `INSERT INTO device_sessions
          (id, authorization_id, idempotency_key, status, started_at, command_json)
         VALUES (?, ?, ?, 'RUNNING', ?, ?)`,
      ).bind(sessionId, authorization.id, idempotencyKey, now, JSON.stringify(command)),
      context.env.DB.prepare(
        `INSERT INTO command_events (id, session_id, event_type, payload_json)
         VALUES (?, ?, 'ACK', ?)`,
      ).bind(
        crypto.randomUUID(),
        sessionId,
        JSON.stringify({ mode: 'mock', acknowledgedAt: now }),
      ),
    ]);
    return context.json({ sessionId, status: 'RUNNING', mode: 'mock', command }, 201);
  });

  app.post('/v1/device-sessions/:id/events', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const parsed = eventSchema.safeParse(await jsonBody(context));
    if (!parsed.success) return context.json({ error: 'INVALID_REQUEST' }, 400);
    const session = await ownedSession(context, context.req.param('id'), participantId);
    if (!session) return context.json({ error: 'SESSION_NOT_FOUND' }, 404);
    if (['STOPPED', 'COMPLETED'].includes(String(session.status))) {
      return context.json({ error: 'SESSION_TERMINAL' }, 409);
    }

    const now = new Date().toISOString();
    await context.env.DB.batch([
      context.env.DB.prepare(
        'INSERT INTO command_events (id, session_id, event_type, payload_json) VALUES (?, ?, ?, ?)',
      ).bind(
        crypto.randomUUID(),
        session.id,
        parsed.data.eventType,
        JSON.stringify(parsed.data.payload),
      ),
      context.env.DB.prepare(
        `UPDATE device_sessions
            SET status = CASE WHEN ? = 'COMPLETED' THEN 'COMPLETED' ELSE status END,
                completed_at = CASE WHEN ? = 'COMPLETED' THEN ? ELSE completed_at END
          WHERE id = ?`,
      ).bind(parsed.data.eventType, parsed.data.eventType, now, session.id),
    ]);
    return context.json({ accepted: true }, 202);
  });

  app.post('/v1/device-sessions/:id/stop', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const session = await ownedSession(context, context.req.param('id'), participantId);
    if (!session) return context.json({ error: 'SESSION_NOT_FOUND' }, 404);
    const body = stopSchema.safeParse(await jsonBody(context));
    if (!body.success) return context.json({ error: 'INVALID_REQUEST' }, 400);
    if (['STOPPED', 'COMPLETED'].includes(String(session.status))) {
      return context.json({
        sessionId: session.id,
        status: session.status,
        stoppedAt: session.stopped_at ?? session.completed_at,
      });
    }

    const now = new Date().toISOString();
    const status = body.data.reason === 'completed' ? 'COMPLETED' : 'STOPPED';
    await context.env.DB.batch([
      context.env.DB.prepare(
        `UPDATE device_sessions
            SET status = ?, stopped_at = ?, stop_reason = ?, completed_at = ?
          WHERE id = ?`,
      ).bind(
        status,
        now,
        body.data.reason,
        status === 'COMPLETED' ? now : null,
        session.id,
      ),
      context.env.DB.prepare(
        `INSERT INTO command_events (id, session_id, event_type, payload_json)
         VALUES (?, ?, 'STOPPING', ?)`,
      ).bind(
        crypto.randomUUID(),
        session.id,
        JSON.stringify({ reason: body.data.reason, at: now }),
      ),
    ]);
    return context.json({ sessionId: session.id, status, stoppedAt: now });
  });
}
