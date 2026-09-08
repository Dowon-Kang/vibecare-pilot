export type Sex = 'female' | 'male';

export type BodyCompositionMeasurement = {
  id: string;
  userId: string;
  measuredAt: string;
  deviceId: string;
  qualityPassed: boolean;
  weightKg: number;
  bmi: number;
  bodyFatPct: number;
  fatMassKg: number;
  skeletalMuscleMassKg: number;
  basalMetabolicRateKcal: number | null;
  bodyWaterPct: number | null;
  proteinKg: number | null;
  mineralKg: number | null;
  ecwRatio: number | null;
  waistCm: number | null;
  visceralFatLevel: number | null;
};

export type Profile = {
  userId: string;
  age: number;
  sex: Sex;
  heightCm: number;
};

export type SafetyAnswers = {
  acutePain: boolean;
  dizziness: boolean;
  clinicianHold: boolean;
};

export type AverageValues = Omit<
  BodyCompositionMeasurement,
  'id' | 'userId' | 'measuredAt' | 'deviceId' | 'qualityPassed'
>;

export type Adjustment = {
  id: string;
  label: string;
  factor: number;
  evidence: 'DIRECT' | 'INDIRECT' | 'PILOT';
  reason: string;
};

export type AlgorithmResult = {
  status: 'READY' | 'REVIEW' | 'BLOCKED';
  averagedValues: AverageValues | null;
  dataWarnings: string[];
  safetyWarnings: string[];
  recommendation: {
    durationSec: number;
    frequencyHz: number;
    intensityPct: number;
    targetAccelerationG: null;
  } | null;
  adjustments: Adjustment[];
  algorithmVersion: string;
  realDeviceSendAllowed: false;
};

export const ALGORITHM_VERSION = 'pilot-0.3.0';
export const REQUIRED_MEASUREMENT_COUNT = 4;

export const PILOT_RULES = {
  base: { durationSec: 300, frequencyHz: 20, intensityPct: 50 },
  age: { threshold: 70, factor: 0.9 },
  sex: { femaleFactor: 0.95, maleFactor: 1 },
  bodyFatReferencePct: {
    female: { minimum: 20, maximum: 35 },
    male: { minimum: 10, maximum: 28 },
  },
  bodyFatOutsideRangeFactor: 0.9,
  output: { minimumPct: 20, maximumPct: 70 },
} as const;

const averageFields: (keyof AverageValues)[] = [
  'weightKg',
  'bmi',
  'bodyFatPct',
  'fatMassKg',
  'skeletalMuscleMassKg',
  'basalMetabolicRateKcal',
  'bodyWaterPct',
  'proteinKg',
  'mineralKg',
  'ecwRatio',
  'waistCm',
  'visceralFatLevel',
];

function round(value: number, digits = 2) {
  const scale = 10 ** digits;
  return Math.round(value * scale) / scale;
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.min(maximum, Math.max(minimum, value));
}

function isFinitePositive(value: number) {
  return Number.isFinite(value) && value > 0;
}

export function averageMeasurements(
  profile: Profile,
  measurements: BodyCompositionMeasurement[],
) {
  const warnings: string[] = [];
  if (!Number.isInteger(profile.age) || profile.age < 18 || profile.age > 100 ||
      !Number.isFinite(profile.heightCm) || profile.heightCm <= 0 ||
      !['female', 'male'].includes(profile.sex) || !profile.userId.trim()) {
    warnings.push('참여자 정보가 유효하지 않습니다.');
  }
  if (new Set(measurements.map((m) => m.id)).size !== measurements.length) warnings.push('중복된 측정 ID가 있습니다.');
  if (measurements.some((m) => !m.id.trim() || !m.deviceId.trim())) warnings.push('측정 ID와 기기 ID가 필요합니다.');

  if (measurements.length !== REQUIRED_MEASUREMENT_COUNT) {
    warnings.push(`측정값은 정확히 ${REQUIRED_MEASUREMENT_COUNT}건이어야 합니다.`);
  }

  if (measurements.some((measurement) => measurement.userId !== profile.userId)) {
    warnings.push('서로 다른 사용자의 측정값이 포함되어 있습니다.');
  }

  const deviceIds = new Set(measurements.map((measurement) => measurement.deviceId));
  if (deviceIds.size > 1) {
    warnings.push('서로 다른 BIA 기기의 측정값이 포함되어 있습니다.');
  }

  if (measurements.some((measurement) => !measurement.qualityPassed)) {
    warnings.push('BIA 품질 검사를 통과하지 못한 측정값이 있습니다.');
  }

  const coreFields = ['weightKg', 'bmi', 'bodyFatPct', 'fatMassKg', 'skeletalMuscleMassKg'] as const;
  const valid = measurements.every((m) => coreFields.every((f) => isFinitePositive(m[f])) &&
    m.bodyFatPct <= 100 && m.fatMassKg <= m.weightKg && m.skeletalMuscleMassKg <= m.weightKg);
  if (!valid) warnings.push('필수 측정값이 유효하지 않습니다.');
  if (measurements.length === 0 || !valid) return { averagedValues: null, warnings };
  const averagedValues = Object.fromEntries(averageFields.map((field) => {
    const values = measurements.map((m) => m[field]);
    return [field, values.some((v) => v == null || !Number.isFinite(v) || v < 0)
      ? null : round((values as number[]).reduce((a, b) => a + b, 0) / values.length)];
  })) as AverageValues;

  measurements.forEach((measurement, index) => {
    const calculatedBodyFatPct = (measurement.fatMassKg / measurement.weightKg) * 100;
    if (Math.abs(calculatedBodyFatPct - measurement.bodyFatPct) > 1) {
      warnings.push(`${index + 1}회 측정의 체지방률과 체지방량이 일치하지 않습니다.`);
    }

    const heightM = profile.heightCm / 100;
    const calculatedBmi = measurement.weightKg / heightM ** 2;
    if (Math.abs(calculatedBmi - measurement.bmi) > 0.6) {
      warnings.push(`${index + 1}회 측정의 BMI와 키·체중이 일치하지 않습니다.`);
    }
  });

  return { averagedValues, warnings: [...new Set(warnings)] };
}

export function calculateVibrationRecommendation(
  profile: Profile,
  measurements: BodyCompositionMeasurement[],
  safety: SafetyAnswers,
): AlgorithmResult {
  const { averagedValues, warnings: dataWarnings } = averageMeasurements(
    profile,
    measurements,
  );
  const safetyWarnings: string[] = [];

  if (safety.acutePain) safetyWarnings.push('현재 통증이 있어 실제 기기 전달을 차단합니다.');
  if (safety.dizziness) safetyWarnings.push('어지럼 증상이 있어 실제 기기 전달을 차단합니다.');
  if (safety.clinicianHold) safetyWarnings.push('전문가 사용 보류 지시가 있습니다.');

  if (!averagedValues || dataWarnings.length > 0 || safetyWarnings.length > 0) {
    return {
      status: safetyWarnings.length > 0 ? 'BLOCKED' : 'REVIEW',
      averagedValues,
      dataWarnings,
      safetyWarnings,
      recommendation: null,
      adjustments: [],
      algorithmVersion: ALGORITHM_VERSION,
      realDeviceSendAllowed: false,
    };
  }

  const bodyFatReference = PILOT_RULES.bodyFatReferencePct[profile.sex];
  const bodyFatOutsideReference = averagedValues.bodyFatPct < bodyFatReference.minimum
    || averagedValues.bodyFatPct > bodyFatReference.maximum;
  const sexFactor = profile.sex === 'female'
    ? PILOT_RULES.sex.femaleFactor
    : PILOT_RULES.sex.maleFactor;

  const adjustments: Adjustment[] = [
    {
      id: 'AGE_70_PILOT',
      label: '연령 보정',
      factor: profile.age >= PILOT_RULES.age.threshold ? PILOT_RULES.age.factor : 1,
      evidence: 'PILOT',
      reason:
        profile.age >= PILOT_RULES.age.threshold
          ? '70세 이상 10% 감산은 검증 전 파일럿 규칙입니다.'
          : '파일럿 연령 감산 조건에 해당하지 않습니다.',
    },
    {
      id: 'SEX_RESPONSE_PILOT',
      label: '성별 보정',
      factor: sexFactor,
      evidence: 'PILOT',
      reason: profile.sex === 'female'
        ? '여성 5% 감산은 성별 반응 차이를 검증하기 위한 보수적 파일럿 규칙입니다.'
        : '남성 기준계수 1.00을 적용했습니다.',
    },
    {
      id: 'BODY_FAT_RANGE_PILOT',
      label: '체지방 보정',
      factor: bodyFatOutsideReference ? PILOT_RULES.bodyFatOutsideRangeFactor : 1,
      evidence: 'PILOT',
      reason: bodyFatOutsideReference
        ? `${profile.sex === 'female' ? '여성' : '남성'} 파일럿 참고범위 ${bodyFatReference.minimum}~${bodyFatReference.maximum}% 밖이므로 10% 감산합니다.`
        : `${profile.sex === 'female' ? '여성' : '남성'} 파일럿 참고범위 안이므로 감산하지 않습니다.`,
    },
  ];

  const reviewReasons: string[] = [];
  if (averagedValues.bmi < 18.5) {
    reviewReasons.push('평균 BMI가 18.5 미만이므로 관리자 검토가 필요합니다.');
  }

  const intensityFactor = adjustments.reduce((product, item) => product * item.factor, 1);
  const recommendation = {
    durationSec: PILOT_RULES.base.durationSec,
    frequencyHz: PILOT_RULES.base.frequencyHz,
    intensityPct: Math.round(clamp(
      PILOT_RULES.base.intensityPct * intensityFactor,
      PILOT_RULES.output.minimumPct,
      PILOT_RULES.output.maximumPct,
    )),
    targetAccelerationG: null,
  } as const;

  return {
    status: reviewReasons.length > 0 ? 'REVIEW' : 'READY',
    averagedValues,
    dataWarnings: reviewReasons,
    safetyWarnings,
    recommendation,
    adjustments,
    algorithmVersion: ALGORITHM_VERSION,
    realDeviceSendAllowed: false,
  };
}

export function createMockCommand(profile: Profile, result: AlgorithmResult) {
  return {
    commandType: 'VIBRATION_RECOMMENDATION_PREVIEW',
    userId: profile.userId,
    status: result.status,
    recommendation: result.recommendation,
    adjustments: result.adjustments,
    warnings: [...result.dataWarnings, ...result.safetyWarnings],
    algorithmVersion: result.algorithmVersion,
    approvalRequired: result.status !== 'READY',
    realDeviceSendAllowed: result.realDeviceSendAllowed,
    createdAt: new Date().toISOString(),
  };
}
