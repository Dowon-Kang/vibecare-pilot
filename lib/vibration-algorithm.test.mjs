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

test('four valid measurements are averaged', () => {
  const result = averageMeasurements(profile, measurements);
  assert.equal(result.warnings.length, 0);
  assert.equal(result.averagedValues.weightKg, 48.5);
  assert.equal(result.averagedValues.bodyFatPct, 25);
});

test('age and sex pilot rules are included in the recommendation', () => {
  const result = calculateVibrationRecommendation(profile, measurements, safe);
  assert.equal(result.status, 'READY');
  assert.equal(result.recommendation.intensityPct, 43);
  assert.equal(result.adjustments[0].factor, 0.9);
  assert.equal(result.adjustments[1].factor, 0.95);
});

test('body fat outside the sex-specific pilot range reduces intensity', () => {
  const lowBodyFat = measurements.map((measurement) => ({
    ...measurement,
    bodyFatPct: 18,
    fatMassKg: measurement.weightKg * 0.18,
  }));
  const result = calculateVibrationRecommendation(profile, lowBodyFat, safe);
  assert.equal(result.recommendation.intensityPct, 38);
  assert.equal(result.adjustments[2].factor, 0.9);
});

test('a current safety symptom blocks recommendation', () => {
  const result = calculateVibrationRecommendation(profile, measurements, {
    ...safe,
    dizziness: true,
  });
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.recommendation, null);
});

test('a set with fewer than four measurements requires review', () => {
  const result = calculateVibrationRecommendation(profile, measurements.slice(0, 3), safe);
  assert.equal(result.status, 'REVIEW');
  assert.equal(result.recommendation, null);
});
