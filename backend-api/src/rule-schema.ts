import { z } from 'zod';
const thresholds = z.object({ lowMaximum: z.number().positive(), mediumMaximum: z.number().positive() }).refine((value) => value.lowMaximum < value.mediumMaximum);
const candidate = z.object({ durationSec: z.number().int().positive(), frequencyHz: z.number().int().positive(), intensityPct: z.number().min(0).max(100), evidence: z.literal('HYPOTHESIS_UNVALIDATED') });
const method = z.object({ method: z.string().min(1), methodEvidenceRef: z.string().min(1), definitionRef: z.string().min(1) });
const definition = (evidence: 'HYPOTHESIS_UNVALIDATED' | 'INDIRECT') => z.object({
  female: thresholds, male: thresholds, classificationEvidence: z.literal(evidence), applicableMethods: z.array(method),
});
export const ruleSchema = z.object({
  version: z.literal('pilot-0.7.0'), activeFrom: z.iso.datetime(), enabled: z.literal(true),
  research: z.object({ mode: z.literal('simulation_only'), protocolEvidence: z.literal('HYPOTHESIS_UNVALIDATED'), physicalExecution: z.literal('PROHIBITED') }),
  measurementPolicy: z.object({
    maximumAgeDays: z.number().int().positive(), maximumFutureSkewMinutes: z.number().int().nonnegative(), requiredUnit: z.literal('kg'),
    requireSameMethod: z.literal(true), requireSameAcquisitionProtocol: z.literal(true), policyBasis: z.literal('ENGINEERING_POLICY'),
  }),
  muscle: z.object({
    definitions: z.object({ ASM: definition('HYPOTHESIS_UNVALIDATED'), SMM: definition('INDIRECT') }),
    simulatorCandidates: z.object({ low: candidate, medium: candidate, reference: candidate }),
  }),
  output: z.object({ minimumPct: z.number().min(0).max(100), maximumPct: z.number().min(0).max(100) }).refine((value) => value.minimumPct <= value.maximumPct),
}).refine((value) => Object.values(value.muscle.simulatorCandidates).every((item) => item.intensityPct >= value.output.minimumPct && item.intensityPct <= value.output.maximumPct));
