// Explicitly typed muscle quantities. Standalone research module, not an execution API.
export const musclePathwayVersion = 'pilot-0.7.0';
export type MuscleCategory = 'LOW' | 'NOT_LOW' | 'MIDDLE' | 'REFERENCE';
const object = (v: unknown): Record<string, unknown> =>
  v !== null && typeof v === 'object' && !Array.isArray(v)
    ? (v as Record<string, unknown>)
    : {};
const nonempty = (v: unknown): v is string =>
  typeof v === 'string' && v.trim().length > 0;
const positive = (v: unknown): v is number =>
  typeof v === 'number' && Number.isFinite(v) && v > 0;
const display = (v: number) => Math.round(v * 100) / 100;
// Only absorb binary floating-point noise, not measurement uncertainty or display rounding.
const compare = (a: number, b: number) =>
  Math.abs(a - b) <= 8 * Number.EPSILON * Math.max(1, Math.abs(a), Math.abs(b))
    ? 0
    : a < b
      ? -1
      : 1;
const timestamp = (v: unknown): v is string =>
  typeof v === 'string' &&
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(v) &&
  Number.isFinite(Date.parse(v)) &&
  new Date(v).toISOString() === v;

export function calculateMusclePathway(raw: unknown) {
  const input = object(raw),
    profile = object(input.profile),
    safety = object(input.safety);
  const rows = Array.isArray(input.measurements)
    ? input.measurements.map(object)
    : [];
  const common = {
    algorithmVersion: musclePathwayVersion,
    realDeviceSendAllowed: false as const,
    command: null,
    evidence: {
      indexDefinition: 'EVIDENCE',
      thresholdTransfer: 'INDIRECT',
      simulationProtocol: 'PILOT',
      variabilityGate: 'PILOT',
    },
    personalization: { status: 'NOT_FITTED', appliedFactor: null },
  };
  const finish = (
    status: 'READY' | 'REVIEW' | 'BLOCKED',
    codes: string[],
    assessment: null | {
      kind: string;
      method: string;
      definitionRef: string;
      reference: string;
      indexName: string;
      indexKgM2: number;
      meanMassKg: number;
      sdKg: number;
      cvPct: number;
      minimumKg: number;
      maximumKg: number;
      measurementIds: string[];
      measurementTimes: string[];
      lowerCutoff: number;
      upperCutoff: number | null;
      lowComparison: string;
      category: MuscleCategory;
    } = null,
    simulationProtocol: null | {
      id: string;
      durationSec: number;
      frequencyHz: number;
      intensityPct: number;
    } = null,
  ) => ({
    ...common,
    status,
    executionStatus:
      status === 'BLOCKED'
        ? 'BLOCKED'
        : codes.includes('INSUFFICIENT_DATA')
          ? 'INSUFFICIENT_DATA'
          : status === 'REVIEW'
            ? 'REVIEW'
            : 'CALIBRATION_REQUIRED',
    assessment,
    simulationProtocol,
    reasonCodes: [
      ...codes,
      'INPUT_DEFINITION_ASSUMED',
      'PILOT_PROTOCOL',
      'SIMULATION_ONLY',
      'CALIBRATION_REQUIRED',
    ],
  });
  const safetyKeys = ['acutePain', 'dizziness', 'clinicianHold'];
  if (safetyKeys.some((k) => safety[k] === true))
    return finish('BLOCKED', ['SAFETY_HOLD']);
  if (rows.length !== 4) return finish('REVIEW', ['INSUFFICIENT_DATA']);
  if (safetyKeys.some((k) => typeof safety[k] !== 'boolean'))
    return finish('REVIEW', ['SAFETY_INCOMPLETE']);
  if (
    !nonempty(profile.participantId) ||
    !['female', 'male'].includes(String(profile.sex)) ||
    !Number.isInteger(profile.age) ||
    Number(profile.age) < 18 ||
    Number(profile.age) > 100 ||
    !positive(profile.heightCm) ||
    profile.heightCm < 100 ||
    profile.heightCm > 250
  )
    return finish('REVIEW', ['PROFILE_INVALID']);
  const heightSquared = (profile.heightCm / 100) ** 2;
  const fields = ['weightKg', 'bmi', 'bodyFatPct', 'fatMassKg'];
  for (const r of rows) {
    const m = object(r.muscle);
    if (
      !nonempty(r.id) ||
      !nonempty(r.deviceId) ||
      r.qualityPassed !== true ||
      !nonempty(r.measuredAt) ||
      !timestamp(r.measuredAt) ||
      fields.some((k) => !positive(r[k])) ||
      !positive(m.massKg)
    )
      return finish('REVIEW', ['MEASUREMENT_INVALID']);
    if (
      Number(r.bodyFatPct) > 100 ||
      Number(r.fatMassKg) > Number(r.weightKg) ||
      m.massKg > Number(r.weightKg) ||
      Math.abs(
        (Number(r.fatMassKg) / Number(r.weightKg)) * 100 - Number(r.bodyFatPct),
      ) > 1 ||
      Math.abs(Number(r.weightKg) / heightSquared - Number(r.bmi)) > 0.6
    )
      return finish('REVIEW', ['MEASUREMENT_INCONSISTENT']);
    if (r.participantId !== profile.participantId)
      return finish('REVIEW', ['PARTICIPANT_MISMATCH']);
  }
  if (new Set(rows.map((r) => r.id)).size !== 4)
    return finish('REVIEW', ['DUPLICATE_MEASUREMENT']);
  if (new Set(rows.map((r) => r.deviceId)).size !== 1)
    return finish('REVIEW', ['DEVICE_MISMATCH']);
  const muscles = rows.map((r) => object(r.muscle));
  if (
    muscles.some(
      (m) =>
        !['ASM', 'SMM'].includes(String(m.kind)) || !nonempty(m.definitionRef),
    )
  )
    return finish('REVIEW', ['MUSCLE_DEFINITION_UNKNOWN']);
  if (
    ['kind', 'method', 'definitionRef'].some(
      (k) => new Set(muscles.map((m) => m[k])).size !== 1,
    )
  )
    return finish('REVIEW', ['MUSCLE_DEFINITION_MIXED']);
  const { kind, method, definitionRef } = muscles[0];
  if (
    !['BIA', 'DXA'].includes(String(method)) ||
    (kind === 'SMM' && method !== 'BIA')
  )
    return finish('REVIEW', ['METHOD_UNSUPPORTED']);
  const age = Number(profile.age),
    female = profile.sex === 'female';
  if (age < (kind === 'ASM' ? 50 : 60))
    return finish('REVIEW', ['REFERENCE_OUT_OF_SCOPE']);
  const asmCutoffs: Record<string, number[]> =
    age < 65
      ? { BIA: [7.6, 5.7], DXA: [7.2, 5.5] }
      : { BIA: [7.0, 5.7], DXA: [7.0, 5.4] };
  const lower =
    kind === 'ASM'
      ? asmCutoffs[String(method)][female ? 1 : 0]
      : female
        ? 5.75
        : 8.5;
  const upper = kind === 'SMM' ? (female ? 6.75 : 10.75) : null;
  const classify = (total: number, n: number): MuscleCategory =>
    kind === 'ASM'
      ? compare(total, lower * heightSquared * n) < 0
        ? 'LOW'
        : 'NOT_LOW'
      : compare(total, lower * heightSquared * n) <= 0
        ? 'LOW'
        : compare(total, upper! * heightSquared * n) <= 0
          ? 'MIDDLE'
          : 'REFERENCE';
  const values = muscles.map((m) => Number(m.massKg)),
    sum = values.reduce((a, b) => a + b, 0),
    mean = sum / 4;
  const sd = Math.sqrt(values.reduce((a, b) => a + (b - mean) ** 2, 0) / 3),
    category = classify(sum, 4);
  const assessment = {
    kind: String(kind),
    method: String(method),
    definitionRef: String(definitionRef),
    measurementIds: rows.map((r) => String(r.id)),
    measurementTimes: rows.map((r) => String(r.measuredAt)),
    reference: kind === 'ASM' ? 'AWGS_2025_HEIGHT' : 'JANSSEN_2004_TOTAL_BIA',
    indexName: kind === 'ASM' ? 'ASMI' : 'SMMI',
    indexKgM2: display(mean / heightSquared),
    meanMassKg: mean,
    sdKg: sd,
    cvPct: (100 * sd) / mean,
    minimumKg: Math.min(...values),
    maximumKg: Math.max(...values),
    lowerCutoff: lower,
    upperCutoff: upper,
    lowComparison: kind === 'ASM' ? '<' : '<=',
    category,
  };
  const reasons: string[] = [];
  if (new Set(values.map((v) => classify(v, 1))).size > 1)
    reasons.push('MUSCLE_TIER_UNSTABLE');
  if (rows.reduce((a, r) => a + Number(r.bmi), 0) / 4 < 18.5)
    reasons.push('BMI_REVIEW');
  if (reasons.length) return finish('REVIEW', reasons, assessment);
  const protocol =
    category === 'LOW'
      ? { id: 'P1', durationSec: 180, frequencyHz: 12, intensityPct: 30 }
      : category === 'REFERENCE'
        ? { id: 'P3', durationSec: 300, frequencyHz: 20, intensityPct: 50 }
        : { id: 'P2', durationSec: 240, frequencyHz: 16, intensityPct: 40 };
  return finish('READY', [], assessment, protocol);
}
