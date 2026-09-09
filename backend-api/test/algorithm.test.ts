import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  applyRequestedIntensity,
  defaultRuleSet,
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

describe('pilot-0.6.0 muscle-driven parity', () => {
  it('returns the female fixture result', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'female', heightCm: 154 },
      measurements,
      safety,
    });
    expect(result.average?.weightKg).toBe(42.05);
    expect(result.average?.bodyFatPct).toBe(18.88);
    expect(result.muscleAssessment).toEqual({totalSmmi: 7.63, level: 'reference'});
    expect(result.recommendation).toEqual({durationSec: 300, frequencyHz: 20, intensityPct: 50});
    expect(result.status).toBe('REVIEW');
  });

  it('uses the male low-muscle protocol for the same absolute muscle mass', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'male', heightCm: 154 },
      measurements,
      safety,
    });
    expect(result.muscleAssessment?.level).toBe('low');
    expect(result.recommendation).toEqual({durationSec: 180, frequencyHz: 12, intensityPct: 30});
  });

  it('calculates the explicit ASM interpretation independently from SMM', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'USER-001', age: 72, sex: 'female', heightCm: 154 },
      measurements,
      safety,
      muscleMassBasis: 'ASM',
    });
    expect(result.muscleMassBasis).toBe('ASM');
    expect(result.muscleAssessment).toEqual({totalSmmi: 7.63, level: 'medium'});
    expect(result.recommendation).toEqual({durationSec: 240, frequencyHz: 16, intensityPct: 40});
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
    expect(() => applyRequestedIntensity(result, 51)).toThrow(RangeError);
    expect(() => applyRequestedIntensity(result, 19)).toThrow(RangeError);
  });
});

const fixture = JSON.parse(readFileSync(new URL('../../shared-contracts/fixtures/pilot-0.6.0.json', import.meta.url), 'utf8'));
it('reads the shared contract fixture', () => {
  const result = calculateRecommendation({profile: fixture.profile, safety, ruleSet: fixture.ruleSet,
    measurements: fixture.measurements.map((m: {values: object}) => ({...m,...m.values}))});
  expect(result.recommendation?.intensityPct).toBe(fixture.expected.femaleIntensityPct);
  expect(result.average?.bmi).toBe(fixture.expected.averageBmi);
  expect(result.status).toBe(fixture.expected.status);
});
it.each([NaN, Infinity, 0, -1, 101])('rejects invalid fat percent %s without an output', (value) => {
  const result = calculateRecommendation({profile: fixture.profile, safety,
    measurements: measurements.map(m => ({...m, bodyFatPct: value}))});
  expect(result.status).toBe('REVIEW');
  expect(result.recommendation).toBeNull();
  expect(result.average).toBeNull();
});
it('rejects disabled and malformed rules outside HTTP too', () => {
  for(const ruleSet of [{...defaultRuleSet,enabled:false}, {...defaultRuleSet,base:{...defaultRuleSet.base,frequencyHz:20.5}}]) {
    expect(calculateRecommendation({profile:fixture.profile, safety, measurements, ruleSet}).recommendation).toBeNull();
  }
});
