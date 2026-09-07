import { describe, expect, it } from 'vitest';
import {
  applyRequestedIntensity,
  calculateRecommendation,
  type CanonicalMeasurement,
} from '../src/algorithm';

const values = [
  ['M-001', 42, 17.7, 18.8, 7.9, 18.1],
  ['M-002', 42.2, 17.8, 18.7, 7.9, 18],
  ['M-003', 41.9, 17.7, 19.1, 8, 18.2],
  ['M-004', 42.1, 17.8, 18.9, 8, 18.1],
] as const;

const measurements: CanonicalMeasurement[] = values.map(
  ([id, weightKg, bmi, bodyFatPct, fatMassKg, skeletalMuscleMassKg]) => ({
    id,
    participantId: 'USER-001',
    deviceId: 'FITRUS-PLUS-01',
    qualityPassed: true,
    weightKg,
    bmi,
    bodyFatPct,
    fatMassKg,
    skeletalMuscleMassKg,
  }),
);

const safety = { acutePain: false, dizziness: false, clinicianHold: false };

describe('pilot-0.3.0 parity', () => {
  it('returns the female fixture result', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'female', heightCm: 154 },
      measurements,
      safety,
    });
    expect(result.average?.weightKg).toBe(42.05);
    expect(result.average?.bodyFatPct).toBe(18.88);
    expect(result.recommendation?.intensityPct).toBe(38);
    expect(result.status).toBe('REVIEW');
  });

  it('returns 45% for the same male input', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'male', heightCm: 154 },
      measurements,
      safety,
    });
    expect(result.recommendation?.intensityPct).toBe(45);
  });

  it('blocks dizziness before making a recommendation', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'female', heightCm: 154 },
      measurements,
      safety: { ...safety, dizziness: true },
    });
    expect(result.status).toBe('BLOCKED');
    expect(result.recommendation).toBeNull();
  });

  it('accepts only a manual intensity within the server-approved range', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'female', heightCm: 154 },
      measurements,
      safety,
    });

    expect(applyRequestedIntensity(result, 30).recommendation?.intensityPct).toBe(30);
    expect(() => applyRequestedIntensity(result, 39)).toThrow(RangeError);
    expect(() => applyRequestedIntensity(result, 19)).toThrow(RangeError);
  });
});
