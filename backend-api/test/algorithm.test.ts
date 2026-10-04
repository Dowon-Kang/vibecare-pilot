import { describe, expect, it } from 'vitest';
import { applyRequestedIntensity, calculateRecommendation, defaultRuleSet, type CanonicalMeasurement } from '../src/algorithm';

const safety = { acutePain: false, dizziness: false, clinicianHold: false };
const measurements = (bodyFatPct = 20, skeletalMuscleMassKg = 28): CanonicalMeasurement[] => [1, 2, 3, 4].map(index => ({
  id: `M${index}`, participantId: 'P1', deviceId: 'BIA', measuredAt: `2026-09-0${index}T00:00:00Z`, qualityPassed: true,
  muscleDefinition: 'SMM', definitionRef: 'TEST-SMM', muscleMeasurementMethod: 'BIA', methodEvidenceRef: 'TEST', muscleMassUnit: 'kg', acquisitionProtocol: 'TEST',
  weightKg: 60, bmi: 22, bodyFatPct, fatMassKg: 60 * bodyFatPct / 100, skeletalMuscleMassKg,
}));
const evaluate = (age: number, sex: 'female' | 'male', skeletalMuscleMassKg: number, bodyPart: 'wholeBody' | 'shoulder' | 'arm' | 'abdomen' | 'thigh' | 'calf' = 'wholeBody') => calculateRecommendation({
  profile: { participantId: 'P1', age, sex, heightCm: 170 }, measurements: measurements(20, skeletalMuscleMassKg), safety, bodyPart, evaluatedAt: new Date('2026-09-10T00:00:00Z'),
});

describe('pilot-0.9.1 illustrative simulator correction', () => {
  it('uses the three illustrative 0.95 factors for a 75-year-old woman with high body fat', () => {
    const result = calculateRecommendation({
      profile: { participantId: 'P1', age: 75, sex: 'female', heightCm: 170 },
      measurements: measurements(36, 18), safety, bodyPart: 'wholeBody',
      evaluatedAt: new Date('2026-09-10T00:00:00Z'),
    });
    expect(result.factors?.totalCoefficient).toBeCloseTo(0.857375);
    expect(result.recommendation).toMatchObject({ baseIntensityPct: 90, intensityPct: 77 });
  });
  it('Case A: keeps the medium preset for a male with medium muscle index', () => {
    const result = evaluate(30, 'male', 28);
    expect(result.recommendation).toMatchObject({ baseIntensityPct: 90, intensityPct: 90, frequencyHz: 8, durationSec: 1800 });
    expect(result.factors).toMatchObject({ genderCoefficient: 1, ageCoefficient: 1, bodyFatCoefficient: 1, totalCoefficient: 1, calculatedIntensityPct: 90 });
  });

  it('Case B: reduces a female medium preset by 0.95', () => {
    const result = evaluate(30, 'female', 18);
    expect(result.recommendation?.intensityPct).toBe(86);
    expect(result.factors).toMatchObject({ genderCoefficient: 0.95, ageCoefficient: 1, bodyFatCoefficient: 1, totalCoefficient: 0.95, calculatedIntensityPct: 85.5 });
  });

  it('Case C: applies female and 70-plus factors', () => {
    const result = evaluate(75, 'female', 18);
    expect(result.recommendation?.intensityPct).toBe(81);
  });

  it('Case D: uses the exact low whole-body preset', () => {
    const result = evaluate(75, 'female', 14);
    expect(result.recommendation).toMatchObject({ durationSec: 1500, frequencyHz: 8, baseIntensityPct: 80, intensityPct: 72 });
    expect(result.factors).toMatchObject({ totalCoefficient: 0.9025, calculatedIntensityPct: 72.2, muscleLevel: 'low' });
  });

  it('Case E: uses the exact high whole-body preset', () => {
    const result = evaluate(85, 'female', 22);
    expect(result.recommendation).toMatchObject({ durationSec: 2100, frequencyHz: 8, baseIntensityPct: 99, intensityPct: 89 });
    expect(result.factors).toMatchObject({ muscleLevel: 'high' });
  });

  it('classifies with the unrounded muscle index at a threshold boundary', () => {
    const result = evaluate(30, 'male', 24.57);

    expect(24.57 / (1.7 * 1.7)).toBeGreaterThan(8.5);
    expect(result.factors).toMatchObject({
      muscleIndexKgM2: 8.5,
      muscleLevel: 'medium',
    });
  });

  it('uses distinct body-part baselines and never enables physical output', () => {
    expect(evaluate(30, 'male', 28, 'shoulder').recommendation).toMatchObject({ durationSec: 1500, frequencyHz: 15, intensityPct: 85 });
    expect(evaluate(30, 'male', 28, 'calf')).toMatchObject({ physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false, recommendation: { durationSec: 600, frequencyHz: 35, intensityPct: 70 } });
  });

  it('applies configured reduction coefficients to simulator intensity and reports each factor', () => {
    const ruleSet = structuredClone(defaultRuleSet);
    ruleSet.correctionPolicy.gender.female = 0.95;
    ruleSet.correctionPolicy.age.seventies = 0.9;
    ruleSet.correctionPolicy.bodyFat.highCoefficient = 0.95;
    const result = calculateRecommendation({
      profile: { participantId: 'P1', age: 75, sex: 'female', heightCm: 170 },
      measurements: measurements(36, 18), safety, bodyPart: 'wholeBody', ruleSet,
      evaluatedAt: new Date('2026-09-10T00:00:00Z'),
    });
    expect(result.recommendation).toMatchObject({ baseIntensityPct: 90, intensityPct: 73, frequencyHz: 8, durationSec: 1800 });
    expect(result.factors).toMatchObject({
      genderCoefficient: 0.95, ageCoefficient: 0.9, bodyFatCoefficient: 0.95,
      muscleMassCoefficient: 1,
    });
    expect(result.factors?.totalCoefficient).toBeCloseTo(0.81225);
    expect(result.factors?.calculatedIntensityPct).toBeCloseTo(73.1025);
    expect(result.physicalExecution).toBe('PROHIBITED');
  });

  it('blocks symptoms and allows only downward manual adjustment', () => {
    const ready = evaluate(30, 'male', 28);
    expect(applyRequestedIntensity(ready, 50).recommendation?.intensityPct).toBe(50);
    expect(() => applyRequestedIntensity(ready, 91)).toThrow(RangeError);
    const blocked = calculateRecommendation({ profile: { participantId: 'P1', age: 30, sex: 'male', heightCm: 170 }, measurements: measurements(), safety: { ...safety, dizziness: true }, bodyPart: 'wholeBody', evaluatedAt: new Date('2026-09-10T00:00:00Z') });
    expect(blocked.status).toBe('BLOCKED');
  });
});
