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

describe('pilot-0.9.0 skeletal-muscle fixed mapping', () => {
  it('Case A: keeps the medium preset for a male with medium muscle index', () => {
    const result = evaluate(30, 'male', 28);
    expect(result.recommendation).toMatchObject({ baseIntensityPct: 90, intensityPct: 90, frequencyHz: 8, durationSec: 1800 });
    expect(result.factors).toMatchObject({ genderCoefficient: 1, ageCoefficient: 1, bodyFatCoefficient: 1, totalCoefficient: 1, calculatedIntensityPct: 90 });
  });

  it('Case B: keeps the medium preset regardless of sex', () => {
    const result = evaluate(30, 'female', 18);
    expect(result.recommendation?.intensityPct).toBe(90);
    expect(result.factors).toMatchObject({ genderCoefficient: 1, ageCoefficient: 1, bodyFatCoefficient: 1, totalCoefficient: 1, calculatedIntensityPct: 90 });
  });

  it('Case C: keeps the medium preset regardless of age', () => {
    const result = evaluate(75, 'female', 18);
    expect(result.recommendation?.intensityPct).toBe(90);
  });

  it('Case D: uses the exact low whole-body preset', () => {
    const result = evaluate(75, 'female', 14);
    expect(result.recommendation).toMatchObject({ durationSec: 1500, frequencyHz: 8, intensityPct: 80 });
    expect(result.factors).toMatchObject({ totalCoefficient: 1, calculatedIntensityPct: 80, muscleLevel: 'low' });
  });

  it('Case E: uses the exact high whole-body preset', () => {
    const result = evaluate(85, 'female', 22);
    expect(result.recommendation).toMatchObject({ durationSec: 2100, frequencyHz: 8, intensityPct: 99 });
    expect(result.factors).toMatchObject({ muscleLevel: 'high' });
  });

  it('uses distinct body-part baselines and never enables physical output', () => {
    expect(evaluate(30, 'male', 28, 'shoulder').recommendation).toMatchObject({ durationSec: 1500, frequencyHz: 15, intensityPct: 85 });
    expect(evaluate(30, 'male', 28, 'calf')).toMatchObject({ physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false, recommendation: { durationSec: 600, frequencyHz: 35, intensityPct: 70 } });
  });

  it('blocks symptoms and allows only downward manual adjustment', () => {
    const ready = evaluate(30, 'male', 28);
    expect(applyRequestedIntensity(ready, 50).recommendation?.intensityPct).toBe(50);
    expect(() => applyRequestedIntensity(ready, 91)).toThrow(RangeError);
    const blocked = calculateRecommendation({ profile: { participantId: 'P1', age: 30, sex: 'male', heightCm: 170 }, measurements: measurements(), safety: { ...safety, dizziness: true }, bodyPart: 'wholeBody', evaluatedAt: new Date('2026-09-10T00:00:00Z') });
    expect(blocked.status).toBe('BLOCKED');
  });
});
