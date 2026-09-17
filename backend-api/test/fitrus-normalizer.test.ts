import { describe, expect, it } from 'vitest';
import { parseFitrusRequest } from '../src/fitrus-contract';
import { normalizeFitrusBodyComposition, normalizeFitrusVital } from '../src/fitrus-normalizer';

const bodyFatRequest = {
  age: 48, height: 169.7, weight: 68.6, gender: 'male' as const,
  voltage: 1.1296023, correct: 0,
};
const bodyFatResponse = {
  bfp: 20.4, bfm: 14, bmr: 1542.7, smm: 29.8, icw: 24.1, ecw: 14.7,
  protein: 10.3, mineral: 3.5, bodyAge: 45,
  createdAt: '2026-09-14T05:30:00.000+00:00',
};

describe('FITRUS provider contract', () => {
  it('normalizes the documented bodyfat response without guessed aliases', () => {
    const result = normalizeFitrusBodyComposition(bodyFatRequest, bodyFatResponse);
    expect(result).toMatchObject({ success: true, value: {
      weightKg: 68.6, bodyFatPct: 20.4, fatMassKg: 14,
      skeletalMuscleMassKg: 29.8, basalMetabolicRateKcal: 1542.7,
      bodyWaterPct: null, ecwRatio: null,
    } });
    if (result.success) expect(result.value.bmi).toBeCloseTo(23.82, 2);
  });

  it('fails closed for nullable required algorithm values or inconsistent composition', () => {
    expect(normalizeFitrusBodyComposition(bodyFatRequest, { ...bodyFatResponse, smm: null }))
      .toEqual({ success: false, reason: 'UNSUPPORTED_RESPONSE_SHAPE' });
    expect(normalizeFitrusBodyComposition(bodyFatRequest, { ...bodyFatResponse, bfp: 10 }))
      .toEqual({ success: false, reason: 'INVALID_BODY_COMPOSITION' });
    expect(normalizeFitrusBodyComposition(bodyFatRequest, { data: bodyFatResponse }))
      .toEqual({ success: false, reason: 'UNSUPPORTED_RESPONSE_SHAPE' });
  });

  it('requires every documented request field and normalizes gender/correct', () => {
    expect(parseFitrusRequest('bloodPressure', { list: [1, 2, 3] }).success).toBe(false);
    expect(parseFitrusRequest('heartRate', { list: [1, 2.5, 3] }).success).toBe(false);
    const parsed = parseFitrusRequest('bodyFat', { ...bodyFatRequest, gender: 'FEMALE', correct: null });
    expect(parsed.success && parsed.data).toMatchObject({ gender: 'female', correct: 0 });
  });

  it('stores only a successful stress2 model result as normalized', () => {
    const value = {
      hr: 72, hrv: 41, sdnn: 38, rmssd: 31, sd1: 22, sd2: 49, pnn50: 18,
      spo2: 98, errorcode: 0, min_hr: 64, max_hr: 83, lf_power: 425.2,
      hf_power: 318.7, lf_hf_ratio: 1.33, sri: 27.5, fatigue_index: 21,
      health_index: 78,
    };
    expect(normalizeFitrusVital('stressV2', value)).toEqual({ success: true, value });
    expect(normalizeFitrusVital('stressV2', { ...value, errorcode: 7 }))
      .toEqual({ success: false, reason: 'PROVIDER_MODEL_ERROR' });
  });
});
