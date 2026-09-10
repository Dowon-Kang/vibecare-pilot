import { z } from 'zod';

export const pinSchema = z.object({
  participantCode: z.string().min(1),
  pin: z.string().regex(/^\d{6}$/),
});

export const refreshSchema = z.object({ refreshToken: z.string().min(20) });

export const safetySchema = z.object({
  acutePain: z.boolean(),
  dizziness: z.boolean(),
  clinicianHold: z.boolean(),
});

export const authorizeSchema = z.object({
  measurementIds: z.array(z.string().min(1)).length(4)
    .refine((ids) => new Set(ids).size === 4),
  safety: safetySchema,
  deviceId: z.string().min(1),
  sourceDeviceId: z.string().min(1).optional(),
  algorithmVersion: z.string().min(1),
  muscleMassBasis: z.enum(['ASM', 'SMM']).default('SMM'),
  requestedIntensityPct: z.number().int().min(1).max(100).optional(),
});

export const fitrusKindSchema = z.enum([
  'bodyFat',
  'bloodPressure',
  'heartRate',
  'stress',
  'stressV2',
  'bodyTemperature',
]);

export const fitrusProxySchema = z.object({
  deviceId: z.string().min(1),
  measuredAt: z.iso.datetime().optional(),
  payload: z.record(z.string(), z.unknown()),
});

export const sessionSchema = z.object({
  authorizationId: z.string().min(1),
  deviceId: z.string().min(1),
});

export const eventSchema = z.object({
  eventType: z.enum(['ACK', 'RUNNING', 'STOPPING', 'COMPLETED', 'ERROR', 'DISCONNECTED']),
  payload: z.record(z.string(), z.unknown()).default({}),
});

export const feedbackSchema = z.object({
  sessionId: z.string().min(1),
  rpe: z.number().int().min(0).max(10),
  pain: z.number().int().min(0).max(10),
  dizziness: z.boolean(),
  intensityRating: z.enum(['weak', 'suitable', 'strong']).optional(),
  durationRating: z.enum(['weak', 'suitable', 'strong']).optional(),
  frequencyRating: z.enum(['weak', 'suitable', 'strong']).optional(),
  discomfort: z.string().max(500).nullable().optional(),
  earlyStopped: z.boolean().optional(),
  actualDurationSec: z.number().nonnegative().nullable().optional(),
  measuredPeakG: z.number().nonnegative().nullable().optional(),
  measuredRmsG: z.number().nonnegative().nullable().optional(),
});

export const stopSchema = z.object({ reason: z.string().min(1).max(100) });
