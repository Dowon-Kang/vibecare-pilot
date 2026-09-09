import { muscleResearch, executionStatus, researchReasons, evidenceLabels, type ExecutionStatus } from '../../shared-contracts/muscle-research.ts';
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
  executionStatus: ExecutionStatus;
  reasonCodes: string[];
  evidence: typeof evidenceLabels;
  muscleStatistics: ReturnType<typeof muscleResearch>['statistics'] | null;
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
  muscleAssessment: {
    totalSmmi: number;
    level: 'low' | 'medium' | 'reference';
  } | null;
  algorithmVersion: string;
  realDeviceSendAllowed: false;
};

export const ALGORITHM_VERSION = 'pilot-0.6.0';
export const REQUIRED_MEASUREMENT_COUNT = 4;

export const PILOT_RULES = {
  base: { durationSec: 300, frequencyHz: 20, intensityPct: 50 },
  age: { threshold: 70, factor: 1 },
  sex: { femaleFactor: 1, maleFactor: 1 },
  bodyFatReferencePct: {
    female: { minimum: 20, maximum: 35 },
    male: { minimum: 10, maximum: 28 },
  },
  bodyFatOutsideRangeFactor: 1,
  muscle: {
    female: { lowMaximum: 5.75, mediumMaximum: 6.75 },
    male: { lowMaximum: 8.5, mediumMaximum: 10.75 },
    protocols: {
      low: { durationSec: 180, frequencyHz: 12, intensityPct: 30 },
      medium: { durationSec: 240, frequencyHz: 16, intensityPct: 40 },
      reference: { durationSec: 300, frequencyHz: 20, intensityPct: 50 },
    },
  },
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
      !Number.isFinite(profile.heightCm) || profile.heightCm < 100 || profile.heightCm > 250 ||
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
  if (measurements.length !== 4 || !valid) return { averagedValues: null, warnings };
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
      muscleAssessment: null,
      executionStatus: executionStatus(safetyWarnings.length ? 'BLOCKED' : 'REVIEW', measurements.length),
      reasonCodes: researchReasons(safetyWarnings.length ? 'BLOCKED' : 'REVIEW', measurements.length),
      evidence: evidenceLabels, muscleStatistics: null,
      algorithmVersion: ALGORITHM_VERSION,
      realDeviceSendAllowed: false,
    };
  }

  const thresholds = PILOT_RULES.muscle[profile.sex];
  const assessment = muscleResearch(measurements.map(m=>m.skeletalMuscleMassKg), profile.heightCm, thresholds);
  const {totalSmmi, level:muscleLevel} = assessment;
  const protocol = PILOT_RULES.muscle.protocols[muscleLevel];
  const muscleLabel = muscleLevel === 'low'
    ? '낮은 근육량'
    : muscleLevel === 'medium' ? '중간 근육량' : '참조 이상 근육량';

  const adjustments: Adjustment[] = [
    {
      id: 'TOTAL_SMMI_PROTOCOL_RESEARCH',
      label: '근육량 기본값',
      factor: protocol.intensityPct / PILOT_RULES.base.intensityPct,
      evidence: 'PILOT',
      reason: `추정 근육지수 ${totalSmmi.toFixed(2)}kg/m², 연구 등급 ${muscleLabel}에 따라 시연 조건 ${protocol.frequencyHz}Hz·${protocol.durationSec}초·${protocol.intensityPct}%를 선택했습니다. 측정법 동등성과 최적 자극은 검증되지 않았습니다.`,
    },
    {
      id: 'AGE_70_PILOT',
      label: '추가 감산 없음',
      factor: profile.age >= PILOT_RULES.age.threshold ? PILOT_RULES.age.factor : 1,
      evidence: 'PILOT',
      reason:
        profile.age >= PILOT_RULES.age.threshold
          ? '임상 근거가 없는 나이별 일괄 감산을 제거했습니다.'
          : '추가 나이 계수를 적용하지 않습니다.',
    },
  ];

  const reviewReasons: string[] = [];
  if (!Object.values(safety).every(v=>typeof v==='boolean') || Object.keys(safety).length!==3) reviewReasons.push('안전 문진을 완료해 주세요.');
  if (profile.age < 60) reviewReasons.push('60세 이상 연구 대상 범위 밖입니다.');
  if (assessment.unstable) reviewReasons.push('반복 측정의 근육지수 등급이 달라 검토가 필요합니다.');
  if (measurements.reduce((s,m)=>s+m.bmi,0)/4 < 18.5) {
    reviewReasons.push('평균 BMI가 18.5 미만이므로 관리자 검토가 필요합니다.');
  }

  const ageFactor = profile.age >= PILOT_RULES.age.threshold ? PILOT_RULES.age.factor : 1;
  const recommendation = {
    durationSec: Math.round(protocol.durationSec * ageFactor),
    frequencyHz: protocol.frequencyHz,
    intensityPct: Math.round(clamp(
      protocol.intensityPct * ageFactor,
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
    muscleAssessment: { totalSmmi, level: muscleLevel },
    muscleStatistics: assessment.statistics,
    evidence: evidenceLabels,
    executionStatus: executionStatus(reviewReasons.length ? 'REVIEW' : 'READY', measurements.length),
    reasonCodes: researchReasons(reviewReasons.length ? 'REVIEW' : 'READY', measurements.length, assessment.unstable),
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
