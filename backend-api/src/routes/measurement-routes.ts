import { FitrusClient, type FitrusMeasurementKind } from '../fitrus-client';
import { parseFitrusRequest, type FitrusBodyFatRequest } from '../fitrus-contract';
import { normalizeFitrusBodyComposition, normalizeFitrusVital } from '../fitrus-normalizer';
import { accessParticipantId, jsonBody } from '../http';
import { bodyValues, latestValidSql } from '../measurement-store';
import { fitrusKindSchema, fitrusProxySchema } from '../request-schemas';
import type { VibeCareApp } from '../app-context';
import { requestId } from '../runtime';

export function registerMeasurementRoutes(app: VibeCareApp): void {
  app.post('/v1/fitrus/measurements/:kind', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const kind = fitrusKindSchema.safeParse(context.req.param('kind'));
    const body = fitrusProxySchema.safeParse(await jsonBody(context));
    if (!kind.success || !body.success || (kind.success && kind.data === 'bodyFat' && !body.data.muscleProvenance)) return context.json({ error: 'INVALID_REQUEST' }, 400);
    const providerPayload = parseFitrusRequest(kind.data, body.data.payload);
    if (!providerPayload.success) {
      return context.json({
        error: 'INVALID_FITRUS_PAYLOAD',
        fields: providerPayload.error.issues.map((issue) => issue.path.join('.')),
      }, 400);
    }
    if (kind.data === 'bodyFat') {
      const profile = await context.env.DB.prepare(
        'SELECT age, sex, height_cm FROM participants WHERE id = ?',
      ).bind(participantId).first<Record<string, unknown>>();
      const payload = providerPayload.data as FitrusBodyFatRequest;
      if (
        !profile || Number(profile.age) !== payload.age ||
        String(profile.sex).toLowerCase() !== payload.gender ||
        Math.abs(Number(profile.height_cm) - payload.height) > 0.01
      ) {
        return context.json({ error: 'FITRUS_PROFILE_MISMATCH' }, 409);
      }
    }
    if (!context.env.FITRUS_API_KEY) {
      return context.json({ error: 'FITRUS_NOT_CONFIGURED' }, 503);
    }

    const providerRequestId = `${requestId(context)}:${crypto.randomUUID()}`;
    const response = await new FitrusClient(
      context.env.FITRUS_API_KEY,
      context.env.FITRUS_API_BASE_URL,
    ).measure(kind.data as FitrusMeasurementKind, providerPayload.data, {
      requestId: providerRequestId,
    });
    const rawId = crypto.randomUUID();
    const measuredAt = body.data.measuredAt ?? new Date().toISOString();
    await context.env.DB.prepare(
      `INSERT INTO fitrus_raw_measurements
        (id, participant_id, kind, source_device_id, request_id, response_json, measured_at,
         muscle_definition, muscle_definition_ref, muscle_measurement_method,
         muscle_method_evidence_ref, muscle_mass_unit, acquisition_protocol)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      rawId,
      participantId,
      kind.data,
      body.data.deviceId,
      providerRequestId,
      JSON.stringify(response),
      measuredAt,
      body.data.muscleProvenance?.muscleDefinition ?? null,
      body.data.muscleProvenance?.definitionRef ?? null,
      body.data.muscleProvenance?.muscleMeasurementMethod ?? null,
      body.data.muscleProvenance?.methodEvidenceRef ?? null,
      body.data.muscleProvenance?.muscleMassUnit ?? null,
      body.data.muscleProvenance?.acquisitionProtocol ?? null,
    ).run();

    if (kind.data === 'bodyFat' && body.data.muscleProvenance) {
      const normalized = normalizeFitrusBodyComposition(
        providerPayload.data as FitrusBodyFatRequest,
        response,
      );
      if (!normalized.success) {
        return context.json({
          requestId: providerRequestId,
          rawMeasurementId: rawId,
          normalized: false,
          normalizationError: normalized.reason,
          providerResponse: response,
        }, 201);
      }

      const value = normalized.value;
      const provenance = body.data.muscleProvenance;
      await context.env.DB.prepare(
        `INSERT INTO bia_measurements
          (id, participant_id, device_id, measured_at, quality_passed, weight_kg, bmi,
           body_fat_pct, fat_mass_kg, skeletal_muscle_mass_kg, raw_json,
           basal_metabolic_rate_kcal, body_water_pct, protein_kg, mineral_kg, ecw_ratio,
           waist_cm, visceral_fat_level, muscle_definition, muscle_definition_ref,
           muscle_measurement_method, muscle_method_evidence_ref, muscle_mass_unit,
           acquisition_protocol)
         VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(
        rawId,
        participantId,
        body.data.deviceId,
        measuredAt,
        value.weightKg,
        value.bmi,
        value.bodyFatPct,
        value.fatMassKg,
        value.skeletalMuscleMassKg,
        JSON.stringify(response),
        value.basalMetabolicRateKcal,
        value.bodyWaterPct,
        value.proteinKg,
        value.mineralKg,
        value.ecwRatio,
        value.waistCm,
        value.visceralFatLevel,
        provenance.muscleDefinition,
        provenance.definitionRef,
        provenance.muscleMeasurementMethod,
        provenance.methodEvidenceRef,
        provenance.muscleMassUnit,
        provenance.acquisitionProtocol,
      ).run();
      return context.json({
        requestId: providerRequestId,
        rawMeasurementId: rawId,
        measurementId: rawId,
        normalized: true,
        providerResponse: response,
      }, 201);
    }

    if (kind.data !== 'bodyFat') {
      const normalized = normalizeFitrusVital(kind.data, response);
      if (!normalized.success) {
        return context.json({
          requestId: providerRequestId,
          rawMeasurementId: rawId,
          normalized: false,
          normalizationError: normalized.reason,
          providerResponse: response,
        }, 201);
      }
      await context.env.DB.prepare(
        `INSERT INTO vital_measurements
          (id, participant_id, kind, measured_at, values_json, units_json, source_raw_id)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ).bind(
        rawId,
        participantId,
        kind.data,
        measuredAt,
        JSON.stringify(normalized.value),
        JSON.stringify({}),
        rawId,
      ).run();
      return context.json({
        requestId: providerRequestId,
        rawMeasurementId: rawId,
        measurementId: rawId,
        normalized: true,
        providerResponse: response,
      }, 201);
    }

    return context.json({
      requestId: providerRequestId,
      rawMeasurementId: rawId,
      normalized: false,
      providerResponse: response,
    }, 201);
  });

  app.get('/v1/participants/me/measurement-set/current', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const deviceId = context.req.query('deviceId') ?? await context.env.DB.prepare(
      'SELECT device_id FROM bia_measurements WHERE participant_id = ? ORDER BY measured_at DESC LIMIT 1',
    ).bind(participantId).first<string>('device_id');
    if (!deviceId) {
      return context.json({
        history: [],
        selectedMeasurementIds: [],
        syncedAt: new Date().toISOString(),
      });
    }

    const rows = await context.env.DB.prepare(
      `SELECT * FROM bia_measurements
        WHERE participant_id = ? AND device_id = ?
        ORDER BY measured_at DESC, id DESC LIMIT 20`,
    ).bind(participantId, deviceId).all<Record<string, unknown>>();
    const selected = (await context.env.DB.prepare(latestValidSql)
      .bind(participantId, deviceId)
      .all<Record<string, unknown>>()).results;
    const history = [
      ...new Map([...rows.results, ...selected].map((row) => [String(row.id), row])).values(),
    ];
    return context.json({
      history: history.map((row) => ({
        id: row.id,
        participantId: row.participant_id,
        deviceId: row.device_id,
        measuredAt: row.measured_at,
        qualityPassed: Number(row.quality_passed) === 1,
        muscleDefinition: row.muscle_definition ?? 'UNKNOWN',
        definitionRef: row.muscle_definition_ref ?? '',
        muscleMeasurementMethod: row.muscle_measurement_method ?? 'UNKNOWN',
        methodEvidenceRef: row.muscle_method_evidence_ref ?? '',
        muscleMassUnit: row.muscle_mass_unit ?? 'kg',
        acquisitionProtocol: row.acquisition_protocol ?? 'UNKNOWN',
        values: bodyValues(row),
      })),
      selectedMeasurementIds: selected.map((row) => String(row.id)),
      syncedAt: new Date().toISOString(),
    });
  });

  app.get('/v1/participants/me/vitals', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const rows = await context.env.DB.prepare(
      `SELECT id, kind, measured_at, values_json, units_json
         FROM vital_measurements WHERE participant_id = ?
         ORDER BY measured_at DESC LIMIT 50`,
    ).bind(participantId).all<Record<string, unknown>>();
    return context.json({
      items: rows.results.map((row) => ({
        id: row.id,
        participantId,
        kind: row.kind,
        measuredAt: row.measured_at,
        values: JSON.parse(String(row.values_json)),
        units: JSON.parse(String(row.units_json)),
      })),
    });
  });
}
