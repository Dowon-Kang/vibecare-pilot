import { z } from 'zod';

const pct = z.number().min(0).max(100);
const range = z.object({ minimum: pct, maximum: pct })
  .refine((value) => value.minimum <= value.maximum);
const protocol = z.object({
  durationSec: z.number().int().positive(),
  frequencyHz: z.number().int().positive(),
  intensityPct: pct,
});
const muscleThresholds = z.object({
  lowMaximum: z.number().positive(),
  mediumMaximum: z.number().positive(),
}).refine((value) => value.lowMaximum < value.mediumMaximum);

export const ruleSchema = z.object({
  version: z.literal('pilot-0.6.0'),
  research: z.object({mode:z.literal('simulation_only'), measurementDefinition:z.literal('unverified'), protocolEvidence:z.literal('PILOT')}),
  activeFrom: z.iso.datetime(),
  enabled: z.literal(true),
  base: z.object({ durationSec: z.number().int().positive(), frequencyHz: z.number().int().positive(), intensityPct: pct }),
  age: z.object({ threshold: z.number().int().min(18).max(100), factor:z.literal(1) }),
  sex: z.object({ femaleFactor:z.literal(1), maleFactor:z.literal(1) }),
  bodyFat: z.object({ female: range, male: range, outsideRangeFactor:z.literal(1) }),
  output: z.object({ minimumPct: pct, maximumPct: pct })
    .refine((value) => value.minimumPct <= value.maximumPct),
  muscle: z.object({
    female: muscleThresholds,
    male: muscleThresholds,
    protocols: z.object({ low: protocol, medium: protocol, reference: protocol }),
  }),
}).refine((value) => value.base.intensityPct >= value.output.minimumPct &&
  value.base.intensityPct <= value.output.maximumPct)
  .refine((value) => Object.values(value.muscle.protocols).every((item) =>
    item.intensityPct >= value.output.minimumPct && item.intensityPct <= value.output.maximumPct));
