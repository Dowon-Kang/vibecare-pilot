import 'dart:math' as math;

import '../models/models.dart';

const algorithmVersion = 'pilot-0.6.0';
const requiredMeasurementCount = 4;
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
  maleMuscleThresholds: MuscleThresholds(
    lowMaximum: 8.50,
    mediumMaximum: 10.75,
  ),
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
  AlgorithmRuleSet ruleSet = pilotRuleSet,
}) {
  final warnings = <String>[];
  if (!ruleSet.enabled) warnings.add('현재 사용할 수 있는 계산 규칙이 없습니다.');
  if (profile.id.trim().isEmpty ||
      profile.age < 18 ||
      profile.age > 100 ||
      !profile.heightCm.isFinite ||
      profile.heightCm < 100 ||
      profile.heightCm > 250) {
    warnings.add('참여자 정보가 유효하지 않습니다.');
  }
  final ruleNumbers = [
    ruleSet.baseIntensityPct,
    ruleSet.ageFactor,
    ruleSet.femaleFactor,
    ruleSet.maleFactor,
    ruleSet.outsideBodyFatFactor,
    ruleSet.minimumPct,
    ruleSet.maximumPct,
    ruleSet.femaleBodyFat.minimum,
    ruleSet.femaleBodyFat.maximum,
    ruleSet.maleBodyFat.minimum,
    ruleSet.maleBodyFat.maximum,
    ruleSet.femaleMuscleThresholds.lowMaximum,
    ruleSet.femaleMuscleThresholds.mediumMaximum,
    ruleSet.maleMuscleThresholds.lowMaximum,
    ruleSet.maleMuscleThresholds.mediumMaximum,
    ruleSet.lowMuscleProtocol.intensityPct,
    ruleSet.mediumMuscleProtocol.intensityPct,
    ruleSet.referenceMuscleProtocol.intensityPct,
  ];
  if (ruleNumbers.any((v) => !v.isFinite) ||
      ruleSet.version != algorithmVersion ||
      ruleSet.ageFactor != 1 ||
      ruleSet.femaleFactor != 1 ||
      ruleSet.maleFactor != 1 ||
      ruleSet.outsideBodyFatFactor != 1 ||
      ruleSet.ageThreshold < 18 ||
      ruleSet.ageThreshold > 100 ||
      ruleSet.femaleBodyFat.minimum < 0 ||
      ruleSet.femaleBodyFat.maximum > 100 ||
      ruleSet.maleBodyFat.minimum < 0 ||
      ruleSet.maleBodyFat.maximum > 100 ||
      ruleSet.durationSec <= 0 ||
      ruleSet.frequencyHz <= 0 ||
      ruleSet.minimumPct < 0 ||
      ruleSet.maximumPct > 100 ||
      ruleSet.minimumPct > ruleSet.maximumPct ||
      ruleSet.baseIntensityPct < ruleSet.minimumPct ||
      ruleSet.baseIntensityPct > ruleSet.maximumPct ||
      [
        ruleSet.ageFactor,
        ruleSet.femaleFactor,
        ruleSet.maleFactor,
        ruleSet.outsideBodyFatFactor,
      ].any((v) => v <= 0 || v > 1) ||
      ruleSet.femaleBodyFat.minimum > ruleSet.femaleBodyFat.maximum ||
      ruleSet.maleBodyFat.minimum > ruleSet.maleBodyFat.maximum) {
    warnings.add('계산 규칙의 범위를 확인해 주세요.');
  }
  final protocols = [
    ruleSet.lowMuscleProtocol,
    ruleSet.mediumMuscleProtocol,
    ruleSet.referenceMuscleProtocol,
  ];
  if (ruleSet.femaleMuscleThresholds.lowMaximum <= 0 ||
      ruleSet.femaleMuscleThresholds.lowMaximum >=
          ruleSet.femaleMuscleThresholds.mediumMaximum ||
      ruleSet.maleMuscleThresholds.lowMaximum <= 0 ||
      ruleSet.maleMuscleThresholds.lowMaximum >=
          ruleSet.maleMuscleThresholds.mediumMaximum ||
      protocols.any(
        (p) =>
            p.durationSec <= 0 ||
            p.frequencyHz <= 0 ||
            p.intensityPct < ruleSet.minimumPct ||
            p.intensityPct > ruleSet.maximumPct,
      )) {
    warnings.add('근육량 기반 계산 규칙의 범위를 확인해 주세요.');
  }
  if (measurements.any(
    (m) => m.id.trim().isEmpty || m.deviceId.trim().isEmpty,
  )) {
    warnings.add('측정 ID와 기기 ID가 필요합니다.');
  }

  if (measurements.length != requiredMeasurementCount) {
    warnings.add('최근 유효 측정값이 4건 필요합니다.');
  }
  if (measurements.any((m) => m.participantId != profile.id)) {
    warnings.add('서로 다른 사용자의 측정값이 포함되어 있습니다.');
  }
  if (measurements.map((m) => m.deviceId).toSet().length > 1) {
    warnings.add('서로 다른 BIA 기기의 측정값이 포함되어 있습니다.');
  }
  if (measurements.map((m) => m.id).toSet().length != measurements.length) {
    warnings.add('중복된 측정 ID가 있습니다.');
  }
  if (measurements.any((m) => !m.qualityPassed)) {
    warnings.add('BIA 품질 검사를 통과하지 못한 측정값이 있습니다.');
  }
  if (measurements.any((m) => !_hasValidCoreValues(m))) {
    warnings.add('필수 측정값에 0, 음수 또는 숫자가 아닌 값이 있습니다.');
  }

  BiaValues? average;
  if (measurements.length == 4 && measurements.every(_hasValidCoreValues)) {
    average = BiaValues(
      weightKg: _round(_mean(measurements.map((m) => m.values.weightKg)), 2),
      bmi: _round(_mean(measurements.map((m) => m.values.bmi)), 2),
      bodyFatPct: _round(
        _mean(measurements.map((m) => m.values.bodyFatPct)),
        2,
      ),
      fatMassKg: _round(_mean(measurements.map((m) => m.values.fatMassKg)), 2),
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
    );
  }

  for (var i = 0; i < measurements.length; i++) {
    final m = measurements[i];
    final calculatedBodyFat = m.values.fatMassKg / m.values.weightKg * 100;
    if ((calculatedBodyFat - m.values.bodyFatPct).abs() > 1) {
      warnings.add('${i + 1}회 측정의 체지방률과 체지방량이 일치하지 않습니다.');
    }
    final heightM = profile.heightCm / 100;
    final calculatedBmi = m.values.weightKg / math.pow(heightM, 2);
    if ((calculatedBmi - m.values.bmi).abs() > 0.6) {
      warnings.add('${i + 1}회 측정의 BMI와 키·체중이 일치하지 않습니다.');
    }
  }

  MuscleAssessment? muscleAssessment;
  ProtocolPreset? muscleProtocol;
  if (warnings.isEmpty &&
      average != null &&
      profile.heightCm.isFinite &&
      profile.heightCm > 0) {
    final heightM = profile.heightCm / 100;
    final muscles = measurements
        .map((m) => m.values.skeletalMuscleMassKg)
        .toList();
    final sum = muscles.reduce((a, b) => a + b);
    final mean = sum / 4;
    final totalSmmi = mean / math.pow(heightM, 2);
    final thresholds = profile.sex == ParticipantSex.female
        ? ruleSet.femaleMuscleThresholds
        : ruleSet.maleMuscleThresholds;
    final heightSquared = heightM * heightM;
    MuscleLevel classify(double total, int count) =>
        total <= thresholds.lowMaximum * heightSquared * count
        ? MuscleLevel.low
        : total <= thresholds.mediumMaximum * heightSquared * count
        ? MuscleLevel.medium
        : MuscleLevel.reference;
    final level = classify(sum, 4);
    final sd = math.sqrt(
      muscles.fold<double>(0, (s, m) => s + math.pow(m - mean, 2)) / 3,
    );
    muscleProtocol = switch (level) {
      MuscleLevel.low => ruleSet.lowMuscleProtocol,
      MuscleLevel.medium => ruleSet.mediumMuscleProtocol,
      MuscleLevel.reference => ruleSet.referenceMuscleProtocol,
    };
    muscleAssessment = MuscleAssessment(
      totalSmmi: _round(totalSmmi, 2),
      level: level,
      meanSkeletalMuscleMassKg: mean,
      sdKg: sd,
      cvPct: 100 * sd / mean,
      minimumKg: muscles.reduce(math.min),
      maximumKg: muscles.reduce(math.max),
      unstable: muscles.map((m) => classify(m, 1)).toSet().length > 1,
    );
  }

  final safetyWarnings = <String>[
    if (safety.acutePain == true) '현재 통증이 있어 실행을 차단합니다.',
    if (safety.dizziness == true) '어지럼 증상이 있어 실행을 차단합니다.',
    if (safety.clinicianHold == true) '전문가 사용 보류 지시가 있습니다.',
  ];

  if (warnings.isNotEmpty || safetyWarnings.isNotEmpty || average == null) {
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

  final selectedProtocol = muscleProtocol!;
  final levelLabel = switch (muscleAssessment!.level) {
    MuscleLevel.low => '낮은 근육량 등급',
    MuscleLevel.medium => '중간 근육량 등급',
    MuscleLevel.reference => '참조 이상 근육량 등급',
  };
  final adjustments = <Adjustment>[
    Adjustment(
      id: 'TOTAL_SMMI_PROTOCOL_RESEARCH',
      label: '근육량 기본값',
      factor: selectedProtocol.intensityPct / ruleSet.baseIntensityPct,
      reason:
          '추정 근육지수 ${muscleAssessment.totalSmmi.toStringAsFixed(2)}kg/m², '
          '$levelLabel에 따라 ${selectedProtocol.frequencyHz}Hz·'
          '${selectedProtocol.durationSec}초·${selectedProtocol.intensityPct.toStringAsFixed(0)}%를 선택했습니다. '
          'FITRUS 교정 전 연구용 기준입니다.',
    ),
    Adjustment(
      id: 'AGE_70_PILOT',
      label: '추가 감산 없음',
      factor: profile.age >= ruleSet.ageThreshold ? ruleSet.ageFactor : 1,
      reason: profile.age >= ruleSet.ageThreshold
          ? '근거 없는 연령별 일괄 감산 제거'
          : '추가 나이 계수 없음',
    ),
  ];

  final ageFactor = profile.age >= ruleSet.ageThreshold
      ? ruleSet.ageFactor
      : 1.0;
  final intensity = (selectedProtocol.intensityPct * ageFactor)
      .clamp(ruleSet.minimumPct, ruleSet.maximumPct)
      .round();
  final duration = (selectedProtocol.durationSec * ageFactor).round();
  final reviewWarnings = <String>[
    if (!safety.isComplete) '오늘 상태 3문항에 모두 답해 주세요.',
    if (_mean(measurements.map((m) => m.values.bmi)) < 18.5)
      '평균 BMI가 18.5 미만이므로 전문가 검토가 필요합니다.',
    if (profile.age < 60) '60세 이상 연구 대상 범위 밖입니다.',
    if (muscleAssessment.unstable) '반복 측정의 근육지수 등급이 달라 재측정과 검토가 필요합니다.',
  ];

  return AlgorithmResult(
    status: reviewWarnings.isEmpty
        ? RecommendationStatus.ready
        : RecommendationStatus.review,
    average: average,
    warnings: reviewWarnings,
    adjustments: adjustments,
    recommendation: Recommendation(
      durationSec: duration,
      frequencyHz: selectedProtocol.frequencyHz,
      intensityPct: intensity,
    ),
    algorithmVersion: ruleSet.version,
    muscleAssessment: muscleAssessment,
    measurementIds: measurements.map((m) => m.id).toList(growable: false),
  );
}
