import 'dart:math' as math;

import '../models/models.dart';

const algorithmVersion = 'pilot-0.9.0';
const requiredMeasurementCount = 4;

const pilotRuleSet = AlgorithmRuleSet(
  version: algorithmVersion,
  enabled: true,
  baselines: {
    BodyPart.wholeBody: VibrationBaseSetting(
      durationMin: 30,
      frequencyHz: 8,
      intensityPct: 90,
    ),
    BodyPart.shoulder: VibrationBaseSetting(
      durationMin: 25,
      frequencyHz: 15,
      intensityPct: 85,
    ),
    BodyPart.arm: VibrationBaseSetting(
      durationMin: 20,
      frequencyHz: 20,
      intensityPct: 80,
    ),
    BodyPart.abdomen: VibrationBaseSetting(
      durationMin: 15,
      frequencyHz: 25,
      intensityPct: 75,
    ),
    BodyPart.thigh: VibrationBaseSetting(
      durationMin: 10,
      frequencyHz: 35,
      intensityPct: 70,
    ),
    BodyPart.calf: VibrationBaseSetting(
      durationMin: 10,
      frequencyHz: 35,
      intensityPct: 70,
    ),
  },
  femaleCoefficient: 1,
  maleCoefficient: 1,
  ageUnder60Coefficient: 1,
  ageSixtiesCoefficient: 1,
  ageSeventiesCoefficient: 1,
  ageEightyPlusCoefficient: 1,
  femaleBodyFat: BodyFatThresholds(lowPct: 20, highPct: 35),
  maleBodyFat: BodyFatThresholds(lowPct: 10, highPct: 28),
  femaleMuscleIndex: MuscleIndexThresholds(
    lowMaximum: 5.75,
    mediumMaximum: 6.75,
  ),
  maleMuscleIndex: MuscleIndexThresholds(lowMaximum: 8.5, mediumMaximum: 10.75),
  lowBodyFatCoefficient: 1,
  normalBodyFatCoefficient: 1,
  highBodyFatCoefficient: 1,
  muscleMassCoefficient: 1,
  minimumPct: 20,
  maximumPct: 99,
);

const _lowMuscleSettings = {
  BodyPart.wholeBody: VibrationBaseSetting(
    durationMin: 25,
    frequencyHz: 8,
    intensityPct: 80,
  ),
  BodyPart.shoulder: VibrationBaseSetting(
    durationMin: 20,
    frequencyHz: 15,
    intensityPct: 75,
  ),
  BodyPart.arm: VibrationBaseSetting(
    durationMin: 15,
    frequencyHz: 20,
    intensityPct: 70,
  ),
  BodyPart.abdomen: VibrationBaseSetting(
    durationMin: 10,
    frequencyHz: 25,
    intensityPct: 65,
  ),
  BodyPart.thigh: VibrationBaseSetting(
    durationMin: 5,
    frequencyHz: 35,
    intensityPct: 60,
  ),
  BodyPart.calf: VibrationBaseSetting(
    durationMin: 5,
    frequencyHz: 35,
    intensityPct: 60,
  ),
};

const _highMuscleSettings = {
  BodyPart.wholeBody: VibrationBaseSetting(
    durationMin: 35,
    frequencyHz: 8,
    intensityPct: 99,
  ),
  BodyPart.shoulder: VibrationBaseSetting(
    durationMin: 30,
    frequencyHz: 15,
    intensityPct: 90,
  ),
  BodyPart.arm: VibrationBaseSetting(
    durationMin: 25,
    frequencyHz: 20,
    intensityPct: 85,
  ),
  BodyPart.abdomen: VibrationBaseSetting(
    durationMin: 20,
    frequencyHz: 25,
    intensityPct: 80,
  ),
  BodyPart.thigh: VibrationBaseSetting(
    durationMin: 15,
    frequencyHz: 35,
    intensityPct: 75,
  ),
  BodyPart.calf: VibrationBaseSetting(
    durationMin: 15,
    frequencyHz: 35,
    intensityPct: 75,
  ),
};

VibrationBaseSetting settingForMuscleLevel(
  String level,
  BodyPart bodyPart,
  AlgorithmRuleSet rules,
) => switch (level) {
  'low' => _lowMuscleSettings[bodyPart]!,
  'high' => _highMuscleSettings[bodyPart]!,
  _ => rules.baselines[bodyPart]!,
};

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

bool _hasValidCoreValues(BiaMeasurement measurement) {
  final values = measurement.values;
  final expectedFatMassKg = values.weightKg * values.bodyFatPct / 100;
  final fatMassToleranceKg = math.max(1, expectedFatMassKg * .20);
  return values.requiredValues.every((value) => value.isFinite && value > 0) &&
      values.bodyFatPct <= 100 &&
      values.fatMassKg <= values.weightKg &&
      values.skeletalMuscleMassKg <= values.weightKg &&
      (values.fatMassKg - expectedFatMassKg).abs() <= fatMassToleranceKg;
}

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

double calculateGenderCoefficient(ParticipantSex sex, AlgorithmRuleSet rules) =>
    sex == ParticipantSex.female
    ? rules.femaleCoefficient
    : rules.maleCoefficient;

double calculateAgeCoefficient(int age, AlgorithmRuleSet rules) {
  if (age < 60) return rules.ageUnder60Coefficient;
  if (age < 70) return rules.ageSixtiesCoefficient;
  if (age < 80) return rules.ageSeventiesCoefficient;
  return rules.ageEightyPlusCoefficient;
}

({String level, double indexKgM2}) calculateMuscleLevel(
  double skeletalMuscleMassKg,
  double heightCm,
  ParticipantSex sex,
  AlgorithmRuleSet rules,
) {
  final thresholds = sex == ParticipantSex.female
      ? rules.femaleMuscleIndex
      : rules.maleMuscleIndex;
  final heightM = heightCm / 100;
  final index = skeletalMuscleMassKg / (heightM * heightM);
  if (index <= thresholds.lowMaximum) {
    return (level: 'low', indexKgM2: _round(index, 2));
  }
  if (index <= thresholds.mediumMaximum) {
    return (level: 'medium', indexKgM2: _round(index, 2));
  }
  return (level: 'high', indexKgM2: _round(index, 2));
}

AlgorithmResult calculateRecommendation({
  required ParticipantProfile profile,
  required List<BiaMeasurement> measurements,
  required SafetyCheck safety,
  BodyPart bodyPart = BodyPart.wholeBody,
  AlgorithmRuleSet ruleSet = pilotRuleSet,
  DateTime? evaluatedAt,
}) {
  final warnings = <String>[];
  final now = evaluatedAt ?? DateTime.now();
  if (!ruleSet.enabled ||
      ruleSet.version != algorithmVersion ||
      ruleSet.policyBasis != 'ENGINEERING_POLICY' ||
      ruleSet.physicalExecution != 'PROHIBITED' ||
      ruleSet.baselines.length != BodyPart.values.length) {
    warnings.add('사용 가능한 새 알고리즘 규칙이 없습니다.');
  }
  if (profile.age < 18 ||
      profile.age > 100 ||
      !profile.heightCm.isFinite ||
      profile.heightCm < 100 ||
      profile.heightCm > 250) {
    warnings.add('참여자 정보가 유효하지 않습니다.');
  }
  if (measurements.length != requiredMeasurementCount) {
    warnings.add('측정값은 정확히 4건이어야 합니다.');
  }
  if (measurements.any((item) => item.participantId != profile.id)) {
    warnings.add('다른 참여자 측정값이 포함되었습니다.');
  }
  if (measurements.map((item) => item.deviceId).toSet().length != 1) {
    warnings.add('다른 측정 기기 값이 포함되었습니다.');
  }
  if (measurements.map((item) => item.id).toSet().length !=
      measurements.length) {
    warnings.add('중복 측정 ID가 있습니다.');
  }
  if (measurements.any(
    (item) => !item.qualityPassed || !_hasValidCoreValues(item),
  )) {
    warnings.add('유효하지 않은 측정값이 있습니다.');
  }
  if (measurements.any(
    (item) => item.muscleDefinition != MuscleMassBasis.smm,
  )) {
    warnings.add('현재 모델은 SMM 정의가 확인된 값만 사용합니다.');
  }
  if (measurements.map((item) => item.muscleMeasurementMethod).toSet().length !=
          1 ||
      measurements.any((item) => item.muscleMeasurementMethod == 'UNKNOWN')) {
    warnings.add('동일한 근육 측정 방법이 필요합니다.');
  }
  if (measurements.map((item) => item.acquisitionProtocolRef).toSet().length !=
          1 ||
      measurements.any((item) => item.acquisitionProtocolRef == 'UNKNOWN')) {
    warnings.add('동일한 획득 프로토콜이 필요합니다.');
  }
  final oldest = now.subtract(Duration(days: ruleSet.maximumAgeDays));
  final latest = now.add(Duration(minutes: ruleSet.maximumFutureSkewMinutes));
  if (measurements.any(
    (item) =>
        item.measuredAt.isBefore(oldest) || item.measuredAt.isAfter(latest),
  )) {
    warnings.add('측정 시각이 운영 허용 범위를 벗어났습니다.');
  }

  BiaValues? average;
  if (measurements.length == requiredMeasurementCount &&
      measurements.every(_hasValidCoreValues)) {
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
      obesityIndex: _optionalMean(
        measurements.map((m) => m.values.obesityIndex),
      ),
      abdomenIndex: _optionalMean(
        measurements.map((m) => m.values.abdomenIndex),
      ),
      dailyCalorie: _optionalMean(
        measurements.map((m) => m.values.dailyCalorie),
      ),
      intracellularWater: _optionalMean(
        measurements.map((m) => m.values.intracellularWater),
      ),
      extracellularWater: _optionalMean(
        measurements.map((m) => m.values.extracellularWater),
      ),
      bodyAge: _optionalMean(measurements.map((m) => m.values.bodyAge)),
    );
  }
  AlgorithmResult rejected(
    RecommendationStatus status,
    List<String> messages,
  ) => AlgorithmResult(
    status: status,
    average: average,
    warnings: messages,
    adjustments: const [],
    recommendation: null,
    algorithmVersion: ruleSet.version,
    bodyPart: bodyPart,
    factors: null,
    measurementIds: measurements.map((m) => m.id).toList(),
  );
  if (safety.hasSymptoms) {
    return rejected(RecommendationStatus.blocked, [
      ...warnings,
      '현재 통증·어지럼 또는 사용 보류 상태입니다.',
    ]);
  }
  if (warnings.isNotEmpty || average == null) {
    return rejected(RecommendationStatus.review, warnings);
  }

  final measurementsByNewest = [...measurements]
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  final muscle = calculateMuscleLevel(
    measurementsByNewest.first.values.skeletalMuscleMassKg,
    profile.heightCm,
    profile.sex,
    ruleSet,
  );
  final base = settingForMuscleLevel(muscle.level, bodyPart, ruleSet);
  final finalIntensity = base.intensityPct.round();
  return AlgorithmResult(
    status: RecommendationStatus.ready,
    average: average,
    warnings: const [],
    adjustments: [
      Adjustment(
        id: 'muscle-mass',
        label: '골격근량 등급',
        factor: 1,
        reason:
            '${muscle.indexKgM2.toStringAsFixed(2)}kg/m² · ${muscle.level} 등급',
      ),
    ],
    recommendation: Recommendation(
      durationSec: (base.durationMin * 60).round(),
      frequencyHz: base.frequencyHz,
      intensityPct: finalIntensity,
      baseIntensityPct: base.intensityPct.round(),
    ),
    algorithmVersion: ruleSet.version,
    bodyPart: bodyPart,
    factors: AlgorithmFactors(
      genderCoefficient: 1,
      ageCoefficient: 1,
      bodyFatCoefficient: 1,
      muscleMassCoefficient: 1,
      totalCoefficient: 1,
      calculatedIntensityPct: base.intensityPct,
      muscleLevel: muscle.level,
      muscleIndexKgM2: muscle.indexKgM2,
    ),
    measurementIds: measurements.map((m) => m.id).toList(),
  );
}

Map<BodyPart, AlgorithmResult> calculateAllRecommendations({
  required ParticipantProfile profile,
  required List<BiaMeasurement> measurements,
  required SafetyCheck safety,
  AlgorithmRuleSet ruleSet = pilotRuleSet,
  DateTime? evaluatedAt,
}) => {
  for (final part in BodyPart.values)
    part: calculateRecommendation(
      profile: profile,
      measurements: measurements,
      safety: safety,
      bodyPart: part,
      ruleSet: ruleSet,
      evaluatedAt: evaluatedAt,
    ),
};
