import { z } from 'zod';

const coefficient = z.number().positive().max(1);
const baseline = z.object({
  durationMin: z.number().int().positive(),
  frequencyHz: z.number().int().positive(),
  intensityPct: z.number().min(0).max(100),
});
const fatRange = z.object({ lowThresholdPct: z.number().min(0).max(100), highThresholdPct: z.number().min(0).max(100) })
  .refine(value => value.lowThresholdPct < value.highThresholdPct);

export const ruleSchema = z.object({
  version: z.literal('pilot-0.8.0'), activeFrom: z.iso.datetime(), enabled: z.literal(true),
  research: z.object({ mode: z.literal('simulation_only'), protocolEvidence: z.literal('HYPOTHESIS_UNVALIDATED'), physicalExecution: z.literal('PROHIBITED') }),
  measurementPolicy: z.object({
    maximumAgeDays: z.number().int().positive(), maximumFutureSkewMinutes: z.number().int().nonnegative(), requiredUnit: z.literal('kg'),
    requireSameMethod: z.literal(true), requireSameAcquisitionProtocol: z.literal(true), policyBasis: z.literal('ENGINEERING_POLICY'),
  }),
  baselines: z.object({ wholeBody: baseline, shoulder: baseline, arm: baseline, abdomen: baseline, thigh: baseline, calf: baseline }),
  correctionPolicy: z.object({
    gender: z.object({ female: coefficient, male: coefficient }),
    age: z.object({ under60: coefficient, sixties: coefficient, seventies: coefficient, eightyPlus: coefficient }),
    bodyFat: z.object({ female: fatRange, male: fatRange, lowCoefficient: coefficient, normalCoefficient: coefficient, highCoefficient: coefficient }),
    muscleMass: z.object({ neutralCoefficient: z.literal(1) }),
  }),
  output: z.object({ minimumPct: z.number().min(0).max(100), maximumPct: z.number().min(0).max(100) }).refine(value => value.minimumPct <= value.maximumPct),
});
