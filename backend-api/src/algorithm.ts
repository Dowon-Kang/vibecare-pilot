import { ruleSchema } from './rule-schema';

export type Sex = 'female' | 'male';
export type BodyPart = 'wholeBody' | 'shoulder' | 'arm' | 'abdomen' | 'thigh' | 'calf';
export type CanonicalMeasurement = {
  id: string; participantId: string; deviceId: string; measuredAt: string; qualityPassed: boolean;
  muscleDefinition: 'UNKNOWN' | 'ASM' | 'SMM'; definitionRef: string;
  muscleMeasurementMethod: string; methodEvidenceRef: string; muscleMassUnit: 'kg'; acquisitionProtocol: string;
  weightKg: number; bmi: number; bodyFatPct: number; fatMassKg: number; skeletalMuscleMassKg: number;
};
type BaseSetting = { durationMin: number; frequencyHz: number; intensityPct: number };
export type AlgorithmRuleSet = {
  version: 'pilot-0.8.0'; activeFrom: string; enabled: true;
  research: { mode: 'simulation_only'; protocolEvidence: 'HYPOTHESIS_UNVALIDATED'; physicalExecution: 'PROHIBITED' };
  measurementPolicy: { maximumAgeDays: number; maximumFutureSkewMinutes: number; requiredUnit: 'kg'; requireSameMethod: true; requireSameAcquisitionProtocol: true; policyBasis: 'ENGINEERING_POLICY' };
  baselines: Record<BodyPart, BaseSetting>;
  correctionPolicy: {
    gender: { female: number; male: number };
    age: { under60: number; sixties: number; seventies: number; eightyPlus: number };
    bodyFat: {
      female: { lowThresholdPct: number; highThresholdPct: number };
      male: { lowThresholdPct: number; highThresholdPct: number };
      lowCoefficient: number; normalCoefficient: number; highCoefficient: number;
    };
    muscleMass: { neutralCoefficient: 1 };
  };
  output: { minimumPct: number; maximumPct: number };
};
export type AlgorithmInput = {
  profile: { participantId: string; age: number; sex: Sex; heightCm: number };
  measurements: CanonicalMeasurement[];
  safety: { acutePain: boolean; dizziness: boolean; clinicianHold: boolean };
  bodyPart: BodyPart;
  ruleSet?: AlgorithmRuleSet;
  evaluatedAt?: Date;
};

export const defaultRuleSet: AlgorithmRuleSet = {
  version: 'pilot-0.8.0', activeFrom: '2026-09-17T00:00:00Z', enabled: true,
  research: { mode: 'simulation_only', protocolEvidence: 'HYPOTHESIS_UNVALIDATED', physicalExecution: 'PROHIBITED' },
  measurementPolicy: { maximumAgeDays: 30, maximumFutureSkewMinutes: 5, requiredUnit: 'kg', requireSameMethod: true, requireSameAcquisitionProtocol: true, policyBasis: 'ENGINEERING_POLICY' },
  baselines: {
    wholeBody: { durationMin: 30, frequencyHz: 8, intensityPct: 90 },
    shoulder: { durationMin: 25, frequencyHz: 15, intensityPct: 85 },
    arm: { durationMin: 20, frequencyHz: 20, intensityPct: 80 },
    abdomen: { durationMin: 15, frequencyHz: 25, intensityPct: 75 },
    thigh: { durationMin: 10, frequencyHz: 35, intensityPct: 70 },
    calf: { durationMin: 10, frequencyHz: 35, intensityPct: 70 },
  },
  // Every coefficient below is a configurable prototype hypothesis, not a clinical safety limit.
  correctionPolicy: {
    gender: { female: 0.95, male: 1 },
    age: { under60: 1, sixties: 0.95, seventies: 0.90, eightyPlus: 0.85 },
    bodyFat: {
      female: { lowThresholdPct: 20, highThresholdPct: 35 },
      male: { lowThresholdPct: 10, highThresholdPct: 28 },
      lowCoefficient: 0.95, normalCoefficient: 1, highCoefficient: 0.95,
    },
    muscleMass: { neutralCoefficient: 1 },
  },
  output: { minimumPct: 20, maximumPct: 99 },
};

export type RecommendationResult = {
  status: 'READY' | 'REVIEW' | 'BLOCKED'; dataDecision: 'ACCEPTED' | 'REVIEW_REQUIRED' | 'BLOCKED';
  executionStatus: 'SIMULATION_READY' | 'REVIEW' | 'BLOCKED'; simulationEligibility: 'ELIGIBLE' | 'INELIGIBLE';
  physicalExecution: 'PROHIBITED'; realDeviceSendAllowed: false; reasonCodes: string[]; warnings: string[];
  algorithmVersion: string; bodyPart: BodyPart; muscleMassBasis: 'SMM';
  average: null | { weightKg: number; bmi: number; bodyFatPct: number; fatMassKg: number; skeletalMuscleMassKg: number };
  recommendation: null | { durationSec: number; frequencyHz: number; intensityPct: number; baseIntensityPct: number; purpose: 'SIMULATION_CANDIDATE'; evidence: 'HYPOTHESIS_UNVALIDATED' };
  factors: null | {
    genderCoefficient: number; ageCoefficient: number; bodyFatCoefficient: number; muscleMassCoefficient: number;
    totalCoefficient: number; calculatedIntensityPct: number; bodyFatBand: 'low' | 'normal' | 'high';
  };
};

const round = (value: number, digits = 2) => Math.round((value + Number.EPSILON) * 10 ** digits) / 10 ** digits;
const mean = (values: number[]) => values.reduce((sum, value) => sum + value, 0) / values.length;
const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(value, high));
const code = (warning: string) => warning.split(':', 1)[0];

export function genderCoefficient(sex: Sex, rules: AlgorithmRuleSet): number {
  return rules.correctionPolicy.gender[sex];
}

export function ageCoefficient(age: number, rules: AlgorithmRuleSet): number {
  if (age < 60) return rules.correctionPolicy.age.under60;
  if (age < 70) return rules.correctionPolicy.age.sixties;
  if (age < 80) return rules.correctionPolicy.age.seventies;
  return rules.correctionPolicy.age.eightyPlus;
}

export function bodyFatCoefficient(bodyFatPct: number, sex: Sex, rules: AlgorithmRuleSet): { coefficient: number; band: 'low' | 'normal' | 'high' } {
  const range = rules.correctionPolicy.bodyFat[sex];
  if (bodyFatPct < range.lowThresholdPct) return { coefficient: rules.correctionPolicy.bodyFat.lowCoefficient, band: 'low' };
  if (bodyFatPct > range.highThresholdPct) return { coefficient: rules.correctionPolicy.bodyFat.highCoefficient, band: 'high' };
  return { coefficient: rules.correctionPolicy.bodyFat.normalCoefficient, band: 'normal' };
}

function rejected(bodyPart: BodyPart, ruleSet: AlgorithmRuleSet, status: 'REVIEW' | 'BLOCKED', warnings: string[], average: RecommendationResult['average'] = null): RecommendationResult {
  return { status, dataDecision: status === 'BLOCKED' ? 'BLOCKED' : 'REVIEW_REQUIRED', executionStatus: status, simulationEligibility: 'INELIGIBLE', physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false, reasonCodes: [...new Set(warnings.map(code))], warnings: [...new Set(warnings)], algorithmVersion: ruleSet.version, bodyPart, muscleMassBasis: 'SMM', average, recommendation: null, factors: null };
}

export function calculateRecommendation(input: AlgorithmInput): RecommendationResult {
  const { profile, measurements, safety, bodyPart } = input;
  const ruleSet = input.ruleSet ?? defaultRuleSet;
  const evaluatedAt = input.evaluatedAt ?? new Date();
  const warnings: string[] = [];
  if (!ruleSchema.safeParse(ruleSet).success) warnings.push('RULE_INVALID: 사용 가능한 규칙이 없습니다.');
  if (!Number.isInteger(profile.age) || profile.age < 18 || profile.age > 100 || !Number.isFinite(profile.heightCm) || profile.heightCm < 100 || profile.heightCm > 250 || !['female', 'male'].includes(profile.sex) || !profile.participantId.trim()) warnings.push('PROFILE_INVALID: 참여자 정보가 유효하지 않습니다.');
  if (measurements.length !== 4) warnings.push('MEASUREMENT_COUNT_INVALID: 측정값은 정확히 4건이어야 합니다.');
  if (measurements.some(item => item.participantId !== profile.participantId)) warnings.push('PARTICIPANT_MIXED: 다른 참여자 값이 포함되었습니다.');
  if (new Set(measurements.map(item => item.deviceId)).size !== 1) warnings.push('DEVICE_MIXED: 다른 측정 기기 값이 포함되었습니다.');
  if (new Set(measurements.map(item => item.id)).size !== measurements.length) warnings.push('MEASUREMENT_DUPLICATED: 중복 측정 ID가 있습니다.');
  if (measurements.some(item => !item.qualityPassed)) warnings.push('QUALITY_FAILED: 품질 검사를 통과하지 못했습니다.');
  if (measurements.some(item => item.muscleDefinition !== 'SMM')) warnings.push('SMM_DEFINITION_REQUIRED: 현재 모델은 SMM 정의가 확인된 값만 사용합니다.');
  if (measurements.some(item => item.muscleMassUnit !== ruleSet.measurementPolicy.requiredUnit)) warnings.push('MUSCLE_UNIT_INVALID: 근육량 단위가 kg이 아닙니다.');
  if (new Set(measurements.map(item => item.muscleMeasurementMethod)).size !== 1 || measurements.some(item => !item.muscleMeasurementMethod.trim() || item.muscleMeasurementMethod === 'UNKNOWN')) warnings.push('METHOD_INVALID: 동일하고 확인된 측정 방법이 필요합니다.');
  if (new Set(measurements.map(item => item.acquisitionProtocol)).size !== 1 || measurements.some(item => !item.acquisitionProtocol.trim() || item.acquisitionProtocol === 'UNKNOWN')) warnings.push('ACQUISITION_PROTOCOL_INVALID: 동일하고 확인된 획득 프로토콜이 필요합니다.');
  const oldestAllowed = evaluatedAt.getTime() - ruleSet.measurementPolicy.maximumAgeDays * 86_400_000;
  const latestAllowed = evaluatedAt.getTime() + ruleSet.measurementPolicy.maximumFutureSkewMinutes * 60_000;
  for (const item of measurements) {
    const timestamp = Date.parse(item.measuredAt);
    if (!Number.isFinite(timestamp) || timestamp < oldestAllowed || timestamp > latestAllowed) warnings.push('MEASUREMENT_TIME_INVALID: 측정 시각이 운영 허용 범위를 벗어났습니다.');
  }
  const fields = ['weightKg', 'bmi', 'bodyFatPct', 'fatMassKg', 'skeletalMuscleMassKg'] as const;
  const validValues = measurements.every(item => {
    const expectedFatMassKg = item.weightKg * item.bodyFatPct / 100;
    const fatMassToleranceKg = Math.max(1, expectedFatMassKg * 0.20);
    return fields.every(field => Number.isFinite(item[field]) && item[field] > 0) &&
      item.bodyFatPct <= 100 && item.fatMassKg <= item.weightKg &&
      item.skeletalMuscleMassKg <= item.weightKg &&
      Math.abs(item.fatMassKg - expectedFatMassKg) <= fatMassToleranceKg;
  });
  if (!validValues) warnings.push('MEASUREMENT_VALUE_INVALID: 필수 측정값이 유효하지 않습니다.');
  const average = measurements.length === 4 && validValues ? Object.fromEntries(fields.map(field => [field, round(mean(measurements.map(item => item[field])))])) as NonNullable<RecommendationResult['average']> : null;
  const safetyWarnings = [safety.acutePain ? 'SAFETY_ACUTE_PAIN: 현재 통증이 있습니다.' : null, safety.dizziness ? 'SAFETY_DIZZINESS: 어지럼 증상이 있습니다.' : null, safety.clinicianHold ? 'SAFETY_CLINICIAN_HOLD: 전문가 보류 지시가 있습니다.' : null].filter((value): value is string => value !== null);
  if (safetyWarnings.length) return rejected(bodyPart, ruleSet, 'BLOCKED', [...warnings, ...safetyWarnings], average);
  if (warnings.length || !average) return rejected(bodyPart, ruleSet, 'REVIEW', warnings, average);

  const base = ruleSet.baselines[bodyPart];
  const gender = genderCoefficient(profile.sex, ruleSet);
  const age = ageCoefficient(profile.age, ruleSet);
  const bodyFat = bodyFatCoefficient(average.bodyFatPct, profile.sex, ruleSet);
  const muscle = ruleSet.correctionPolicy.muscleMass.neutralCoefficient;
  const total = gender * age * bodyFat.coefficient * muscle;
  const calculated = base.intensityPct * total;
  const intensity = Math.round(clamp(calculated, ruleSet.output.minimumPct, Math.min(ruleSet.output.maximumPct, base.intensityPct)));
  return {
    status: 'READY', dataDecision: 'ACCEPTED', executionStatus: 'SIMULATION_READY', simulationEligibility: 'ELIGIBLE', physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false,
    reasonCodes: ['SIMULATION_ONLY', 'HYPOTHESIS_UNVALIDATED', 'PHYSICAL_EXECUTION_PROHIBITED'], warnings: [], algorithmVersion: ruleSet.version, bodyPart, muscleMassBasis: 'SMM', average,
    recommendation: { durationSec: base.durationMin * 60, frequencyHz: base.frequencyHz, intensityPct: intensity, baseIntensityPct: base.intensityPct, purpose: 'SIMULATION_CANDIDATE', evidence: 'HYPOTHESIS_UNVALIDATED' },
    factors: { genderCoefficient: gender, ageCoefficient: age, bodyFatCoefficient: bodyFat.coefficient, muscleMassCoefficient: muscle, totalCoefficient: round(total, 4), calculatedIntensityPct: round(calculated, 2), bodyFatBand: bodyFat.band },
  };
}

export function applyRequestedIntensity(result: RecommendationResult, requestedIntensityPct: number | undefined, ruleSet: AlgorithmRuleSet = defaultRuleSet): RecommendationResult {
  if (requestedIntensityPct == null || result.recommendation == null) return result;
  if (!Number.isInteger(requestedIntensityPct) || requestedIntensityPct < ruleSet.output.minimumPct || requestedIntensityPct > result.recommendation.intensityPct) throw new RangeError('Requested intensity is outside the simulator-approved range');
  return { ...result, recommendation: { ...result.recommendation, intensityPct: requestedIntensityPct } };
}
