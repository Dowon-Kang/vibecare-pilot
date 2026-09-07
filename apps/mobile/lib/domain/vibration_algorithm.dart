import 'dart:math' as math;

import 'models.dart';

const algorithmVersion = 'pilot-0.3.0';
const requiredMeasurementCount = 4;
const pilotRuleSet = AlgorithmRuleSet(
  version: algorithmVersion,
  enabled: true,
  durationSec: 300,
  frequencyHz: 20,
  baseIntensityPct: 50,
  ageThreshold: 70,
  ageFactor: 0.90,
  femaleFactor: 0.95,
  maleFactor: 1,
  femaleBodyFat: BodyFatRange(20, 35),
  maleBodyFat: BodyFatRange(10, 28),
  outsideBodyFatFactor: 0.90,
  minimumPct: 20,
  maximumPct: 70,
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
      profile.heightCm <= 0) {
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
  ];
  if (ruleNumbers.any((v) => !v.isFinite) ||
      ruleSet.version.trim().isEmpty ||
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
  if (measurements.isNotEmpty && measurements.every(_hasValidCoreValues)) {
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
      measurementIds: measurements.map((m) => m.id).toList(growable: false),
    );
  }

  final isFemale = profile.sex == ParticipantSex.female;
  final bodyFatRange = isFemale ? ruleSet.femaleBodyFat : ruleSet.maleBodyFat;
  final bodyFatOutOfRange =
      average.bodyFatPct < bodyFatRange.minimum ||
      average.bodyFatPct > bodyFatRange.maximum;
  final adjustments = <Adjustment>[
    Adjustment(
      id: 'AGE_70_PILOT',
      label: '연령 보정',
      factor: profile.age >= ruleSet.ageThreshold ? ruleSet.ageFactor : 1,
      reason: profile.age >= ruleSet.ageThreshold
          ? '${ruleSet.ageThreshold}세 이상 PILOT 감산'
          : '감산 조건 아님',
    ),
    Adjustment(
      id: 'SEX_RESPONSE_PILOT',
      label: '성별 보정',
      factor: isFemale ? ruleSet.femaleFactor : ruleSet.maleFactor,
      reason: isFemale ? '여성 PILOT 5% 감산' : '남성 기준계수',
    ),
    Adjustment(
      id: 'BODY_FAT_RANGE_PILOT',
      label: '체지방 보정',
      factor: bodyFatOutOfRange ? ruleSet.outsideBodyFatFactor : 1,
      reason: bodyFatOutOfRange ? '성별 PILOT 참고범위 밖 10% 감산' : '성별 PILOT 참고범위 안',
    ),
  ];

  final factor = adjustments.fold<double>(
    1,
    (value, item) => value * item.factor,
  );
  final intensity = (ruleSet.baseIntensityPct * factor)
      .clamp(ruleSet.minimumPct, ruleSet.maximumPct)
      .round();
  final reviewWarnings = <String>[
    if (!safety.isComplete) '오늘 상태 3문항에 모두 답해 주세요.',
    if (average.bmi < 18.5) '평균 BMI가 18.5 미만이므로 전문가 검토가 필요합니다.',
  ];

  return AlgorithmResult(
    status: reviewWarnings.isEmpty
        ? RecommendationStatus.ready
        : RecommendationStatus.review,
    average: average,
    warnings: reviewWarnings,
    adjustments: adjustments,
    recommendation: Recommendation(
      durationSec: ruleSet.durationSec,
      frequencyHz: ruleSet.frequencyHz,
      intensityPct: intensity,
    ),
    algorithmVersion: ruleSet.version,
    measurementIds: measurements.map((m) => m.id).toList(growable: false),
  );
}
