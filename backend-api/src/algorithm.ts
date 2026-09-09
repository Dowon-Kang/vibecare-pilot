import { ruleSchema } from './rule-schema';
import { muscleResearch, executionStatus, researchReasons, evidenceLabels, type ExecutionStatus } from '../../shared-contracts/muscle-research';

export type Sex = 'female' | 'male';
export type MuscleMassBasis = 'ASM' | 'SMM';

export type CanonicalMeasurement = {
  id: string;
  participantId: string;
  deviceId: string;
  qualityPassed: boolean;
  weightKg: number;
  bmi: number;
  bodyFatPct: number;
  fatMassKg: number;
  skeletalMuscleMassKg: number;
};

export type AlgorithmInput = {
  profile: { participantId: string; age: number; sex: Sex; heightCm: number };
  measurements: CanonicalMeasurement[];
  safety: { acutePain: boolean; dizziness: boolean; clinicianHold: boolean };
  muscleMassBasis?: MuscleMassBasis;
  ruleSet?: AlgorithmRuleSet;
};

export type AlgorithmRuleSet = {
  research: { mode: 'simulation_only'; measurementDefinition: 'unverified'; protocolEvidence: 'PILOT' };
  version: string;
  activeFrom: string;
  enabled: boolean;
  base: { durationSec: number; frequencyHz: number; intensityPct: number };
  age: { threshold: number; factor: number };
  sex: { femaleFactor: number; maleFactor: number };
  bodyFat: {
    female: { minimum: number; maximum: number };
    male: { minimum: number; maximum: number };
    outsideRangeFactor: number;
  };
  output: { minimumPct: number; maximumPct: number };
  muscle: {
    female: { lowMaximum: number; mediumMaximum: number };
    male: { lowMaximum: number; mediumMaximum: number };
    protocols: {
      low: { durationSec: number; frequencyHz: number; intensityPct: number };
      medium: { durationSec: number; frequencyHz: number; intensityPct: number };
      reference: { durationSec: number; frequencyHz: number; intensityPct: number };
    };
  };
};

export const defaultRuleSet: AlgorithmRuleSet = {
  version: 'pilot-0.6.0',
  research: {mode:'simulation_only',measurementDefinition:'unverified',protocolEvidence:'PILOT'},
  activeFrom: '2026-09-08T00:00:00Z',
  enabled: true,
  base: { durationSec: 300, frequencyHz: 20, intensityPct: 50 },
  age: { threshold: 70, factor: 1 },
  sex: { femaleFactor: 1, maleFactor: 1 },
  bodyFat: {
    female: { minimum: 20, maximum: 35 },
    male: { minimum: 10, maximum: 28 },
    outsideRangeFactor: 1,
  },
  output: { minimumPct: 20, maximumPct: 70 },
  muscle: {
    female: { lowMaximum: 5.75, mediumMaximum: 6.75 },
    male: { lowMaximum: 8.5, mediumMaximum: 10.75 },
    protocols: {
      low: { durationSec: 180, frequencyHz: 12, intensityPct: 30 },
      medium: { durationSec: 240, frequencyHz: 16, intensityPct: 40 },
      reference: { durationSec: 300, frequencyHz: 20, intensityPct: 50 },
    },
  },
};

export type RecommendationResult = {
  executionStatus: ExecutionStatus;
  realDeviceSendAllowed: false;
  reasonCodes: string[];
  evidence: typeof evidenceLabels;
  muscleMassBasis: MuscleMassBasis;
  muscleStatistics: ReturnType<typeof muscleResearch>['statistics'] | null;
  status: 'READY' | 'REVIEW' | 'BLOCKED';
  average: null | {
    weightKg: number;
    bmi: number;
    bodyFatPct: number;
    fatMassKg: number;
    skeletalMuscleMassKg: number;
  };
  recommendation: null | { durationSec: number; frequencyHz: number; intensityPct: number };
  factors: { age: number; muscleProtocol: number } | null;
  muscleAssessment: { totalSmmi: number; level: 'low' | 'medium' | 'reference' } | null;
  warnings: string[];
  algorithmVersion: string;
};

const round = (value: number, digits = 2) => {
  const scale = 10 ** digits;
  return Math.round(value * scale) / scale;
};

const mean = (values: number[]) => values.reduce((sum, value) => sum + value, 0) / values.length;

export function calculateRecommendation(input: AlgorithmInput): RecommendationResult {
  const { profile, measurements, safety } = input;
  const muscleMassBasis = input.muscleMassBasis ?? 'SMM';
  const ruleSet = input.ruleSet ?? defaultRuleSet;
  const warnings: string[] = [];
  if (!ruleSchema.safeParse(ruleSet).success) warnings.push('사용 가능한 유효한 계산 규칙이 없습니다.');
  if (!Number.isInteger(profile.age) || profile.age < 18 || profile.age > 100 ||
      !Number.isFinite(profile.heightCm) || profile.heightCm < 100 || profile.heightCm > 250 ||
      !['female', 'male'].includes(profile.sex) || !profile.participantId.trim()) {
    warnings.push('참여자 정보가 유효하지 않습니다.');
  }
  if (measurements.length !== 4) warnings.push('측정값은 정확히 4건이어야 합니다.');
  if (measurements.some((item) => item.participantId !== profile.participantId)) {
    warnings.push('서로 다른 사용자의 측정값이 포함되어 있습니다.');
  }
  if (new Set(measurements.map((item) => item.deviceId)).size > 1) {
    warnings.push('서로 다른 BIA 기기의 측정값이 포함되어 있습니다.');
  }
  if (new Set(measurements.map((item) => item.id)).size !== measurements.length) {
    warnings.push('중복된 측정 ID가 있습니다.');
  }
  if (measurements.some((item) => !item.qualityPassed)) {
    warnings.push('BIA 품질 검사를 통과하지 못한 값이 있습니다.');
  }

  const fields = ['weightKg', 'bmi', 'bodyFatPct', 'fatMassKg', 'skeletalMuscleMassKg'] as const;
  const validValues = measurements.every((item) =>
    fields.every((field) => Number.isFinite(item[field]) && item[field] > 0) &&
    item.bodyFatPct <= 100 && item.fatMassKg <= item.weightKg &&
    item.skeletalMuscleMassKg <= item.weightKg);
  if (!validValues) {
    warnings.push('필수 측정값이 유효하지 않습니다.');
  }

  for (const item of measurements) {
    if (!item.id.trim() || !item.deviceId.trim()) warnings.push('측정 ID와 기기 ID가 필요합니다.');
    if (Math.abs(item.fatMassKg / item.weightKg * 100 - item.bodyFatPct) > 1) {
      warnings.push('체지방률과 체지방량이 일치하지 않습니다.');
    }
    if (Math.abs(item.weightKg / (profile.heightCm / 100) ** 2 - item.bmi) > 0.6) {
      warnings.push('BMI와 키·체중이 일치하지 않습니다.');
    }
  }

  const average = measurements.length !== 4 || !validValues ? null : Object.fromEntries(
    fields.map((field) => [field, round(mean(measurements.map((item) => item[field])))])
  ) as NonNullable<RecommendationResult['average']>;

  const safetyWarnings = [
    safety.acutePain ? '현재 통증이 있습니다.' : null,
    safety.dizziness ? '어지럼 증상이 있습니다.' : null,
    safety.clinicianHold ? '전문가 사용 보류 지시가 있습니다.' : null,
  ].filter((item): item is string => item !== null);
  const safetyComplete = ['acutePain','dizziness','clinicianHold'].every(key =>
    typeof safety[key as keyof typeof safety] === 'boolean');

  if (warnings.length || safetyWarnings.length || !average) {
    return {
      executionStatus: executionStatus(safetyWarnings.length ? 'BLOCKED' : 'REVIEW', measurements.length),
      realDeviceSendAllowed: false,
      reasonCodes: researchReasons(safetyWarnings.length ? 'BLOCKED' : 'REVIEW', measurements.length),
      evidence: evidenceLabels, muscleStatistics: null,
      muscleMassBasis,
      status: safetyWarnings.length ? 'BLOCKED' : 'REVIEW',
      average,
      recommendation: null,
      factors: null,
      muscleAssessment: null,
      warnings: [...new Set([...warnings, ...safetyWarnings])],
      algorithmVersion: ruleSet.version,
    };
  }

  const thresholds = ruleSet.muscle[profile.sex];
  const muscleValues = measurements.map(m=>m.skeletalMuscleMassKg);
  const assessment = muscleResearch(muscleValues, profile.heightCm, thresholds);
  const {totalSmmi} = assessment;
  // AWGS 2025 height-adjusted ASM cut-offs for BIA. This branch remains an
  // explicit assumption until the provider confirms that its field is ASM.
  const asmCutoff = profile.sex === 'female' ? 5.7 : profile.age >= 65 ? 7.0 : 7.6;
  const level: 'low' | 'medium' | 'reference' = muscleMassBasis === 'ASM'
    ? totalSmmi < asmCutoff ? 'low' : 'medium'
    : assessment.level;
  const heightSquared = (profile.heightCm / 100) ** 2;
  const unstable = muscleMassBasis === 'ASM'
    ? new Set(muscleValues.map(value => value / heightSquared < asmCutoff ? 'low' : 'medium')).size > 1
    : assessment.unstable;
  const protocol = ruleSet.muscle.protocols[level];
  const ageFactor = profile.age >= ruleSet.age.threshold ? ruleSet.age.factor : 1;
  const intensityPct = Math.round(Math.min(
    ruleSet.output.maximumPct,
    Math.max(
      ruleSet.output.minimumPct,
      protocol.intensityPct * ageFactor,
    ),
  ));
  const reviewWarnings = [
    ...(!safetyComplete ? ['안전 문진을 완료해 주세요.'] : []),
    ...(mean(measurements.map(m=>m.bmi)) < 18.5 ? ['평균 BMI가 18.5 미만이므로 전문가 검토가 필요합니다.'] : []),
    ...(profile.age < 60 ? ['60세 이상 연구 대상 범위 밖입니다.'] : []),
    ...(unstable ? ['반복 측정의 근육지수 등급이 달라 재측정과 검토가 필요합니다.'] : []),
  ];

  return {
    status: reviewWarnings.length ? 'REVIEW' : 'READY',
    executionStatus: executionStatus(reviewWarnings.length ? 'REVIEW' : 'READY', measurements.length),
    realDeviceSendAllowed: false,
    reasonCodes: researchReasons(reviewWarnings.length ? 'REVIEW' : 'READY', measurements.length, unstable),
    evidence: evidenceLabels, muscleStatistics: assessment.statistics,
    average,
    recommendation: {
      durationSec: Math.round(protocol.durationSec * ageFactor),
      frequencyHz: protocol.frequencyHz,
      intensityPct,
    },
    factors: { age: ageFactor, muscleProtocol: protocol.intensityPct / ruleSet.base.intensityPct },
    muscleMassBasis,
    muscleAssessment: { totalSmmi, level },
    warnings: reviewWarnings,
    algorithmVersion: ruleSet.version,
  };
}

export function applyRequestedIntensity(
  result: RecommendationResult,
  requestedIntensityPct: number | undefined,
  ruleSet: AlgorithmRuleSet = defaultRuleSet,
): RecommendationResult {
  if (requestedIntensityPct == null || result.recommendation == null) return result;
  if (
    !Number.isInteger(requestedIntensityPct) ||
    requestedIntensityPct < ruleSet.output.minimumPct ||
    requestedIntensityPct > result.recommendation.intensityPct
  ) {
    throw new RangeError('Requested intensity is outside the server-approved range');
  }
  return {
    ...result,
    recommendation: {
      ...result.recommendation,
      intensityPct: requestedIntensityPct,
    },
  };
}
