import { applyRequestedIntensity, calculateRecommendation } from '../algorithm';
import { readFeedbackAdjustment } from '../feedback-store';
import { accessParticipantId, jsonBody } from '../http';
import { canonicalMeasurement, latestValidSql } from '../measurement-store';
import { authorizeSchema } from '../request-schemas';
import { loadRuleSet } from '../rule-store';
import type { VibeCareApp } from '../app-context';

export function registerRecommendationRoutes(app: VibeCareApp): void {
  app.get('/v1/algorithm-rules/current', async (context) => {
    if (!await accessParticipantId(context)) {
      return context.json({ error: 'UNAUTHORIZED' }, 401);
    }
    const rules = await loadRuleSet(context);
    return rules
      ? context.json(rules)
      : context.json({ error: 'ALGORITHM_UNAVAILABLE' }, 503);
  });

  app.post('/v1/recommendations/authorize', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const parsed = authorizeSchema.safeParse(await jsonBody(context));
    if (!parsed.success) {
      return context.json({ error: 'INVALID_REQUEST', details: parsed.error.issues }, 400);
    }

    const participant = await context.env.DB.prepare(
      'SELECT id, age, sex, height_cm FROM participants WHERE id = ?',
    ).bind(participantId).first<Record<string, unknown>>();
    if (!participant) return context.json({ error: 'PARTICIPANT_NOT_FOUND' }, 404);
    const placeholders = parsed.data.measurementIds.map(() => '?').join(',');
    const rows = await context.env.DB.prepare(
      `SELECT * FROM bia_measurements WHERE id IN (${placeholders})`,
    ).bind(...parsed.data.measurementIds).all<Record<string, unknown>>();
    const sourceDeviceId = parsed.data.sourceDeviceId ?? parsed.data.deviceId;
    const currentRows = await context.env.DB.prepare(latestValidSql)
      .bind(participantId, sourceDeviceId)
      .all<{ id: string }>();
    const requestedIds = new Set(parsed.data.measurementIds);
    if (
      currentRows.results.length !== 4 ||
      currentRows.results.some((row) => !requestedIds.has(String(row.id)))
    ) {
      return context.json({
        error: 'MEASUREMENT_SET_STALE',
        currentMeasurementIds: currentRows.results.map((row) => String(row.id)),
      }, 409);
    }

    const ruleSet = await loadRuleSet(context);
    if (!ruleSet) return context.json({ error: 'ALGORITHM_UNAVAILABLE' }, 503);
    if (parsed.data.algorithmVersion !== ruleSet.version) {
      return context.json({
        error: 'ALGORITHM_VERSION_MISMATCH',
        currentRuleSet: ruleSet,
      }, 409);
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
      muscleMassBasis: parsed.data.muscleMassBasis,
      ruleSet,
    });
    const adjustment = await readFeedbackAdjustment(context, participantId);
    if (adjustment && result.recommendation) {
      if (adjustment.requiresReview || adjustment.intensityCap < ruleSet.output.minimumPct) {
        result = {
          ...result,
          status: 'BLOCKED',
          executionStatus: 'BLOCKED',
          reasonCodes: [...result.reasonCodes, 'FEEDBACK_HOLD'],
          recommendation: null,
          warnings: [...result.warnings, adjustment.reason],
        };
      } else {
        result = {
          ...result,
          recommendation: {
            ...result.recommendation,
            intensityPct: Math.min(
              result.recommendation.intensityPct,
              adjustment.intensityCap,
            ),
          },
        };
      }
    }

    try {
      result = applyRequestedIntensity(result, parsed.data.requestedIntensityPct, ruleSet);
    } catch (error) {
      if (!(error instanceof RangeError)) throw error;
      return context.json({
        error: 'INTENSITY_OUTSIDE_SAFE_RANGE',
        minimumPct: ruleSet.output.minimumPct,
        maximumPct: result.recommendation?.intensityPct ?? null,
      }, 409);
    }

    const measurementSetId = crypto.randomUUID();
    const recommendationId = crypto.randomUUID();
    await context.env.DB.batch([
      context.env.DB.prepare(
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
      context.env.DB.prepare(
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
    if (result.status !== 'READY') {
      return context.json({ authorized: false, recommendationId, result }, 409);
    }
    const mode = context.env.DEVICE_MODE ??
      (context.env.REAL_DEVICE_ENABLED === 'true' ? 'real' : 'mock');
    if (mode !== 'mock') {
      return context.json({
        authorized: false,
        error: 'CALIBRATION_REQUIRED',
        recommendationId,
        result,
      }, 409);
    }

    const authorizationId = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 60_000).toISOString();
    await context.env.DB.prepare(
      `INSERT INTO execution_authorizations
        (id, participant_id, device_id, algorithm_version, recommendation_json, expires_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).bind(
      authorizationId,
      participantId,
      parsed.data.deviceId,
      result.algorithmVersion,
      JSON.stringify(result),
      expiresAt,
    ).run();
    return context.json({
      authorized: true,
      mode: 'mock',
      authorizationId,
      recommendationId,
      expiresAt,
      result,
    }, 201);
  });
}
