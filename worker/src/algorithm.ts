export type Sex = 'female' | 'male';

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
  ruleSet?: AlgorithmRuleSet;
};

export type AlgorithmRuleSet = {
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
};

export const defaultRuleSet: AlgorithmRuleSet = {
  version: 'pilot-0.3.0',
  activeFrom: '2026-09-03T00:00:00Z',
  enabled: true,
  base: { durationSec: 300, frequencyHz: 20, intensityPct: 50 },
  age: { threshold: 70, factor: 0.9 },
  sex: { femaleFactor: 0.95, maleFactor: 1 },
  bodyFat: {
    female: { minimum: 20, maximum: 35 },
    male: { minimum: 10, maximum: 28 },
    outsideRangeFactor: 0.9,
  },
  output: { minimumPct: 20, maximumPct: 70 },
};

export type RecommendationResult = {
  status: 'READY' | 'REVIEW' | 'BLOCKED';
  average: null | {
    weightKg: number;
    bmi: number;
    bodyFatPct: number;
    fatMassKg: number;
    skeletalMuscleMassKg: number;
  };
  recommendation: null | { durationSec: number; frequencyHz: number; intensityPct: number };
  factors: { age: number; sex: number; bodyFat: number } | null;
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
  const ruleSet = input.ruleSet ?? defaultRuleSet;
  const warnings: string[] = [];
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
  if (measurements.some((item) => fields.some((field) => !Number.isFinite(item[field]) || item[field] <= 0))) {
    warnings.push('필수 측정값이 유효하지 않습니다.');
  }

  const average = measurements.length === 0 ? null : Object.fromEntries(
    fields.map((field) => [field, round(mean(measurements.map((item) => item[field])))])
  ) as NonNullable<RecommendationResult['average']>;

  const safetyWarnings = [
    safety.acutePain ? '현재 통증이 있습니다.' : null,
    safety.dizziness ? '어지럼 증상이 있습니다.' : null,
    safety.clinicianHold ? '전문가 사용 보류 지시가 있습니다.' : null,
  ].filter((item): item is string => item !== null);

  if (warnings.length || safetyWarnings.length || !average) {
    return {
      status: safetyWarnings.length ? 'BLOCKED' : 'REVIEW',
      average,
      recommendation: null,
      factors: null,
      warnings: [...new Set([...warnings, ...safetyWarnings])],
      algorithmVersion: ruleSet.version,
    };
  }

  const ageFactor = profile.age >= ruleSet.age.threshold ? ruleSet.age.factor : 1;
  const sexFactor = profile.sex === 'female' ? ruleSet.sex.femaleFactor : ruleSet.sex.maleFactor;
  const range = profile.sex === 'female' ? ruleSet.bodyFat.female : ruleSet.bodyFat.male;
  const bodyFatFactor = average.bodyFatPct < range.minimum || average.bodyFatPct > range.maximum
    ? ruleSet.bodyFat.outsideRangeFactor
    : 1;
  const intensityPct = Math.round(Math.min(
    ruleSet.output.maximumPct,
    Math.max(
      ruleSet.output.minimumPct,
      ruleSet.base.intensityPct * ageFactor * sexFactor * bodyFatFactor,
    ),
  ));
  const reviewWarnings = average.bmi < 18.5
    ? ['평균 BMI가 18.5 미만이므로 전문가 검토가 필요합니다.']
    : [];

  return {
    status: reviewWarnings.length ? 'REVIEW' : 'READY',
    average,
    recommendation: {
      durationSec: ruleSet.base.durationSec,
      frequencyHz: ruleSet.base.frequencyHz,
      intensityPct,
    },
    factors: { age: ageFactor, sex: sexFactor, bodyFat: bodyFatFactor },
    warnings: reviewWarnings,
    algorithmVersion: ruleSet.version,
  };
}
