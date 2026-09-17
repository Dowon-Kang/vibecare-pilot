import type { FitrusMeasurementKind, FitrusPayload } from './fitrus-client';
import {
  fitrusResponseSchemas,
  type FitrusBodyFatRequest,
  type FitrusBodyFatResponse,
} from './fitrus-contract';

export type NormalizedBodyComposition = {
  weightKg: number;
  bmi: number;
  bodyFatPct: number;
  fatMassKg: number;
  skeletalMuscleMassKg: number;
  basalMetabolicRateKcal: number | null;
  bodyWaterPct: null;
  proteinKg: number | null;
  mineralKg: number | null;
  ecwRatio: null;
  waistCm: null;
  visceralFatLevel: null;
};

export type NormalizationResult<T> =
  | { success: true; value: T }
  | { success: false; reason: 'UNSUPPORTED_RESPONSE_SHAPE' | 'INVALID_BODY_COMPOSITION' | 'PROVIDER_MODEL_ERROR' };

export function normalizeFitrusBodyComposition(
  request: FitrusBodyFatRequest,
  response: FitrusPayload,
): NormalizationResult<NormalizedBodyComposition> {
  const parsed = fitrusResponseSchemas.bodyFat.safeParse(response);
  if (!parsed.success) return { success: false, reason: 'UNSUPPORTED_RESPONSE_SHAPE' };
  const value: FitrusBodyFatResponse = parsed.data;
  if (value.bfp === null || value.bfm === null || value.smm === null) {
    return { success: false, reason: 'UNSUPPORTED_RESPONSE_SHAPE' };
  }
  const normalized = {
    weightKg: request.weight,
    bmi: request.weight / ((request.height / 100) ** 2),
    bodyFatPct: value.bfp,
    fatMassKg: value.bfm,
    skeletalMuscleMassKg: value.smm,
    basalMetabolicRateKcal: value.bmr,
    bodyWaterPct: null,
    proteinKg: value.protein,
    mineralKg: value.mineral,
    ecwRatio: null,
    waistCm: null,
    visceralFatLevel: null,
  };
  if (
    normalized.bodyFatPct <= 0 || normalized.bodyFatPct > 100 ||
    normalized.fatMassKg <= 0 || normalized.fatMassKg > normalized.weightKg ||
    normalized.skeletalMuscleMassKg <= 0 || normalized.skeletalMuscleMassKg > normalized.weightKg ||
    Math.abs((normalized.fatMassKg / normalized.weightKg) * 100 - normalized.bodyFatPct) > 1
  ) return { success: false, reason: 'INVALID_BODY_COMPOSITION' };
  return { success: true, value: normalized };
}

export function normalizeFitrusVital(
  kind: Exclude<FitrusMeasurementKind, 'bodyFat'>,
  response: FitrusPayload,
): NormalizationResult<Record<string, unknown>> {
  if (kind === 'stressV2') {
    const stressV2 = fitrusResponseSchemas.stressV2.safeParse(response);
    if (!stressV2.success) return { success: false, reason: 'UNSUPPORTED_RESPONSE_SHAPE' };
    if (stressV2.data.errorcode !== 0) return { success: false, reason: 'PROVIDER_MODEL_ERROR' };
    return { success: true, value: stressV2.data };
  }
  const parsed = fitrusResponseSchemas[kind].safeParse(response);
  if (!parsed.success) return { success: false, reason: 'UNSUPPORTED_RESPONSE_SHAPE' };
  return { success: true, value: parsed.data as Record<string, unknown> };
}
