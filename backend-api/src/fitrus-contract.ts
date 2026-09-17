import { z } from 'zod';
import type { FitrusMeasurementKind, FitrusPayload } from './fitrus-client';

const finite = z.number().finite();
const positive = finite.positive();
const ppgList = z.array(z.number().int()).min(1);

export const fitrusRequestSchemas = {
  bloodPressure: z.object({ list: ppgList, baseSystolic: positive, baseDiastolic: positive }),
  heartRate: z.object({ list: ppgList }),
  stress: z.object({ list: ppgList, age: z.number().int().positive() }),
  stressV2: z.object({ list: ppgList }),
  bodyTemperature: z.object({ temp: finite }),
  bodyFat: z.object({
    age: z.number().int().positive(), height: positive, weight: positive,
    gender: z.string().transform((value) => value.toLowerCase()).pipe(z.enum(['male', 'female'])),
    voltage: finite,
    correct: finite.nullish().transform((value) => value ?? 0),
  }),
} satisfies Record<FitrusMeasurementKind, z.ZodType>;

export const fitrusResponseSchemas = {
  bloodPressure: z.object({ dbp: finite, sbp: finite }),
  heartRate: z.object({ hr: finite, hrv: finite, spo2: finite }),
  stress: z.object({
    hr: z.number().int(), hrv: z.number().int(), spo2: z.number().int(),
    value: z.number().int(), level: z.enum(['LOW', 'MID', 'HIGH']),
  }),
  bodyTemperature: z.object({ temp: finite }),
  bodyFat: z.object({
    bfp: finite.nullable(), bfm: finite.nullable(), bmr: finite.nullable(),
    smm: finite.nullable(), icw: finite.nullable(), ecw: finite.nullable(),
    protein: finite.nullable(), mineral: finite.nullable(), bodyAge: z.number().int().nullable(),
    createdAt: z.iso.datetime({ offset: true }),
  }),
  stressV2: z.object({
    hr: z.number().int(), hrv: z.number().int(), sdnn: z.number().int(),
    rmssd: z.number().int(), sd1: z.number().int(), sd2: z.number().int(),
    pnn50: z.number().int(), spo2: z.number().int(), errorcode: z.number().int(),
    min_hr: finite, max_hr: finite, lf_power: finite, hf_power: finite,
    lf_hf_ratio: finite, sri: finite, fatigue_index: finite, health_index: finite,
  }),
} satisfies Record<FitrusMeasurementKind, z.ZodType>;

export function parseFitrusRequest(kind: FitrusMeasurementKind, payload: FitrusPayload) {
  return fitrusRequestSchemas[kind].safeParse(payload);
}

export type FitrusBodyFatRequest = z.infer<typeof fitrusRequestSchemas.bodyFat>;
export type FitrusBodyFatResponse = z.infer<typeof fitrusResponseSchemas.bodyFat>;
