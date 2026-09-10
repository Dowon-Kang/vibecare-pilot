import 'dart:math' as math;

import '../models/models.dart';

const algorithmVersion = 'pilot-0.7.0';
const requiredMeasurementCount = 4;

/// Research-simulator rules. These values are hypotheses, not a clinical
/// prescription and never authorize physical vibration output.
const pilotRuleSet = AlgorithmRuleSet(
  version: algorithmVersion,
  enabled: true,
  durationSec: 300,
  frequencyHz: 20,
  baseIntensityPct: 50,
  ageThreshold: 70,
  ageFactor: 1,
  femaleFactor: 1,
  maleFactor: 1,
  femaleBodyFat: BodyFatRange(20, 35),
  maleBodyFat: BodyFatRange(10, 28),
  outsideBodyFatFactor: 1,
  minimumPct: 20,
  maximumPct: 70,
  femaleMuscleThresholds: MuscleThresholds(
    lowMaximum: 5.75,
    mediumMaximum: 6.75,
  ),
  maleMuscleThresholds: MuscleThresholds(lowMaximum: 8.5, mediumMaximum: 10.75),
  asmFemaleMuscleThresholds: MuscleThresholds(
    lowMaximum: 5.7,
    mediumMaximum: 6.7,
  ),
  asmMaleMuscleThresholds: MuscleThresholds(lowMaximum: 7, mediumMaximum: 8),
  lowMuscleProtocol: ProtocolPreset(
    durationSec: 180,
    frequencyHz: 12,
    intensityPct: 30,
  ),
  mediumMuscleProtocol: ProtocolPreset(
    durationSec: 240,
    frequencyHz: 16,
    intensityPct: 40,
  ),
  referenceMuscleProtocol: ProtocolPreset(
    durationSec: 300,
    frequencyHz: 20,
    intensityPct: 50,
  ),
);

double _round(double value, int digits) {
  final scale = math.pow(10, digits).toDouble();
  return (value * scale).round() / scale;
}

double _mean(Iterable<double> values) {
  final list = values.toList(growable: false);
  return list.reduce((a, b) => a + b) / list.length;
}

double? _optionalMean(Iterable<double?> values) {
  final list = values.toList(growable: false);
  if (list.length != requiredMeasurementCount ||
      list.any((value) => value == null || !value.isFinite || value < 0)) {
    return null;
  }
  return _round(_mean(list.cast<double>()), 2);
}

bool _hasValidCoreValues(BiaMeasurement measurement) =>
    measurement.values.requiredValues.every(
      (value) => value.isFinite && value > 0,
    ) &&
    measurement.values.bodyFatPct <= 100 &&
    measurement.values.fatMassKg <= measurement.values.weightKg &&
    measurement.values.skeletalMuscleMassKg <= measurement.values.weightKg;

List<BiaMeasurement> selectLatestValidMeasurements({
  required String participantId,
  required String deviceId,
  required Iterable<BiaMeasurement> candidates,
}) {
  final byId = <String, BiaMeasurement>{};
  for (final measurement in candidates) {
    if (measurement.participantId != participantId ||
        measurement.deviceId != deviceId ||
        !measurement.qualityPassed ||
        !_hasValidCoreValues(measurement)) {
      continue;
    }
    final previous = byId[measurement.id];
    if (previous == null ||
        measurement.measuredAt.isAfter(previous.measuredAt)) {
      byId[measurement.id] = measurement;
    }
  }
  final sorted = byId.values.toList()
    ..sort((a, b) {
      final time = b.measuredAt.compareTo(a.measuredAt);
      return time == 0 ? b.id.compareTo(a.id) : time;
    });
  return sorted.take(requiredMeasurementCount).toList(growable: false);
}

AlgorithmResult calculateRecommendation({
  required ParticipantProfile profile,
  required List<BiaMeasurement> measurements,
  required SafetyCheck safety,
  MuscleMassBasis muscleMassBasis = MuscleMassBasis.smm,
  AlgorithmRuleSet ruleSet = pilotRuleSet,
  DateTime? evaluatedAt,
}) {
  final warnings = <String>[];
  final now = evaluatedAt ?? DateTime.now();
  final thresholds = [
    ruleSet.asmFemaleMuscleThresholds,
    ruleSet.asmMaleMuscleThresholds,
    ruleSet.femaleMuscleThresholds,
    ruleSet.maleMuscleThresholds,
  ];
  final presets = [
    ruleSet.lowMuscleProtocol,
    ruleSet.mediumMuscleProtocol,
    ruleSet.referenceMuscleProtocol,
  ];

  if (!ruleSet.enabled ||
      ruleSet.version != algorithmVersion ||
      ruleSet.policyBasis != 'ENGINEERING_POLICY' ||
      ruleSet.physicalExecution != 'PROHIBITED' ||
      ruleSet.asmClassificationEvidence != 'HYPOTHESIS_UNVALIDATED' ||
      !const {
        'INDIRECT',
        'HYPOTHESIS_UNVALIDATED',
      }.contains(ruleSet.smmClassificationEvidence) ||
      ruleSet.maximumAgeDays <= 0 ||
      ruleSet.maximumFutureSkewMinutes < 0 ||
      ruleSet.minimumPct < 0 ||
      ruleSet.maximumPct > 100 ||
      ruleSet.minimumPct > ruleSet.maximumPct ||
      thresholds.any(
        (value) =>
            !value.lowMaximum.isFinite ||
            !value.mediumMaximum.isFinite ||
            value.lowMaximum <= 0 ||
            value.lowMaximum >= value.mediumMaximum,
      ) ||
      presets.any(
        (value) =>
            value.durationSec <= 0 ||
            value.frequencyHz <= 0 ||
            !value.intensityPct.isFinite ||
            value.intensityPct < ruleSet.minimumPct ||
            value.intensityPct > ruleSet.maximumPct ||
            value.evidence != 'HYPOTHESIS_UNVALIDATED',
      )) {
    warnings.add('RULE_INVALID: 사용 가능한 연구 규칙이 없습니다.');
  }
  if (profile.id.trim().isEmpty ||
      profile.age < 18 ||
      profile.age > 100 ||
      !profile.heightCm.isFinite ||
      profile.heightCm < 100 ||
      profile.heightCm > 250) {
    warnings.add('PROFILE_INVALID: 참여자 정보가 유효하지 않습니다.');
  }
  if (muscleMassBasis == MuscleMassBasis.unknown) {
    warnings.add('MUSCLE_BASIS_UNKNOWN: 계산 기준이 확인되지 않았습니다.');
  }
  if (measurements.length != requiredMeasurementCount) {
    warnings.add('MEASUREMENT_COUNT_INVALID: 최근 유효 측정값이 정확히 4건 필요합니다.');
  }
  if (measurements.any((m) => m.participantId != profile.id)) {
    warnings.add('PARTICIPANT_MIXED: 다른 참여자의 측정값이 포함되었습니다.');
  }
  if (measurements.map((m) => m.deviceId).toSet().length != 1) {
    warnings.add('DEVICE_MIXED: 서로 다른 BIA 기기의 값이 포함되었습니다.');
  }
  if (measurements.map((m) => m.id).toSet().length != measurements.length) {
    warnings.add('MEASUREMENT_DUPLICATED: 중복 측정 ID가 있습니다.');
  }
  if (measurements.any((m) => !m.qualityPassed)) {
    warnings.add('QUALITY_FAILED: 품질 검사를 통과하지 못한 값이 있습니다.');
  }
  if (measurements.any((m) => !_hasValidCoreValues(m))) {
    warnings.add('MEASUREMENT_VALUE_INVALID: 필수 측정값이 유효하지 않습니다.');
  }

  final definitions = measurements.map((m) => m.muscleDefinition).toSet();
  if (definitions.contains(MuscleMassBasis.unknown)) {
    warnings.add('MUSCLE_DEFINITION_UNKNOWN: 공급사 근육량 정의가 확인되지 않았습니다.');
  }
  if (definitions.length != 1) {
    warnings.add('MUSCLE_DEFINITION_MIXED: 서로 다른 근육량 정의가 섞였습니다.');
  }
  if (definitions.any((definition) => definition != muscleMassBasis)) {
    warnings.add('MUSCLE_BASIS_MISMATCH: 선택 기준과 측정 정의가 다릅니다.');
  }
  if (measurements.any((m) => m.muscleMassUnit != 'kg')) {
    warnings.add('MUSCLE_UNIT_INVALID: 근육량 단위가 kg이 아닙니다.');
  }
  if (measurements.map((m) => m.muscleMeasurementMethod).toSet().length != 1) {
    warnings.add('METHOD_MIXED: 측정 방법이 섞였습니다.');
  }
  if (measurements.any(
    (m) =>
        m.muscleMeasurementMethod.trim().isEmpty ||
        m.muscleMeasurementMethod == 'UNKNOWN',
  )) {
    warnings.add('METHOD_UNKNOWN: 측정 방법이 확인되지 않았습니다.');
  }
  if (measurements.map((m) => m.methodEvidenceRef).toSet().length != 1 ||
      measurements.any((m) => m.methodEvidenceRef.trim().isEmpty)) {
    warnings.add('METHOD_EVIDENCE_INVALID: 측정 방법 근거가 없거나 서로 다릅니다.');
  }
  if (measurements.map((m) => m.definitionRef).toSet().length != 1 ||
      measurements.any((m) => m.definitionRef.trim().isEmpty)) {
    warnings.add('DEFINITION_REF_INVALID: 근육량 정의 문서가 없거나 서로 다릅니다.');
  }
  if (measurements.map((m) => m.acquisitionProtocolRef).toSet().length != 1) {
    warnings.add('ACQUISITION_PROTOCOL_MIXED: 획득 프로토콜이 섞였습니다.');
  }
  if (measurements.any(
    (m) =>
        m.acquisitionProtocolRef.trim().isEmpty ||
        m.acquisitionProtocolRef == 'UNKNOWN',
  )) {
    warnings.add('ACQUISITION_PROTOCOL_UNKNOWN: 획득 프로토콜이 확인되지 않았습니다.');
  }
  if (muscleMassBasis != MuscleMassBasis.unknown && measurements.isNotEmpty) {
    final applicableMethods = muscleMassBasis == MuscleMassBasis.asm
        ? ruleSet.asmApplicableMethods
        : ruleSet.smmApplicableMethods;
    final first = measurements.first;
    if (!applicableMethods.any(
      (item) =>
          item.method == first.muscleMeasurementMethod &&
          item.methodEvidenceRef == first.methodEvidenceRef &&
          item.definitionRef == first.definitionRef,
    )) {
      warnings.add('METHOD_NOT_APPLICABLE: 규칙에서 검토된 측정 방법이 아닙니다.');
    }
  }

  final oldest = now.subtract(Duration(days: ruleSet.maximumAgeDays));
  final latest = now.add(Duration(minutes: ruleSet.maximumFutureSkewMinutes));
  for (final measurement in measurements) {
    if (measurement.measuredAt.isBefore(oldest)) {
      warnings.add('MEASUREMENT_STALE: 운영 유효기간이 지난 측정입니다.');
    }
    if (measurement.measuredAt.isAfter(latest)) {
      warnings.add('MEASUREMENT_FUTURE: 허용 시각보다 미래의 측정입니다.');
    }
    if (_hasValidCoreValues(measurement)) {
      final bodyFat =
          measurement.values.fatMassKg / measurement.values.weightKg * 100;
      if ((bodyFat - measurement.values.bodyFatPct).abs() > 1) {
        warnings.add('BODY_FAT_INCONSISTENT: 체지방 값이 일치하지 않습니다.');
      }
      final calculatedBmi =
          measurement.values.weightKg / math.pow(profile.heightCm / 100, 2);
      if ((calculatedBmi - measurement.values.bmi).abs() > 0.6) {
        warnings.add('BMI_INCONSISTENT: BMI와 키·체중이 일치하지 않습니다.');
      }
    }
  }

  final average =
      measurements.length == requiredMeasurementCount &&
          measurements.every(_hasValidCoreValues)
      ? BiaValues(
          weightKg: _round(
            _mean(measurements.map((m) => m.values.weightKg)),
            2,
          ),
          bmi: _round(_mean(measurements.map((m) => m.values.bmi)), 2),
          bodyFatPct: _round(
            _mean(measurements.map((m) => m.values.bodyFatPct)),
            2,
          ),
          fatMassKg: _round(
            _mean(measurements.map((m) => m.values.fatMassKg)),
            2,
          ),
          skeletalMuscleMassKg: _round(
            _mean(measurements.map((m) => m.values.skeletalMuscleMassKg)),
            2,
          ),
          basalMetabolicRateKcal: _optionalMean(
            measurements.map((m) => m.values.basalMetabolicRateKcal),
          ),
          bodyWaterPct: _optionalMean(
            measurements.map((m) => m.values.bodyWaterPct),
          ),
          proteinKg: _optionalMean(measurements.map((m) => m.values.proteinKg)),
          mineralKg: _optionalMean(measurements.map((m) => m.values.mineralKg)),
          ecwRatio: _optionalMean(measurements.map((m) => m.values.ecwRatio)),
          waistCm: _optionalMean(measurements.map((m) => m.values.waistCm)),
          visceralFatLevel: _optionalMean(
            measurements.map((m) => m.values.visceralFatLevel),
          ),
        )
      : null;

  final safetyWarnings = <String>[
    if (safety.acutePain == true) 'SAFETY_ACUTE_PAIN: 현재 통증이 있습니다.',
    if (safety.dizziness == true) 'SAFETY_DIZZINESS: 어지럼 증상이 있습니다.',
    if (safety.clinicianHold == true)
      'SAFETY_CLINICIAN_HOLD: 전문가 사용 보류 지시가 있습니다.',
  ];
  if (safetyWarnings.isNotEmpty || warnings.isNotEmpty || average == null) {
    return AlgorithmResult(
      status: safetyWarnings.isNotEmpty
          ? RecommendationStatus.blocked
          : RecommendationStatus.review,
      average: average,
      warnings: {...warnings, ...safetyWarnings}.toList(),
      adjustments: const [],
      recommendation: null,
      algorithmVersion: ruleSet.version,
      muscleAssessment: null,
      measurementIds: measurements.map((m) => m.id).toList(growable: false),
    );
  }

  final muscles = measurements
      .map((m) => m.values.skeletalMuscleMassKg)
      .toList(growable: false);
  final mean = _mean(muscles);
  final heightSquared = math.pow(profile.heightCm / 100, 2).toDouble();
  final selectedThresholds = muscleMassBasis == MuscleMassBasis.asm
      ? (profile.sex == ParticipantSex.female
            ? ruleSet.asmFemaleMuscleThresholds
            : ruleSet.asmMaleMuscleThresholds)
      : (profile.sex == ParticipantSex.female
            ? ruleSet.femaleMuscleThresholds
            : ruleSet.maleMuscleThresholds);
  MuscleLevel classify(double massKg) {
    final index = massKg / heightSquared;
    return index <= selectedThresholds.lowMaximum
        ? MuscleLevel.low
        : index <= selectedThresholds.mediumMaximum
        ? MuscleLevel.medium
        : MuscleLevel.reference;
  }

  final level = classify(mean);
  final sd = math.sqrt(
    muscles.fold<double>(0, (sum, value) => sum + math.pow(value - mean, 2)) /
        (muscles.length - 1),
  );
  final assessment = MuscleAssessment(
    basis: muscleMassBasis,
    indexKgM2: _round(mean / heightSquared, 2),
    level: level,
    meanSkeletalMuscleMassKg: mean,
    sdKg: sd,
    cvPct: 100 * sd / mean,
    minimumKg: muscles.reduce(math.min),
    maximumKg: muscles.reduce(math.max),
    unstable: muscles.map(classify).toSet().length > 1,
  );
  if (assessment.unstable || average.bmi < 18.5) {
    return AlgorithmResult(
      status: RecommendationStatus.review,
      average: average,
      warnings: [
        if (assessment.unstable) 'MUSCLE_TIER_UNSTABLE: 4건의 연구 분류가 일치하지 않습니다.',
        if (average.bmi < 18.5) 'BMI_REVIEW: 평균 BMI가 18.5 미만이므로 검토가 필요합니다.',
      ],
      adjustments: const [],
      recommendation: null,
      algorithmVersion: ruleSet.version,
      muscleAssessment: assessment,
      measurementIds: measurements.map((m) => m.id).toList(growable: false),
    );
  }

  final preset = switch (level) {
    MuscleLevel.low => ruleSet.lowMuscleProtocol,
    MuscleLevel.medium => ruleSet.mediumMuscleProtocol,
    MuscleLevel.reference => ruleSet.referenceMuscleProtocol,
  };
  final basisLabel = muscleMassBasis == MuscleMassBasis.asm ? 'ASM' : 'SMM';
  return AlgorithmResult(
    status: safety.isComplete
        ? RecommendationStatus.ready
        : RecommendationStatus.review,
    average: average,
    warnings: safety.isComplete
        ? const []
        : const ['SAFETY_INCOMPLETE: 오늘 상태 3문항을 완료해 주세요.'],
    adjustments: [
      Adjustment(
        id: '${basisLabel}_SIMULATION_CANDIDATE',
        label: '연구용 시뮬레이션 후보',
        factor: preset.intensityPct / ruleSet.baseIntensityPct,
        reason:
            '$basisLabel 정의가 확인된 4건의 지수 '
            '${assessment.indexKgM2.toStringAsFixed(2)}kg/m²를 연구 분류에 사용했습니다. '
            '시간·주파수·강도 연결은 검증되지 않은 가설이며 실제 장치 출력은 금지됩니다.',
      ),
    ],
    recommendation: Recommendation(
      durationSec: preset.durationSec,
      frequencyHz: preset.frequencyHz,
      intensityPct: preset.intensityPct.round(),
    ),
    algorithmVersion: ruleSet.version,
    muscleAssessment: assessment,
    measurementIds: measurements.map((m) => m.id).toList(growable: false),
  );
}
