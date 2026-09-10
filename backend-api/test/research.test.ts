import { expect, it } from 'vitest';
import { feedbackAdjustment } from '../src/feedback';
import { muscleResearch } from '../../shared-contracts/muscle-research';

it('uses raw precision at tier boundaries and flags boundary crossing', () => {
  const heightCm = 150;
  const threshold = { lowMaximum: 8, mediumMaximum: 9 };
  const exact = 8 * (heightCm / 100) ** 2;
  expect(muscleResearch([exact, exact, exact, exact], heightCm, threshold).level).toBe('low');
  expect(muscleResearch([exact - 0.01, exact + 0.01, exact, exact], heightCm, threshold).unstable).toBe(true);
});

it('feedback decreases only intensity and holds other discomforts', () => {
  const clear = { rpe: 2, pain: 0, dizziness: false };
  expect(feedbackAdjustment({ ...clear, intensityRating: 'strong' }, 50).intensityCap).toBe(45);
  expect(feedbackAdjustment({ ...clear, intensityRating: 'weak' }, 50, 40).intensityCap).toBe(40);
  for (const extra of [{ durationRating: 'strong' }, { frequencyRating: 'strong' }, { earlyStopped: true }, { pain: 1 }, { dizziness: true }]) {
    expect(feedbackAdjustment({ ...clear, ...extra }, 50).requiresReview).toBe(true);
  }
});
