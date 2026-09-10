import { ruleSchema } from './rule-schema';
import { muscleResearch, type MuscleStatistics, type MuscleTier } from '../../shared-contracts/muscle-research';

export type Sex = 'female' | 'male';
export type MuscleDefinition = 'UNKNOWN' | 'ASM' | 'SMM';
type ConfirmedDefinition = Exclude<MuscleDefinition, 'UNKNOWN'>;
type Thresholds = { lowMaximum: number; mediumMaximum: number };
type DefinitionRule = {
  female: Thresholds; male: Thresholds;
  classificationEvidence: 'HYPOTHESIS_UNVALIDATED' | 'INDIRECT';
  applicableMethods: { method: string; methodEvidenceRef: string; definitionRef: string }[];
};
type SimulatorCandidate = { durationSec: number; frequencyHz: number; intensityPct: number; evidence: 'HYPOTHESIS_UNVALIDATED' };

export type CanonicalMeasurement = {
  id: string; participantId: string; deviceId: string; measuredAt: string; qualityPassed: boolean;
  muscleDefinition: MuscleDefinition; definitionRef: string; muscleMeasurementMethod: string; methodEvidenceRef: string;
  muscleMassUnit: 'kg'; acquisitionProtocol: string;
  weightKg: number; bmi: number; bodyFatPct: number; fatMassKg: number; skeletalMuscleMassKg: number;
};
export type AlgorithmRuleSet = {
  version: 'pilot-0.7.0'; activeFrom: string; enabled: true;
  research: { mode: 'simulation_only'; protocolEvidence: 'HYPOTHESIS_UNVALIDATED'; physicalExecution: 'PROHIBITED' };
  measurementPolicy: { maximumAgeDays: number; maximumFutureSkewMinutes: number; requiredUnit: 'kg'; requireSameMethod: true; requireSameAcquisitionProtocol: true; policyBasis: 'ENGINEERING_POLICY' };
  muscle: { definitions: Record<ConfirmedDefinition, DefinitionRule>; simulatorCandidates: Record<MuscleTier, SimulatorCandidate> };
  output: { minimumPct: number; maximumPct: number };
};
export type AlgorithmInput = {
  profile: { participantId: string; age: number; sex: Sex; heightCm: number };
  measurements: CanonicalMeasurement[];
  safety: { acutePain: boolean; dizziness: boolean; clinicianHold: boolean };
  muscleMassBasis: ConfirmedDefinition;
  ruleSet?: AlgorithmRuleSet;
  evaluatedAt?: Date;
};

export const defaultRuleSet: AlgorithmRuleSet = {
  version: 'pilot-0.7.0', activeFrom: '2026-09-10T00:00:00Z', enabled: true,
  research: { mode: 'simulation_only', protocolEvidence: 'HYPOTHESIS_UNVALIDATED', physicalExecution: 'PROHIBITED' },
  // Operational freshness policy only; it is not clinical dose evidence.
  measurementPolicy: { maximumAgeDays: 30, maximumFutureSkewMinutes: 5, requiredUnit: 'kg', requireSameMethod: true, requireSameAcquisitionProtocol: true, policyBasis: 'ENGINEERING_POLICY' },
  muscle: {
    definitions: {
      ASM: { female: { lowMaximum: 5.7, mediumMaximum: 6.7 }, male: { lowMaximum: 7, mediumMaximum: 8 }, classificationEvidence: 'HYPOTHESIS_UNVALIDATED', applicableMethods: [] },
      SMM: { female: { lowMaximum: 5.75, mediumMaximum: 6.75 }, male: { lowMaximum: 8.5, mediumMaximum: 10.75 }, classificationEvidence: 'INDIRECT', applicableMethods: [] },
    },
    simulatorCandidates: {
      low: { durationSec: 180, frequencyHz: 12, intensityPct: 30, evidence: 'HYPOTHESIS_UNVALIDATED' },
      medium: { durationSec: 240, frequencyHz: 16, intensityPct: 40, evidence: 'HYPOTHESIS_UNVALIDATED' },
      reference: { durationSec: 300, frequencyHz: 20, intensityPct: 50, evidence: 'HYPOTHESIS_UNVALIDATED' },
    },
  },
  output: { minimumPct: 20, maximumPct: 70 },
};

export type RecommendationResult = {
  status: 'READY' | 'REVIEW' | 'BLOCKED'; dataDecision: 'ACCEPTED' | 'REVIEW_REQUIRED' | 'BLOCKED';
  executionStatus: 'SIMULATION_READY' | 'REVIEW' | 'BLOCKED';
  simulationEligibility: 'ELIGIBLE' | 'INELIGIBLE'; physicalExecution: 'PROHIBITED'; realDeviceSendAllowed: false;
  reasonCodes: string[]; warnings: string[]; algorithmVersion: string; muscleMassBasis: ConfirmedDefinition;
  muscleStatistics: MuscleStatistics | null;
  average: null | { weightKg: number; bmi: number; bodyFatPct: number; fatMassKg: number; skeletalMuscleMassKg: number };
  muscleAssessment: { heightAdjustedIndex: number; level: MuscleTier; unstable: boolean } | null;
  recommendation: (SimulatorCandidate & { purpose: 'SIMULATION_CANDIDATE' }) | null;
  factors: null;
};

const round = (value: number, digits = 2) => Math.round(value * 10 ** digits) / 10 ** digits;
const mean = (values: number[]) => values.reduce((sum, value) => sum + value, 0) / values.length;
const code = (warning: string) => warning.split(':', 1)[0];
const rejected = (basis: ConfirmedDefinition, ruleSet: AlgorithmRuleSet, status: 'REVIEW' | 'BLOCKED', warnings: string[], average: RecommendationResult['average'] = null): RecommendationResult => ({
  status, executionStatus: status, dataDecision: status === 'BLOCKED' ? 'BLOCKED' : 'REVIEW_REQUIRED', simulationEligibility: 'INELIGIBLE', physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false,
  reasonCodes: [...new Set(warnings.map(code))], warnings: [...new Set(warnings)], algorithmVersion: ruleSet.version, muscleMassBasis: basis,
  muscleStatistics: null, average, muscleAssessment: null, recommendation: null, factors: null,
});

export function calculateRecommendation(input: AlgorithmInput): RecommendationResult {
  const { profile, measurements, safety, muscleMassBasis } = input;
  const ruleSet = input.ruleSet ?? defaultRuleSet;
  const evaluatedAt = input.evaluatedAt ?? new Date();
  const warnings: string[] = [];
  if (!ruleSchema.safeParse(ruleSet).success) warnings.push('RULE_INVALID: 사용 가능한 규칙이 없습니다.');
  if (!Number.isInteger(profile.age) || profile.age < 18 || profile.age > 100 || !Number.isFinite(profile.heightCm) || profile.heightCm < 100 || profile.heightCm > 250 || !['female', 'male'].includes(profile.sex) || !profile.participantId.trim()) warnings.push('PROFILE_INVALID: 참여자 정보가 유효하지 않습니다.');
  if (measurements.length !== 4) warnings.push('MEASUREMENT_COUNT_INVALID: 측정값은 정확히 4건이어야 합니다.');
  if (measurements.some((item) => item.participantId !== profile.participantId)) warnings.push('PARTICIPANT_MIXED: 다른 참여자 값이 포함되었습니다.');
  if (new Set(measurements.map((item) => item.deviceId)).size !== 1) warnings.push('DEVICE_MIXED: 다른 측정 기기 값이 포함되었습니다.');
  if (new Set(measurements.map((item) => item.id)).size !== measurements.length) warnings.push('MEASUREMENT_DUPLICATED: 중복 측정 ID가 있습니다.');
  if (measurements.some((item) => !item.qualityPassed)) warnings.push('QUALITY_FAILED: 품질 검사를 통과하지 못했습니다.');

  const definitions = new Set(measurements.map((item) => item.muscleDefinition));
  if (definitions.has('UNKNOWN')) warnings.push('MUSCLE_DEFINITION_UNKNOWN: 공급사 근육량 정의가 확인되지 않았습니다.');
  if (definitions.size !== 1) warnings.push('MUSCLE_DEFINITION_MIXED: 서로 다른 근육량 정의가 섞였습니다.');
  if ([...definitions].some((definition) => definition !== muscleMassBasis)) warnings.push('MUSCLE_BASIS_MISMATCH: 선택 기준과 측정 정의가 다릅니다.');
  if (measurements.some((item) => !item.definitionRef.trim())) warnings.push('MUSCLE_DEFINITION_REF_MISSING: 정의 근거 참조가 없습니다.');
  if (new Set(measurements.map((item) => item.definitionRef)).size !== 1) warnings.push('MUSCLE_DEFINITION_REF_MIXED: 정의 근거 참조가 섞였습니다.');
  if (measurements.some((item) => item.muscleMassUnit !== ruleSet.measurementPolicy.requiredUnit)) warnings.push('MUSCLE_UNIT_INVALID: 근육량 단위가 kg이 아닙니다.');
  if (new Set(measurements.map((item) => item.muscleMeasurementMethod)).size !== 1) warnings.push('METHOD_MIXED: 측정 방법이 섞였습니다.');
  if (measurements.some((item) => !item.muscleMeasurementMethod.trim() || item.muscleMeasurementMethod === 'UNKNOWN')) warnings.push('METHOD_UNKNOWN: 측정 방법이 확인되지 않았습니다.');
  if (measurements.some((item) => !item.methodEvidenceRef.trim())) warnings.push('METHOD_EVIDENCE_REF_MISSING: 측정 방법 근거 참조가 없습니다.');
  if (new Set(measurements.map((item) => item.methodEvidenceRef)).size !== 1) warnings.push('METHOD_EVIDENCE_REF_MIXED: 측정 방법 근거 참조가 섞였습니다.');
  const definitionRule = ruleSet.muscle.definitions[muscleMassBasis];
  if (!measurements.every((item) => definitionRule.applicableMethods.some((entry) =>
    entry.method === item.muscleMeasurementMethod &&
    entry.methodEvidenceRef === item.methodEvidenceRef &&
    entry.definitionRef === item.definitionRef))) warnings.push('METHOD_NOT_APPLICABLE: 현재 규칙에서 검증된 측정 방법·정의 조합이 아닙니다.');
  if (new Set(measurements.map((item) => item.acquisitionProtocol)).size !== 1) warnings.push('ACQUISITION_PROTOCOL_MIXED: 획득 프로토콜이 섞였습니다.');
  if (measurements.some((item) => !item.acquisitionProtocol.trim() || item.acquisitionProtocol === 'UNKNOWN')) warnings.push('ACQUISITION_PROTOCOL_UNKNOWN: 획득 프로토콜이 확인되지 않았습니다.');

  const oldestAllowed = evaluatedAt.getTime() - ruleSet.measurementPolicy.maximumAgeDays * 86_400_000;
  const latestAllowed = evaluatedAt.getTime() + ruleSet.measurementPolicy.maximumFutureSkewMinutes * 60_000;
  for (const item of measurements) {
    const timestamp = Date.parse(item.measuredAt);
    if (!Number.isFinite(timestamp)) warnings.push('MEASURED_AT_INVALID: 측정 시각이 유효하지 않습니다.');
    else if (timestamp < oldestAllowed) warnings.push('MEASUREMENT_STALE: 운영상 유효기간이 지난 측정입니다.');
    else if (timestamp > latestAllowed) warnings.push('MEASUREMENT_FUTURE: 허용 시각보다 미래의 측정입니다.');
  }

  const fields = ['weightKg', 'bmi', 'bodyFatPct', 'fatMassKg', 'skeletalMuscleMassKg'] as const;
  const validValues = measurements.every((item) => fields.every((field) => Number.isFinite(item[field]) && item[field] > 0) && item.bodyFatPct <= 100 && item.fatMassKg <= item.weightKg && item.skeletalMuscleMassKg <= item.weightKg);
  if (!validValues) warnings.push('MEASUREMENT_VALUE_INVALID: 필수 측정값이 유효하지 않습니다.');
  for (const item of measurements) {
    if (Math.abs(item.fatMassKg / item.weightKg * 100 - item.bodyFatPct) > 1) warnings.push('BODY_FAT_INCONSISTENT: 체지방 값이 일치하지 않습니다.');
    if (Math.abs(item.weightKg / (profile.heightCm / 100) ** 2 - item.bmi) > 0.6) warnings.push('BMI_INCONSISTENT: BMI와 키·체중이 일치하지 않습니다.');
  }
  const average = measurements.length === 4 && validValues ? Object.fromEntries(fields.map((field) => [field, round(mean(measurements.map((item) => item[field])))])) as NonNullable<RecommendationResult['average']> : null;
  const safetyWarnings = [safety.acutePain ? 'SAFETY_ACUTE_PAIN: 현재 통증이 있습니다.' : null, safety.dizziness ? 'SAFETY_DIZZINESS: 어지럼 증상이 있습니다.' : null, safety.clinicianHold ? 'SAFETY_CLINICIAN_HOLD: 전문가 보류 지시가 있습니다.' : null].filter((value): value is string => value !== null);
  if (safetyWarnings.length) return rejected(muscleMassBasis, ruleSet, 'BLOCKED', [...warnings, ...safetyWarnings], average);
  if (warnings.length || !average) return rejected(muscleMassBasis, ruleSet, 'REVIEW', warnings, average);

  const assessment = muscleResearch(measurements.map((item) => item.skeletalMuscleMassKg), profile.heightCm, definitionRule[profile.sex]);
  if (assessment.unstable) return rejected(muscleMassBasis, ruleSet, 'REVIEW', ['MUSCLE_TIER_UNSTABLE: 4건의 등급이 일치하지 않습니다.'], average);
  if (average.bmi < 18.5) return rejected(muscleMassBasis, ruleSet, 'REVIEW', ['BMI_REVIEW: 평균 BMI가 18.5 미만입니다.'], average);
  const candidate = ruleSet.muscle.simulatorCandidates[assessment.level];
  return {
    status: 'READY', executionStatus: 'SIMULATION_READY', dataDecision: 'ACCEPTED', simulationEligibility: 'ELIGIBLE', physicalExecution: 'PROHIBITED', realDeviceSendAllowed: false,
    reasonCodes: ['SIMULATION_ONLY', 'HYPOTHESIS_UNVALIDATED', 'PHYSICAL_EXECUTION_PROHIBITED'], warnings: [], algorithmVersion: ruleSet.version,
    muscleMassBasis, muscleStatistics: assessment.statistics, average,
    muscleAssessment: { heightAdjustedIndex: assessment.heightAdjustedIndex, level: assessment.level, unstable: false },
    recommendation: { ...candidate, purpose: 'SIMULATION_CANDIDATE' }, factors: null,
  };
}

export function applyRequestedIntensity(result: RecommendationResult, requestedIntensityPct: number | undefined, ruleSet: AlgorithmRuleSet = defaultRuleSet): RecommendationResult {
  if (requestedIntensityPct == null || result.recommendation == null) return result;
  if (!Number.isInteger(requestedIntensityPct) || requestedIntensityPct < ruleSet.output.minimumPct || requestedIntensityPct > result.recommendation.intensityPct) throw new RangeError('Requested intensity is outside the simulator-approved range');
  return { ...result, recommendation: { ...result.recommendation, intensityPct: requestedIntensityPct } };
}
