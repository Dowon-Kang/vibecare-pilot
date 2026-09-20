import { describe, expect, it } from 'vitest';

import { feedbackAdjustment } from '../src/feedback';
import { feedbackSchema } from '../src/request-schemas';

describe('compact session feedback', () => {
  it('accepts feedback without an optional RPE score', () => {
    const parsed = feedbackSchema.safeParse({
      sessionId: 'session-1',
      pain: 0,
      dizziness: false,
      intensityRating: 'suitable',
      durationRating: 'suitable',
      frequencyRating: 'suitable',
    });

    expect(parsed.success).toBe(true);
  });

  it('still reduces a strong intensity report without RPE', () => {
    const result = feedbackAdjustment(
      {
        pain: 0,
        dizziness: false,
        intensityRating: 'strong',
        durationRating: 'suitable',
        frequencyRating: 'suitable',
      },
      80,
    );

    expect(result.intensityCap).toBe(72);
    expect(result.reasonCode).toBe('FEEDBACK_INTENSITY_REDUCED');
  });
});
