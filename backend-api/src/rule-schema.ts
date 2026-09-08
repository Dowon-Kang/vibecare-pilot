import { z } from 'zod';

const pct = z.number().min(0).max(100);
const factor = z.number().positive().max(1);
const range = z.object({ minimum: pct, maximum: pct })
  .refine((value) => value.minimum <= value.maximum);

export const ruleSchema = z.object({
  version: z.string().min(1),
  activeFrom: z.iso.datetime(),
  enabled: z.literal(true),
  base: z.object({ durationSec: z.number().int().positive(), frequencyHz: z.number().int().positive(), intensityPct: pct }),
  age: z.object({ threshold: z.number().int().min(18).max(100), factor }),
  sex: z.object({ femaleFactor: factor, maleFactor: factor }),
  bodyFat: z.object({ female: range, male: range, outsideRangeFactor: factor }),
  output: z.object({ minimumPct: pct, maximumPct: pct })
    .refine((value) => value.minimumPct <= value.maximumPct),
}).refine((value) => value.base.intensityPct >= value.output.minimumPct &&
  value.base.intensityPct <= value.output.maximumPct);
