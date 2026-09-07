import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  averageMeasurements,
  calculateVibrationRecommendation,
} from './vibration-algorithm.ts';

const profile = { userId: 'U-1', age: 72, sex: 'female', heightCm: 154 };
const base = {
  userId: 'U-1', measuredAt: '2026-08-22T09:00:00+09:00', deviceId: 'D-1',
  qualityPassed: true, weightKg: 48, bmi: 20.24, bodyFatPct: 25,
  fatMassKg: 12, skeletalMuscleMassKg: 19, basalMetabolicRateKcal: 1150,
  bodyWaterPct: 55, proteinKg: 7, mineralKg: 2.5, ecwRatio: 0.38,
  waistCm: 70, visceralFatLevel: 7,
};
const measurements = [1, 2, 3, 4].map((index) => ({
  ...base,
  id: `M-${index}`,
  weightKg: 46 + index,
  bmi: (46 + index) / 1.54 ** 2,
  fatMassKg: (46 + index) * 0.25,
}));
const safe = { acutePain: false, dizziness: false, clinicianHold: false };

await test('four valid measurements are averaged', () => {
  const result = averageMeasurements(profile, measurements);
  assert.equal(result.warnings.length, 0);
  assert.equal(result.averagedValues.weightKg, 48.5);
  assert.equal(result.averagedValues.bodyFatPct, 25);
});

await test('age and sex pilot rules are included in the recommendation', () => {
  const result = calculateVibrationRecommendation(profile, measurements, safe);
  assert.equal(result.status, 'READY');
  assert.equal(result.recommendation.intensityPct, 43);
  assert.equal(result.adjustments[0].factor, 0.9);
  assert.equal(result.adjustments[1].factor, 0.95);
});

await test('body fat outside the sex-specific pilot range reduces intensity', () => {
  const lowBodyFat = measurements.map((measurement) => ({
    ...measurement,
    bodyFatPct: 18,
    fatMassKg: measurement.weightKg * 0.18,
  }));
  const result = calculateVibrationRecommendation(profile, lowBodyFat, safe);
  assert.equal(result.recommendation.intensityPct, 38);
  assert.equal(result.adjustments[2].factor, 0.9);
});

await test('a current safety symptom blocks recommendation', () => {
  const result = calculateVibrationRecommendation(profile, measurements, {
    ...safe,
    dizziness: true,
  });
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.recommendation, null);
});

await test('a set with fewer than four measurements requires review', () => {
  const result = calculateVibrationRecommendation(profile, measurements.slice(0, 3), safe);
  assert.equal(result.status, 'REVIEW');
  assert.equal(result.recommendation, null);
});

await test('shared contract fixture gives the same research recommendation', () => {
  const fixture = JSON.parse(readFileSync(new URL('../../packages/contracts/fixtures/pilot-0.3.0.json', import.meta.url), 'utf8'));
  const result = calculateVibrationRecommendation({...fixture.profile,userId:fixture.profile.participantId},
    fixture.measurements.map(m => ({...m,...m.values,userId:m.participantId})),safe);
  assert.equal(result.recommendation.intensityPct, fixture.expected.femaleIntensityPct);
  assert.equal(result.status, fixture.expected.status);
});
await test('optional missing values do not invalidate required inputs', () => {
  const result = calculateVibrationRecommendation(profile, measurements.map(m => ({...m, waistCm:null,ecwRatio:0})),safe);
  assert.equal(result.status, 'READY');
  assert.equal(result.averagedValues.waistCm, null);
  assert.equal(result.averagedValues.ecwRatio, 0);
});
await test('invalid core values and duplicate records never produce an output', () => {
  for (const rows of [measurements.map(m => ({...m,bodyFatPct:NaN})), measurements.map(m => ({...m,fatMassKg:1})), [measurements[0],measurements[0],measurements[2],measurements[3]]]) {
    assert.equal(calculateVibrationRecommendation(profile, rows, safe).recommendation, null);
  }
});
