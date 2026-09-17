import { describe, expect, it } from 'vitest';
import { applyRequestedIntensity, calculateRecommendation, defaultRuleSet, type CanonicalMeasurement } from '../src/algorithm';

const safety = { acutePain: false, dizziness: false, clinicianHold: false };
const measurements = (bodyFatPct = 25): CanonicalMeasurement[] => [1, 2, 3, 4].map(index => ({
  id: `M${index}`, participantId: 'P1', deviceId: 'BIA', measuredAt: `2026-09-0${index}T00:00:00Z`, qualityPassed: true,
  muscleDefinition: 'SMM', definitionRef: 'TEST-SMM', muscleMeasurementMethod: 'BIA', methodEvidenceRef: 'TEST', muscleMassUnit: 'kg', acquisitionProtocol: 'TEST',
  weightKg: 60, bmi: 22, bodyFatPct, fatMassKg: 60 * bodyFatPct / 100, skeletalMuscleMassKg: 24,
}));
const evaluate = (age: number, sex: 'female' | 'male', bodyFatPct: number, bodyPart: 'wholeBody' | 'shoulder' | 'arm' | 'abdomen' | 'thigh' | 'calf' = 'wholeBody') => calculateRecommendation({
  profile: { participantId: 'P1', age, sex, heightCm: 170 }, measurements: measurements(bodyFatPct), safety, bodyPart, evaluatedAt: new Date('2026-09-10T00:00:00Z'),
});

describe('pilot-0.8.0 coefficient model', () => {
  it('Case A: keeps the baseline for a male under 60 with normal body fat', () => {
    const result = evaluate(30, 'male', 20);
    expect(result.recommendation).toMatchObject({ baseIntensityPct: 90, intensityPct: 90, frequencyHz: 8, durationSec: 1800 });
    expect(result.factors).toMatchObject({ genderCoefficient: 1, ageCoefficient: 1, bodyFatCoefficient: 1, totalCoefficient: 1, calculatedIntensityPct: 90 });
  });

  it('Case B: applies only the female coefficient', () => {
    const result = evaluate(30, 'female', 25);
    expect(result.recommendation?.intensityPct).toBe(86);
    expect(result.factors).toMatchObject({ genderCoefficient: .95, ageCoefficient: 1, bodyFatCoefficient: 1, totalCoefficient: .95, calculatedIntensityPct: 85.5 });
  });

  it('Case C: multiplies female and age-70 coefficients', () => {
    const result = evaluate(75, 'female', 25);
    expect(result.recommendation?.intensityPct).toBe(77);
    expect(result.factors).toMatchObject({ genderCoefficient: .95, ageCoefficient: .9, bodyFatCoefficient: 1, totalCoefficient: .855, calculatedIntensityPct: 76.95 });
  });

  it('Case D: additionally applies the low-body-fat coefficient', () => {
    const result = evaluate(75, 'female', 18);
    expect(result.recommendation?.intensityPct).toBe(73);
    expect(result.factors).toMatchObject({ genderCoefficient: .95, ageCoefficient: .9, bodyFatCoefficient: .95, totalCoefficient: .8123, calculatedIntensityPct: 73.1, bodyFatBand: 'low' });
  });

  it('Case E: clamps overlapping reductions to the configured minimum', () => {
    const ruleSet = structuredClone(defaultRuleSet);
    ruleSet.output.minimumPct = 70;
    ruleSet.correctionPolicy.gender.female = .5;
    const result = calculateRecommendation({ profile: { participantId: 'P1', age: 85, sex: 'female', heightCm: 170 }, measurements: measurements(18), safety, bodyPart: 'calf', ruleSet, evaluatedAt: new Date('2026-09-10T00:00:00Z') });
    expect(result.factors?.calculatedIntensityPct).toBeLessThan(70);
    expect(result.recommendation?.intensityPct).toBe(70);
  });

  it('uses distinct body-part baselines and never enables physical output', () => {
    expect(evaluate(30, 'male', 20, 'shoulder').recommendation).toMatchObject({ durationSec: 1500, frequencyHz: 15, intensityPct: 85 });
    expect(evaluate(30, 'male', 20, 'calf')).toMatchObject({ physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false, recommendation: { durationSec: 600, frequencyHz: 35, intensityPct: 70 } });
  });

  it('blocks symptoms and allows only downward manual adjustment', () => {
    const ready = evaluate(30, 'male', 20);
    expect(applyRequestedIntensity(ready, 50).recommendation?.intensityPct).toBe(50);
    expect(() => applyRequestedIntensity(ready, 91)).toThrow(RangeError);
    const blocked = calculateRecommendation({ profile: { participantId: 'P1', age: 30, sex: 'male', heightCm: 170 }, measurements: measurements(), safety: { ...safety, dizziness: true }, bodyPart: 'wholeBody', evaluatedAt: new Date('2026-09-10T00:00:00Z') });
    expect(blocked.status).toBe('BLOCKED');
  });
});
